import json
import argparse
import os
from atomicwrites import atomic_write

# Function to format the prompt
def format_prompt(object, prompt_format, batch_size=None, list_start=1):
    object = {**object, 'batch_size': batch_size, 'list_number': list_start}
    formatted_prompt = prompt_format.format(**object)
    return formatted_prompt

# Function to generate message data
def main(args):

    # Read json and yaml
    with open(args.template, 'r') as template_file:
            template = json.load(template_file)

    if args.input_json:
        with open(args.input_json, 'r') as input_file:
            data = json.load(input_file)
    else:
        data = [{}]
    
    messages = [{}]    

    for i, obj in enumerate(data):
        obj['id'] = str(i+1).zfill(5)
        obj['batch_size'] = args.batch_size
        
        # Append messages if input objects already contain them
        if 'prompt' in obj:
            obj['messages'].extend([{'role':'user', 'content':prompt}, {'role':'assistant', 'content':assistant_prompt}])
        else:
            obj['messages'] = [{'role':'user', 'content':prompt}, {'role':'assistant', 'content':assistant_prompt}]
        messages.append(obj)                

    # Write to output json file
    with atomic_write(args.output_json, overwrite=True) as f:
        json.dump(data, f, indent=4)

    print(f"promptIt: Successfully Output {args.output_json} with " + str(len(data)) + " entries.")

if __name__ == '__main__':
    #Argument Parser
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_json", help="JSON for input", type=str)
    parser.add_argument("--output_json", help="JSON for output", type=str, required=True)    
    parser.add_argument("--batch_size", help="Expected segments in response for use with splitIt", type=int, default=1)
    parser.add_argument("--template", help="YAML template in which to insert user and bot messages when generating prompt", type=str)
    parser.add_argument("--user", help="User message to be appended to end of prompt.", type=str, required=True)
    parser.add_argument("--bot", help="Bot message to be appended to end of prompt.", type=str, default="")
    #args = parser.parse_args()
    args = parser.parse_args([
        "--output_json", "jokes",
        "--template", "openAI_chat",
        "--user", "Tell a knock knock joke",
        "--bot", "Knock Knock"
    ])

    # If input not specified use output as input
    if args.input_json is None:
        args.input_json = args.output_json

    # Prepend file paths
    args.input_json = os.path.join('../jsons', args.input_json)
    args.output_json = os.path.join('../jsons', args.output_json)
    args.template = os.path.join('../../templates/prompts/', args.template)

    # Append file formats
    if not args.input_json.endswith('.json'):
        args.input_json += '.json'
    if not args.output_json.endswith('.json'):
        args.output_json += '.json'
    if not args.template.endswith('.yaml'):
        args.template += '.yaml'       
        
    main(args)
