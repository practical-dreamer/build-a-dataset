import argparse
import json
import os
from atomicwrites import atomic_write
import re

def main(args):
    with open(args.input_json, 'r') as f:
        input_data = json.load(f)

    for entry in input_data:
        last_assistant_message = None

        # Check if the JSON structure is as expected
        if 'messages' not in entry or 'messages_assistant_prompt' not in entry:
            print(f"Warning: Entry does not have 'messages' or 'messages_assistant_prompt'. Skipping this entry.")
            continue

        # Identify the last assistant's message
        for message in reversed(entry['messages']):
            if message['role'] == 'assistant':
                last_assistant_message = message
                break        

        # If no assistant message found, continue to next entry
        if last_assistant_message is None:
            print(f"Warning: No assistant message found in the entry. Skipping this entry.")
            continue

        last_prompt = entry['messages_assistant_prompt'].format(**entry)        
        response_content = last_assistant_message['content']
        list_size = entry.get('messages_list_size', 0)

        if list_size > 0:
            # Remove any content before the first list item
            response_content = re.sub(r'^.*?1\. ', '1. ', response_content, flags=re.DOTALL)
            # Remove any content after the last list item
            response_content = re.sub(r'(\n{list_number}\..*?)\n.*$'.format(list_number=list_size), r'\1', response_content, flags=re.DOTALL)

        if args.trim_lines_from_end > 0 or args.trim_lines_from_start > 0:
            lines = response_content.split('\n')
            non_blank_lines = [i for i, line in enumerate(lines) if line.strip() != '']

            # Trim lines from end
            if args.trim_lines_from_end > 0:
                if len(non_blank_lines) > args.trim_lines_from_end:
                    last_kept_line_index = non_blank_lines[-args.trim_lines_from_end-1]
                    response_content = '\n'.join(lines[:last_kept_line_index + 1])

            # Trim lines from start
            if args.trim_lines_from_start > 0:
                if len(non_blank_lines) > args.trim_lines_from_start:
                    first_kept_line_index = non_blank_lines[args.trim_lines_from_start]
                    response_content = '\n'.join(lines[first_kept_line_index:])

        # Ensure that the last line starts with a specific string
        if args.last_line_starts_with:
            try:
                start_str = args.last_line_starts_with.format(**entry).lower()
                lines = response_content.split('\n')
                for i in reversed(range(len(lines))):
                    # If a non-blank line is found
                    if lines[i].strip():
                        # Check if the last line begins with the specified string (case-insensitive)
                        if lines[i].lower().startswith(start_str):
                            response_content = '\n'.join(lines[:i+1])
                            break
            except KeyError as e:
                print(f"Warning: Property {str(e)} not found in the entry. Skipping 'last_line_starts_with' for this entry.")

        # Trim blanks
        if args.trim_blanks:
            response_content = response_content.strip()

        last_assistant_message['content'] = response_content

        # Remove assistant prompt if required
        if args.trim_assistant_prompt and last_assistant_message['content'].startswith(last_prompt):
            last_assistant_message['content'] = last_assistant_message['content'][len(last_prompt):]

    with atomic_write(args.output_json, overwrite=True) as f:
        json.dump(input_data, f, indent=4)

    print(f"trimIt: Successfully Output {args.output_json} with " + str(len(input_data)) + " entries.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Trim lines in JSON responses.')
    parser.add_argument('-input_json', required=True, help='Input JSON file')
    parser.add_argument('-output_json', help='Output JSON file')
    parser.add_argument('-trim_lines_from_start', type=int, default=0, help='Number of lines to trim from start of the assistant\'s last message')
    parser.add_argument('-trim_lines_from_end', type=int, default=0, help='Number of lines to trim from end of the assistant\'s last message')
    parser.add_argument('-trim_assistant_prompt', action='store_true', help="Remove the assistant's prompt from the assistant's last message")
    parser.add_argument('-trim_blanks', action='store_true', help="Remove all blank lines and new lines from the start and end of the response")
    parser.add_argument('-last_line_starts_with', default="", help="Specify a string with which the last line should start. You can use {property_name} to include entry properties.")
    args = parser.parse_args()
    #import shlex
    #args = parser.parse_args(shlex.split("-input_json character_pair_moods_asked -trim_blanks -trim_assistant_prompt"))

    # Ensure input filename ends with .json
    if args.input_json and not args.input_json.endswith('.json'):
        args.input_json += '.json'

    # If output_json argument is not provided, use the input filename with modified suffix
    if args.input_json and not args.output_json:
        args.output_json = re.sub(r'_([^_]*)$', '_trimmed', args.input_json) 

    # Ensure output filename ends with .json
    if not args.output_json.endswith('.json'):
        args.output_json += '.json'

    # prepend 'jsons/' to the input and output JSON file paths
    args.input_json = os.path.join('jsons', args.input_json)
    args.output_json = os.path.join('jsons', args.output_json)    
        
    main(args)
