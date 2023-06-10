#!/bin/bash

#TODO: Implement range option for prompter like 20-50 characters could be really useful. Might even implement short,medium,long so like randomly pick from array or range...
#jq '.[0:5]' jsons/character_pairs_with_scenario_moods > jsons/character_pairs_with_scenario_moods-truncated 
#Also should make promptIt make assistant prompt to "1. " if list size > 0 and not specified
#might consider prepending a number to make seeing where it stopped easier

## Phase I Getting Pairs of Character Descriptions
python promptIt.py -output_json genres_prompted -list_size 10 \
    -first_prompt     "List the top {list_size} most famous genres of literary works in the public domain. Each entry in your response will be directly parsed into a JSON dataset so please ONLY provide the name of the **genre** without further elaboration or commentary." \
    -assistant_prompt "1. " 
python askIt.py   -input_json genres_prompted -resume -model gpt-4
python trimIt.py  -input_json genres_asked -trim_blanks
python splitIt.py -input_json genres_trimmed -new_key "genre"

python promptIt.py -input_json genres_split -output_json books_prompted -list_size 10 \
    -first_prompt     "List the top {list_size} most famous **{genre}** literary works in the public domain. Each entry in your response will be directly parsed into a JSON dataset so please ONLY provide the name of the **book** without further elaboration or commentary." \
    -next_prompt      "Now list the top {list_size} most famous **{genre}** literary works in the public domain. Each entry in your response will be directly parsed into a JSON dataset so please ONLY provide the name of the **book** without further elaboration or commentary." \
    -assistant_prompt "Genre: {genre}\n1. "
python askIt.py   -input_json books_prompted -include_chat_history -resume -model gpt-4
python trimIt.py  -input_json books_asked -trim_blanks
python splitIt.py -input_json books_trimmed -new_key "book"

python promptIt.py -input_json books_split -output_json characters_prompted -list_size 4 \
    -first_prompt     "List four prolific **characters** from {book}. These character names in your list should represent individual entities within the context of the story capable of dialogue. Each entry in your response will be directly parsed into a JSON dataset so please ONLY provide the name of the **character** without further elaboration or commentary."\
    -next_prompt      "Now list four prolific **characters** from {book}. These character names in your list should represent individual entities within the context of the story capable of dialogue. Each entry in your response will be directly parsed into a JSON dataset so please ONLY provide the name of the **character** without further elaboration or commentary."\
    -assistant_prompt "1. "
python askIt.py   -input_json characters_prompted -include_chat_history -resume -model gpt-4
python trimIt.py  -input_json characters_asked -trim_blanks
python splitIt.py -input_json characters_trimmed  -new_key "character_name"

python promptIt.py -input_json characters_split -output_json characters_descriptions_prompted \
    -first_prompt     "Generate a short character description for {character_name} ({book}) that includes gender, age, MBTI and speech accent using 30 words or less." \
    -assistant_prompt "{character_name} Description: "
python askIt.py   -input_json characters_descriptions_prompted -resume -model gpt-4
python trimIt.py  -input_json characters_descriptions_asked -trim_blanks -trim_assistant_prompt
python splitIt.py -input_json characters_descriptions_trimmed -new_key "character_description"

python mixIt.py -input_json_big characters_descriptions_split -input_json_small characters_descriptions_split -output_json character_pairs -iterations 3

## Phase III Assigning each character Pair a scenario mood

python promptIt.py -output_json scenario_moods_prompted -list_size 20 \
    -first_prompt     "List {list_size} different **scenario** moods for a creative writing exercise. Your response will be used in the creation of a dataset so please ONLY provide the name of the mood." \
    -assistant_prompt "1. "
python askIt.py   -input_json scenario_moods_prompted -resume -model gpt-4
python trimIt.py  -input_json scenario_moods_asked -trim_blanks
python splitIt.py -input_json scenario_moods_trimmed -new_key "scenario_mood"

python mixIt.py -input_json_big character_pairs -input_json_small scenario_moods_split -output_json character_pair_moods_mixed -iterations 1

## Phase IV Generating Scenarios for each character pair based on the assigned mood

first_prompt=$(cat <<'EOF'
Hey! I have a great idea for a creative writing exercise and I need your help. I've matched together pairs of characters from all kinds of literature in the public domain and I'd like you to think up an imaginative scenario prompt for how they might interact with eachother!
Some of these character pairs might be pretty weird because they were mixed together at random but that's part of the fun! Don't be afraid to push the narative a little let's say PG-13 at max but the writing exercise is for adults not kids.
Can I also request that the scenario is character centric? So like the location and conflict or objective should be built to facilitate an interesting dialogue of some sort that showcases the unique dynamic between them. 

The two characters for the scenario are **{character_name1}** from {book1} and **{character_name2}** from {book2}.
I want you to really think about who these chararacters are and how they'd interact.

Who is **{character_name1}**? Who is **{character_name2}**? What would they likely think of each other? How are they different or the same?
What would be an ideal **{scenario_mood}** setting and environment to contrast and explore the dynamic these characters might have through dialogue?
What might {character_name1} want from {character_name2}? Did {character_name2} force {character_name1} to be here or did they happen to just cross paths?
A good scenario prompt focuses on the dynamics between the characters. 

*Note: Your response is going to be added to a dataset where the above character descriptions will already be provided so please ONLY provide the scenario prompt you came up with.*
EOF
)
python promptIt.py -input_json character_pair_moods_mixed -output_json character_pair_moods_prompted -first_prompt "$first_prompt" -assistant_prompt "{character_name1}: {character_description1}\n\n{character_name2}: {character_description2}\n\nScenario Mood: {scenario_mood}\n\nScenario Prompt: "
python askIt.py    -input_json character_pair_moods_prompted -temperature 1.0 -top_p 0.9 -presence_penalty 0.4 -frequency_penalty 0.4 -resume -model gpt-4
python trimIt.py   -input_json character_pair_moods_asked -trim_blanks -trim_assistant_prompt
python splitIt.py  -input_json character_pair_moods_trimmed -output_json character_pair_scenarios -new_key "scenario"

## Part V Generating Roleplay Conversations
first_prompt=$(cat <<'EOF'
Generate a 2,000 token interaction between the following characters in asterisk roleplay format. Use asterisks to vividly describe character actions/sensations and do not wrap spoken word with double quotes. Your response will be used in a dataset to train a large language model about long form character roleplay.

## {character_name1} ({book1}):
{character_description1}

## {character_name2} ({book2}):
{character_description2}

## Scenario:
{scenario}

*Note: It's critical that the actions and dialogue match the characters as they are depicted in their descriptions. Every line in your response should alternate between "{character_name1}:" and "{character_name2}:"*
EOF
)
python promptIt.py -input_json character_pair_scenarios -output_json character_pair_scenarios_prompted -first_prompt "$first_prompt" -assistant_prompt "## Roleplay (asterisk format):\n{character_name1}: *"
python askIt.py    -input_json character_pair_scenarios_prompted -temperature 1.0 -top_p 0.9 -presence_penalty 0.3 -frequency_penalty 0.2 -max_tokens 3000 -resume -model gpt-4
python trimIt.py   -input_json character_pair_scenarios_asked -trim_lines_from_end 2 -last_line_starts_with "{character_name2}: " -trim_blanks

first_prompt=$(cat <<'EOF'
Please continue with the next 2000 tokens of the roleplay between {character_name1} and {character_name2}. 
Remember your response will be used in a dataset to train a large language model about long form character roleplay so it's critical that the actions and dialogue match the characters as they are depicted in their descriptions. 
Every line in your response should alternate between "{character_name1}:" and "{character_name2}:" -assistant_prompt "{character_name1}: *"
EOF
)
python promptIt.py -input_json character_pair_scenarios_trimmed   -output_json character_pair_scenarios_prompted2 -first_prompt "$first_prompt" -assistant_prompt "{character_name1}: *"
python askIt.py    -input_json character_pair_scenarios_prompted2 -output_json character_pair_scenarios_asked2 -temperature 1.0 -top_p 0.9 -presence_penalty 0.3 -frequency_penalty 0.2 -max_tokens 3000 -resume -model gpt-4
python trimIt.py   -input_json character_pair_scenarios_asked2    -output_json character_pair_scenarios_trimmed2 -trim_lines_from_end 2 -last_line_starts_with "{character_name2}: " -trim_blanks

python promptIt.py -input_json character_pair_scenarios_trimmed2  -output_json character_pair_scenarios_prompted3 -first_prompt "$first_prompt" -assistant_prompt "{character_name1}: *"
python askIt.py    -input_json character_pair_scenarios_prompted3 -output_json character_pair_scenarios_asked3 -temperature 1.0 -top_p 0.9 -presence_penalty 0.3 -frequency_penalty 0.2 -max_tokens 3000 -resume -model gpt-4
python trimIt.py   -input_json character_pair_scenarios_asked3    -output_json character_pair_scenarios_trimmed3 -trim_lines_from_end 2 -last_line_starts_with "{character_name2}: " -trim_blanks