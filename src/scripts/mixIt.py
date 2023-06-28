import argparse
import json
import random
import os
import itertools
from atomicwrites import atomic_write

def modify_keys(obj, append):
    return {f"{k}{append}": v for k, v in obj.items()}

def main(args):
    with open(args.input_json_big, 'r') as f:
        data_big = json.load(f)

    with open(args.input_json_small, 'r') as f:
        data_small = json.load(f)

    output_data = []
    used_combinations = set()
    
    same_file = args.input_json_big == args.input_json_small # Check if we are mixing the file with itself
    combinations = list(itertools.product(data_big, data_small)) # Generate all combinations
    random.shuffle(combinations) # Randomize the order of combinations    
    big_usage_limit = min(len(data_small), args.iterations) # Number of times a big item can be used    
    big_usage = {json.dumps(item): 0 for item in data_big} # Track usage of big items

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

    with atomic_write(args.output_json, overwrite=True) as f:
        json.dump(output_data, f, indent=4)

    print(f"mixIt: Successfully Output {args.output_json} with " + str(len(output_data)) + " entries.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Randomly join two JSON arrays.')
    parser.add_argument('-args.input_json_big', required=True, help='Input JSON file (big)')
    parser.add_argument('-args.input_json_small', required=True, help='Input JSON file (small)')
    parser.add_argument('-args.output_json', required=True, help='Output JSON file')
    parser.add_argument('-iterations', type=int, default=1, help='Number of iterations through big JSON array')
    args = parser.parse_args()    

    # Ensure input and output filenames ends with .json
    if not args.args.input_json_big.endswith('.json'):
        args.args.input_json_big += '.json'
    if not args.args.input_json_small.endswith('.json'):
        args.args.input_json_small += '.json'    
    if args.args.output_json and not args.args.output_json.endswith('.json'):
        args.args.output_json += '.json'    

    # Prepend 'jsons/' to the input and output JSON file paths
    args.args.input_json_big = os.path.join('jsons', args.args.input_json_big)
    args.args.input_json_small = os.path.join('jsons', args.args.input_json_small)
    args.args.output_json = os.path.join('jsons', args.args.output_json)

    main(args)
