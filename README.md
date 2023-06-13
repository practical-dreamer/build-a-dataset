<p align="center">
  <img src="https://github.com/practicaldreamer/build-a-dataset/assets/78515588/79520f21-8d36-4431-b2bf-8574732dac5d" />
</p>

# Build-A-Dataset

A suite of tools designed for constructing complex and unique datasets by recursively prompt-chainging responses from OpenAI API. Initially conceived to generate datasets for character roleplay, this toolset can be adapted to fit a wide variety of use-cases. Still under active development, may contain bugs. Contributions are welcome.

## Scripts and Data Flow

This suite uses a series of JSON files to pass data between the different scripts. Below, you can see each script along with its input and output files.

1. **promptIt.py**: Generates an array of messages to be sent to the OpenAI API.

    ```bash
    python promptIt.py -input_json <input_file> -output_json <output_file> -list_size <number> -first_prompt <prompt> -next_prompt <prompt> -assistant_prompt <prompt>
    ```

2. **askIt.py**: Fills in responses using the OpenAI API.
*threaded version does same thing without verbose terminal output and doesn't support compounding last objects messages... as this is serialized by nature... I plan to merge the two*

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
6. **conformIt.py**: Finalizes dataset by conforming a prompted script to alpaca or shareGPT format for training.

    ```bash
    python conformIt.py -input_json <prompted_json> -output_json <formatted_json> -format <"Alpaca" or "ShareGPT">
    ```

## Environmental Variables

The `askIt.py` script expects the following environment variables to be set or passed via arguments:

- `openai.api_key`: Your OpenAI API key.
- `openai.api_base`: The base URL for the OpenAI API.

## Example Usage: build-a-dataset_example_rpgptv1.sh

Included in the repository is `build-a-dataset_example_rpgptv1.sh`, a script demonstrating a possible way to chain together these tools to build a comprehensive dataset of role-play conversations between characters in the public domain (think Sherlock Holmes and Peter Pan). It progresses through the following steps:

1. Retrieving genres.
2. Acquiring books from those genres.
3. Extracting characters from those books.
4. Randomly pairing characters.
5. Gathering scenario moods.
6. Mixing the character pairs with scenario moods.
7. Generating scenarios based on these character pairs and moods.
8. Creating roleplay conversations from the scenarios with moods and character pairs.
9. Conforming output to ShareGPT and Alpaca Formats

Please note that this is just one example of the multitude of applications for these scripts.

# Disclaimer

This project is currently under active development and may still contain bugs. While the scripts have been designed to work for a specific use case, extensive testing has yet to be performed. The functionality of the scripts can vary depending on the data and tasks. Please use them with this understanding. 

I welcome contributions to improve this project. If you find any issues or have suggestions, please open an issue or submit a pull request.

## License

The Build-A-Dataset project is licensed under the [MIT license](LICENSE).
