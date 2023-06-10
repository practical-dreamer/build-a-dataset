import argparse
import json
import random
import os
import itertools
from atomicwrites import atomic_write

def modify_keys(obj, append):
    return {f"{k}{append}": v for k, v in obj.items()}

def join_it(input_json_big, input_json_small, output_json, iterations):
    with open(input_json_big, 'r') as f:
        data_big = json.load(f)

    with open(input_json_small, 'r') as f:
        data_small = json.load(f)

    output_data = []
    used_combinations = set()

    # Check if we are mixing the file with itself
    same_file = input_json_big == input_json_small

    # Generate all combinations
    combinations = list(itertools.product(data_big, data_small))
    
    # Randomize the order of combinations
    random.shuffle(combinations)

    # Number of times a big item can be used
    big_usage_limit = min(len(data_small), iterations)

    # Track usage of big items
    big_usage = {json.dumps(item): 0 for item in data_big}

    # Go through combinations
    for (item_big, item_small) in combinations:
        # Create a unique key for the combination
        comb_key = json.dumps(item_big) + '|' + json.dumps(item_small)

        if comb_key in used_combinations:
            continue

        if big_usage[json.dumps(item_big)] >= big_usage_limit:
            continue

        # Modify keys if mixing the same file
        item_big_mod = modify_keys(item_big, '1') if same_file else item_big
        item_small_mod = modify_keys(item_small, '2') if same_file else item_small

        # Merge the two items
        joined_item = {**item_big_mod, **item_small_mod}
        output_data.append(joined_item)

        # Remember this combination
        used_combinations.add(comb_key)
        big_usage[json.dumps(item_big)] += 1

    with atomic_write(output_json, overwrite=True) as f:
        json.dump(output_data, f, indent=4)

    print(f"mixIt: Successfully Output {output_json} with " + str(len(output_data)) + " entries.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Randomly join two JSON arrays.')
    parser.add_argument('-input_json_big', required=True, help='Input JSON file (big)')
    parser.add_argument('-input_json_small', required=True, help='Input JSON file (small)')
    parser.add_argument('-output_json', help='Output JSON file')
    parser.add_argument('-iterations', type=int, default=1, help='Number of iterations through big JSON array')
    args = parser.parse_args()    

    # Ensure all input and output filenames ends with .json
    if not args.input_json_big.endswith('.json'):
        args.input_json_big += '.json'
    if not args.input_json_small.endswith('.json'):
        args.input_json_small += '.json'    
    if args.output_json and not args.output_json.endswith('.json'):
        args.output_json += '.json'    

    # If output_json argument is not provided, construct it from input_json_big and input_json_small
    if not args.output_json:
        big_base = os.path.splitext(args.input_json_big)[0]  # Remove the extension
        small_suffix = os.path.splitext(args.input_json_small)[0].split('_')[0]  # Get the part after the last underscore
        args.output_json = f'{big_base}_{small_suffix}_mixed.json'

    # Prepend 'jsons/' to the input and output JSON file paths
    args.input_json_big = os.path.join('jsons', args.input_json_big)
    args.input_json_small = os.path.join('jsons', args.input_json_small)
    args.output_json = os.path.join('jsons', args.output_json)

    join_it(args.input_json_big, args.input_json_small, args.output_json, args.iterations)
