import argparse
import json
import os
from atomicwrites import atomic_write
import re

def split_last_message(entry, split_on, new_key):
    last_assistant_message = next((message for message in reversed(entry['messages']) if message['role'] == 'assistant'), None)

    if not last_assistant_message:
        return []
    
    response_content = last_assistant_message['content']
    list_size = entry.get('messages_list_size', 0)

    # If 'messages_list_size' is 0, create a new entry with the entire last assistant response
    if list_size == 0:
        new_entry = {key: value for key, value in entry.items() if key not in ['messages', 'messages_id', 'messages_list_size', 'messages_complete', 'messages_assistant_prompt']}
        new_entry[new_key] = response_content
        return [new_entry]

    parts = response_content.split(split_on)

    new_entries = []
    for part in parts:
        if part:  # Skip if empty string (occurs if content starts with split_on)
            new_entry = {key: value for key, value in entry.items() if key not in ['messages', 'messages_id', 'messages_list_size', 'messages_complete', 'messages_assistant_prompt']}

            # Remove the leading list number (if exists) and add the new content to the new item
            if list_size != 0:
                part = re.sub(r'^\d+\. ', '', part).strip()
            new_entry[new_key] = part
            new_entries.append(new_entry)
    return new_entries

def main(args):
    with open(args.input_json, 'r') as f:
        input_data = json.load(f)

    output_data = []
    for entry in input_data:
        # Skip this entry if messages_complete is not true
        if not entry.get('messages_complete', False):
            print(f"Warning: Entry with messages_id {entry.get('messages_id')} has messages_complete set to false. This entry is discarded.")
            continue
        
        new_entries = split_last_message(entry, args.split_on, args.new_key)

        # Check if new_entries matches the expected size
        expected_size = entry.get('messages_list_size')
        if entry.get('messages_list_size', 0) > 0:
            if expected_size is not None and len(new_entries) != expected_size:
                print(f"Warning: Entry with messages_id {entry.get('messages_id')} generated an unexpected number of new entries. Expected: {expected_size}, Actual: {len(new_entries)}. This entry is discarded.")
                continue  # skip this entry and continue with the next one

        output_data.extend(new_entries)

    with atomic_write(args.output_json, overwrite=True) as f:
        json.dump(output_data, f, indent=4)

    print(f"splitIt: Successfully Output {args.output_json} with " + str(len(output_data)) + " entries.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Split response content in JSON entries.')
    parser.add_argument('-input_json', required=True, help='Input JSON file')
    parser.add_argument('-output_json', help='Output JSON file')
    parser.add_argument('-split_on', default='\n', help='String to split the response content on')
    parser.add_argument('-new_key', required=True, help='New key to assign the split parts to')
    args = parser.parse_args()
    #import shlex
    #args = parser.parse_args(shlex.split("-input_json genre_responses_trimmed.json -split_on 'and' -new_key 'partytime'"))    

    # Ensure input filename ends with .json
    if args.input_json and not args.input_json.endswith('.json'):
        args.input_json += '.json'

    # If output_json argument is not provided, use the input filename with modified suffix
    if args.input_json and not args.output_json:
        args.output_json = re.sub(r'_([^_]*)$', '_split', args.input_json) 

    # Ensure output filename ends with .json
    if not args.output_json.endswith('.json'):
        args.output_json += '.json'

    # prepend 'jsons/' to the input and output JSON file paths
    args.input_json = os.path.join('jsons', args.input_json)
    args.output_json = os.path.join('jsons', args.output_json)    
        
    main(args)
