import json
import argparse
import re
import os
from atomicwrites import atomic_write

# Function to format the prompt
def format_prompt(object, prompt_format, list_size=None, list_start=1):
    object = {**object, 'list_size': list_size, 'list_number': list_start}
    formatted_prompt = prompt_format.format(**object)
    return formatted_prompt

# Function to generate message data
# Function to generate message data
def main(args):
    # Initialize input data
    input_data = [{}]

    # Read input json file if provided
    if args.input_json:
        with open(args.input_json, 'r') as input_file:
            input_data = json.load(input_file)
    
    output_data = input_data
    messages = []    

    for i, obj in enumerate(output_data):
        obj['messages_id'] = str(i+1).zfill(5)
        obj['messages_list_size'] = args.list_size
        obj['messages_assistant_prompt'] = args.assistant_prompt
        obj['messages_complete'] = False
        
        # If list_size, calculate the list start position
        list_start = 1 + i * args.list_size if args.list_size else None

        # If next_prompt is not provided or it's the first object, use first_prompt
        if not args.next_prompt or i == 0:
            prompt = format_prompt(obj, args.first_prompt, args.list_size, list_start)
        else:
            prompt = format_prompt(obj, args.next_prompt, args.list_size, list_start)

        if args.assistant_prompt:
            assistant_prompt = args.assistant_prompt.format(**obj) # New line for formatting assistant_prompt
        else:
            assistant_prompt = ''

        # Append messages if input objects already contain them
        if 'messages' in obj:
            obj['messages'].extend([{'role':'user', 'content':prompt}, {'role':'assistant', 'content':assistant_prompt}])
        else:
            obj['messages'] = [{'role':'user', 'content':prompt}, {'role':'assistant', 'content':assistant_prompt}]
        messages.append(obj)                

    # Write to output json file
    with atomic_write(args.output_json, overwrite=True) as f:
        json.dump(output_data, f, indent=4)

    print(f"promptIt: Successfully Output {args.output_json} with " + str(len(output_data)) + " entries.")


if __name__ == '__main__':
    #Argument Parser
    parser = argparse.ArgumentParser()
    parser.add_argument("-input_json", help="Input JSON file", type=str)
    parser.add_argument("-output_json", help="Output JSON file", type=str)
    parser.add_argument("-list_size", help="Number of expected list entries in response to generated prompt", type=int, default=0)
    parser.add_argument("-first_prompt", help="First generated prompt", type=str, required=True)
    parser.add_argument("-next_prompt", help="Next generated prompt", type=str)
    parser.add_argument("-assistant_prompt", help="Beginning of assistant message", type=str)
    parser.add_argument("-forget_lines", help="Number of last lines to forget in each object's last message", type=int)
    args = parser.parse_args()
    #args = parser.parse_args([  
        #"-input_json", "character_pair_moods_mixed",
        #"-output_json", "character_pair_moods_prompted",
        #"-first_prompt", "Hey! I have a great idea for a creative writing exercise and I need your help. I\'ve matched together pairs of characters from all kinds of literature in the public domain and I'd like you to think up an imaginative scenario prompt for how they might interact with eachother!\nSome of these character pairs might be pretty weird because they were mixed together at random but that's part of the fun! Don't be afraid to push the narative a little let's say PG-13 at max but the writing exercise is for adults not kids.\nCan I also request that the scenario is character centric? So like the location and conflict or objective should be built to facilitate an interesting dialogue of some sort that showcases the unique dynamic between them.\n\nOkay so the first scenario I need you to come up with is between **{character_name1}** from {book1} and **{character_name2}** from {book2}.\n{character_name1} is described as \"{character_description1}\" while {character_name2} is described as \"{character_description2}\".\nAnd the mood for this scenario prompt should be **{scenario_mood}**.\n\nI'm sure you'll do great and I can't wait to see what you come up with! Oh one last thing, your response is going to be added to a dataset where the above character descriptions will already be provided so please ONLY provide the scenario prompt you came up with. Thanks again!\nRemember all I need is a short scenario prompt doesn't need to be all that long just something to hopefully spark creativity. Describe a location, maybe a conflict or delima, just something to get an interesting interaction between the two.",
        #"-assistant_prompt", '{character_name1}: *'
    #])

    # hack to remove new line escapes the shell tries to put in on parameters
    for arg in vars(args):
        value = getattr(args, arg)
        if isinstance(value, str):
            setattr(args, arg, value.replace('\\n', '\n'))     

    # Ensure input filename ends with .json
    if args.input_json and not args.input_json.endswith('.json'):
        args.input_json += '.json'

    # If output_json argument is not provided, use the input filename with modified suffix
    if args.input_json and not args.output_json:
        args.output_json = re.sub(r'_([^_]*)$', '_prompted', args.input_json) 

    # Ensure output filename ends with .json
    if not args.output_json.endswith('.json'):
        args.output_json += '.json'
    
    if args.input_json is not None:
        args.input_json = os.path.join('jsons', args.input_json)
    args.output_json = os.path.join('jsons', args.output_json)    
        
    main(args)
