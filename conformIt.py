import json
import re
import os
import argparse
from atomicwrites import atomic_write

def share_gpt_format(data):
    formatted_data = []
    for entry in data:
        new_entry = {}
        new_entry["id"] = entry["messages_id"]
        new_entry["conversations"] = []
        for message in entry["messages"]:
            new_message = {}
            new_message["from"] = "human" if message["role"] == "user" else "gpt"
            new_message["value"] = message["content"]
            new_entry["conversations"].append(new_message)
        formatted_data.append(new_entry)
    return formatted_data

def alpaca_format(data):
    formatted_data = []
    for entry in data:
        new_entry = {}
        first_message_content = entry["messages"][0]["content"].split('\n', 1)
        new_entry["instruction"] = first_message_content[0].strip()
        new_entry["input"] = first_message_content[1].strip() if len(first_message_content) > 1 else ""
        new_entry["output"] = entry["messages"][1]["content"]
        formatted_data.append(new_entry)
    return formatted_data

def main(args):
    with open(args.input_json, 'r') as f:
        data = json.load(f)

    if args.format == "ShareGPT":
        formatted_data = share_gpt_format(data)
    elif args.format == "Alpaca":
        formatted_data = alpaca_format(data)

    with atomic_write(args.output_json, overwrite=True) as f:
        json.dump(formatted_data, f, indent=4)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Conform JSON data to specified format')
    parser.add_argument('-input_json', required=True, help='Input JSON file')
    parser.add_argument('-output_json', help='Output JSON file')
    parser.add_argument('-format', required=True, choices=["ShareGPT", "Alpaca"], help='Format to conform to')
    args = parser.parse_args()

    # hack to remove new line escapes the shell tries to put in on parameters
    for arg in vars(args):
        value = getattr(args, arg)
        if isinstance(value, str):
            setattr(args, arg, value.replace('\\n', '\n'))

    # Ensure input filename ends with .json
    if args.input_json and not args.input_json.endswith('.json'):
        args.input_json += '.json'

    # If output_json argument is not provided, use the input filename with modified suffix
    if args.format == "ShareGPT":
        if args.input_json and not args.output_json:
            args.output_json = re.sub(r'_([^_]*)$', '_sharegpt', args.input_json)
    elif args.format == "Alpaca":
        if args.input_json and not args.output_json:
            args.output_json = re.sub(r'_([^_]*)$', '_alpaca', args.input_json)

    # Ensure output filename ends with .json
    if not args.output_json.endswith('.json'):
        args.output_json += '.json'

    # prepend 'jsons/' to the input and output JSON file paths
    args.input_json = os.path.join('jsons', args.input_json)
    args.output_json = os.path.join('jsons', args.output_json)

    main(args)
