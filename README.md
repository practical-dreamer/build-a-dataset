# Build-A-Dataset

A suite of tools designed for constructing complex and unique datasets by interacting with the OpenAI API. Initially conceived to generate datasets for role-playing characters, this toolset can be adapted to fit a wide variety of use-cases.

## Scripts

1. **promptIt.py**: Generates an array of messages to be sent to the OpenAI API.

    ```bash
    python promptIt.py -input_json <input_file> -output_json <output_file> -list_size <number> -first_prompt <prompt> -next_prompt <prompt> -assistant_prompt <prompt>
    ```

2. **askIt.py**: Fills in responses using the OpenAI API.

    ```bash
    python askIt.py -input_json <input_file> -output_json <output_file> -include_chat_history -max_chat_history <number> -resume -api_key <api_key> -api_url <api_url> -model <model> -temperature <value> -top_p <value> -presence_penalty <value> -frequency_penalty <value> -max_tokens <number>
    ```

3. **trimIt.py**: Trims responses obtained from the OpenAI API.

    ```bash
    python trimIt.py -input_json <input_file> -output_json <output_file> -trim_lines_from_start <number> -trim_lines_from_end <number> -trim_assistant_prompt -trim_blanks -last_line_starts_with <string>
    ```

4. **splitIt.py**: Splits API responses into properties, discarding the conversation.

    ```bash
    python splitIt.py -input_json <input_file> -output_json <output_file> -split_on <string> -new_key <key>
    ```

5. **mixIt.py**: Randomly matches a left dataset with a right dataset.

    ```bash
    python mixIt.py -input_json_big <big_input_file> -input_json_small <small_input_file> -output_json <output_file> -iterations <number>
    ```

## Environmental Variables

The `askIt.py` script expects the following environment variables to be set:

- `openai.api_key`: Your OpenAI API key.
- `openai.api_base`: The base URL for the OpenAI API.

## Usage

These scripts can be invoked individually, passing the output from one as the input to another. Alternatively, they can be chained together in a shell script.

## Contribute

This project welcomes contributions from the community. Feel free to create an issue or open a pull request.

## License

The Build-A-Dataset project is licensed under the [MIT license](LICENSE).
