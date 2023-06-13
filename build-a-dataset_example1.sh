#!/bin/bash

#TODO: Implement range option for prompter like 20-50 characters could be really useful. Might even implement short,medium,long so like randomly pick from array or range...
#jq '.[0:5]' jsons/character_pairs_with_scenario_moods > jsons/character_pairs_with_scenario_moods-truncated 
#Also should make promptIt make assistant prompt to "1. " if list size > 0 and not specified
#might consider prepending a number to make seeing where it stopped easier
#
#Vertical pipe would be far better so we can see end results in little time...
#Threading API requests a good idea...

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
python askIt.py   -input_json books_prompted -include_chat_history -model gpt-4 -resume 
python trimIt.py  -input_json books_asked -trim_blanks
python splitIt.py -input_json books_trimmed -new_key "book"

python promptIt.py -input_json books_split -output_json characters_prompted -list_size 4 \
    -first_prompt     "List four prolific **characters** from {book}. These character names in your list should represent individual entities within the context of the story capable of dialogue. Each entry in your response will be directly parsed into a JSON dataset so please ONLY provide the name of the **character** without further elaboration or commentary."\
    -next_prompt      "Now list four prolific **characters** from {book}. These character names in your list should represent individual entities within the context of the story capable of dialogue. Each entry in your response will be directly parsed into a JSON dataset so please ONLY provide the name of the **character** without further elaboration or commentary."\
    -assistant_prompt "1. "
python askIt.py   -input_json characters_prompted -include_chat_history -model gpt-4 -resume 
python trimIt.py  -input_json characters_asked -trim_blanks
python splitIt.py -input_json characters_trimmed  -new_key "character_name"

python promptIt.py -input_json characters_split -output_json characters_descriptions_prompted \
    -first_prompt     "Generate a short character description for {character_name} ({book}) that includes gender, age, MBTI and speech accent using 30 words or less." \
    -assistant_prompt "{character_name} Description: "
python askIt.py   -input_json characters_descriptions_prompted -model gpt-4 -resume 
python trimIt.py  -input_json characters_descriptions_asked -trim_blanks -trim_assistant_prompt
python splitIt.py -input_json characters_descriptions_trimmed -new_key "character_description"

python mixIt.py -input_json_big characters_descriptions_split -input_json_small characters_descriptions_split -output_json character_pairs -iterations 3

## Phase III Assigning each character Pair a scenario mood

python promptIt.py -output_json scenario_moods_prompted -list_size 20 \
    -first_prompt     "List {list_size} different **scenario** moods for a creative writing exercise. Your response will be used in the creation of a dataset so please ONLY provide the name of the mood." \
    -assistant_prompt "1. "
python askIt.py   -input_json scenario_moods_prompted -model gpt-4 -resume 
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
#PossibleAddition Note: When thinking of the scenario, keep in mind that the subsequent role-play dialogue will strictly involve these two characters. This means they will need to "narrate" the surrounding events within their own dialogue or actions. So the scenario should allow them to express the context of the scene through their perspective.
python promptIt.py -input_json character_pair_moods_mixed -output_json character_pair_moods_prompted -first_prompt "$first_prompt" -assistant_prompt "{character_name1}: {character_description1}\n\n{character_name2}: {character_description2}\n\nScenario Mood: {scenario_mood}\n\nScenario Prompt: "
python askIt.py    -input_json character_pair_moods_prompted -temperature 1.0 -top_p 0.9 -presence_penalty 0.4 -frequency_penalty 0.4 -model gpt-4 -resume 
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
python promptIt.py          -input_json character_pair_scenarios -output_json character_pair_scenarios_prompted -first_prompt "$first_prompt" -assistant_prompt "## Roleplay (asterisk format):\n{character_name1}: *"
python askIt_threaded.py    -input_json character_pair_scenarios_prompted -temperature 1.0 -top_p 0.9 -presence_penalty 0.3 -frequency_penalty 0.2 -max_tokens 3000 -model gpt-4 -max_threads 20 -resume
python trimIt.py            -input_json character_pair_scenarios_asked -last_line_starts_with "{character_name2}: " -trim_lines_from_end 4 -trim_assistant_prompt -trim_blanks
python splitIt.py           -input_json character_pair_scenarios_trimmed -new_key "conversation1"

first_prompt=$(cat <<'EOF'
Below is the first part of a character roleplay dialogue paired with two characters, a scenario, and an important note on roleplay guidelines. Progress the scene by writing part II of the dialogue using asterisk roleplay format. Each line in your response must be from the perspective of one of the characters (see format guidelines).

## {character_name1} ({book1}):
{character_description1}

## {character_name2} ({book2}):
{character_description2}

## Scenario:
{scenario}

## Roleplay Dialogue (Part I):
{character_name1}: *{conversation1}

## Roleplay Guidelines
Really think about who these characters are. Who is {character_name1}? Who is {character_name2}? What would {character_name1} think of {character_name2}? How would {character_name2} think of {character_name1}? Compare and contrast {character_name1} to {character_name2} and make sure {character_name1} acts and speaks like {character_name1} and {character_name2} acts and speaks like {character_name2}.
1. DO be creative and immersive.
2. DO use asterisks (*) to vividly describe character actions, thoughts, and sensations from the first-person perspective of one of the two characters.
3. DO start each message with a character's name. There should be no third-party narration or observations. The scene should unfold exclusively from the characters' viewpoints.
4. DO NOT include dialogue or actions from any characters outside "{character_name1}" and "{character_name2}".
5. DO NOT repeat the same dialogue due to uncertainty about how to progress the scene. Each line should move the narrative forward or add depth to the characters.
6. DO ensure that each line of dialogue clearly advances the scene. The characters' actions or decisions should drive the plot forward.
7. DO highlight the individuality of the characters. They should maintain distinct thoughts, plans, and actions, whether they are allies or adversaries. Actions and dialogue should reflect the character's individual perspectives and motivations.
EOF
)
python promptIt.py          -input_json character_pair_scenarios_split      -output_json character_pair_scenarios_prompted2 -first_prompt "$first_prompt" -assistant_prompt "## Roleplay Conversation (Part II):\n{character_name1}: *"
python askIt_threaded.py    -input_json character_pair_scenarios_prompted2  -output_json character_pair_scenarios_asked2    -temperature 1.0 -top_p 0.9 -presence_penalty 1.5 -frequency_penalty 0.3 -max_tokens 3000 -model gpt-4 -max_threads 20 -resume
python trimIt.py            -input_json character_pair_scenarios_asked2     -output_json character_pair_scenarios_trimmed2  -last_line_starts_with "{character_name2}: " -trim_lines_from_end 1 -trim_assistant_prompt -trim_blanks
python splitIt.py           -input_json character_pair_scenarios_trimmed2   -output_json character_pair_scenarios_split2    -new_key "conversation2"

first_prompt=$(cat <<'EOF'
Below is the first part of a character roleplay dialogue paired with two characters, a scenario, and an important note on roleplay guidelines. Progress the scene by writing part II of the dialogue using asterisk roleplay format. Each line in your response must be from the perspective of one of the characters (see format guidelines).

## {character_name1} ({book1}):
{character_description1}

## {character_name2} ({book2}):
{character_description2}

## Scenario:
{scenario}

## Roleplay Dialogue (Part I):
{character_name1}: *{conversation1}

{character_name1}: *{conversation2}

## Roleplay Guidelines
Really think about who these characters are. Who is {character_name1}? Who is {character_name2}? What would {character_name1} think of {character_name2}? How would {character_name2} think of {character_name1}? Compare and contrast {character_name1} to {character_name2} and make sure {character_name1} acts and speaks like {character_name1} and {character_name2} acts and speaks like {character_name2}.
1. DO be creative and immersive.
2. DO use asterisks (*) to vividly describe character actions, thoughts, and sensations from the first-person perspective of one of the two characters.
3. DO start each message with a character's name. There should be no third-party narration or observations. The scene should unfold exclusively from the characters' viewpoints.
4. DO NOT include dialogue or actions from any characters outside "{character_name1}" and "{character_name2}".
5. DO NOT repeat the same dialogue due to uncertainty about how to progress the scene. Each line should move the narrative forward or add depth to the characters.
6. DO ensure that each line of dialogue clearly advances the scene. The characters' actions or decisions should drive the plot forward.
7. DO highlight the individuality of the characters. They should maintain distinct thoughts, plans, and actions, whether they are allies or adversaries. Actions and dialogue should reflect the character's individual perspectives and motivations.
EOF
)
python promptIt.py          -input_json character_pair_scenarios_split2     -output_json character_pair_scenarios_prompted3 -first_prompt "$first_prompt" -assistant_prompt "## Roleplay Dialogue (Part II):\n{character_name1}: *"
python askIt_threaded.py    -input_json character_pair_scenarios_prompted3  -output_json character_pair_scenarios_asked3    -temperature 1.0 -top_p 0.9 -presence_penalty 1.0 -frequency_penalty 0.2 -max_tokens 4000 -model gpt-4 -max_threads 20 -resume
python trimIt.py            -input_json character_pair_scenarios_asked3     -output_json character_pair_scenarios_trimmed3  -last_line_starts_with "{character_name2}: " -trim_lines_from_end 1 -trim_assistant_prompt -trim_blanks
python splitIt.py           -input_json character_pair_scenarios_trimmed3   -output_json character_pair_scenarios_split3    -new_key "conversation3"

first_prompt=$(cat <<'EOF'
Below is the first part of a character roleplay dialogue paired with two characters, a scenario, and an important note on roleplay guidelines. Progress the scene by writing part II of the dialogue using asterisk roleplay format. Each line in your response must be from the perspective of one of the characters (see format guidelines).

## {character_name1} ({book1}):
{character_description1}

## {character_name2} ({book2}):
{character_description2}

## Scenario:
{scenario}

## Roleplay Dialogue (Part I):
{character_name1}: *{conversation1}

{character_name1}: *{conversation2}

{character_name1}: *{conversation3}

## Roleplay Guidelines
Really think about who these characters are. Who is {character_name1}? Who is {character_name2}? What would {character_name1} think of {character_name2}? How would {character_name2} think of {character_name1}? Compare and contrast {character_name1} to {character_name2} and make sure {character_name1} acts and speaks like {character_name1} and {character_name2} acts and speaks like {character_name2}.
1. DO be creative and immersive.
2. DO use asterisks (*) to vividly describe character actions, thoughts, and sensations from the first-person perspective of one of the two characters.
3. DO start each message with a character's name. There should be no third-party narration or observations. The scene should unfold exclusively from the characters' viewpoints.
4. DO NOT include dialogue or actions from any characters outside "{character_name1}" and "{character_name2}".
5. DO NOT repeat the same dialogue due to uncertainty about how to progress the scene. Each line should move the narrative forward or add depth to the characters.
6. DO ensure that each line of dialogue clearly advances the scene. The characters' actions or decisions should drive the plot forward.
7. DO highlight the individuality of the characters. They should maintain distinct thoughts, plans, and actions, whether they are allies or adversaries. Actions and dialogue should reflect the character's individual perspectives and motivations.
EOF
)
python promptIt.py          -input_json character_pair_scenarios_split3     -output_json character_pair_scenarios_prompted4 -first_prompt "$first_prompt" -assistant_prompt "## Roleplay Dialogue (Part II):\n{character_name1}: *"
python askIt_threaded.py    -input_json character_pair_scenarios_prompted4  -output_json character_pair_scenarios_asked4    -temperature 1.0 -top_p 0.9 -presence_penalty 1.0 -frequency_penalty 0.2 -max_tokens 4000 -model gpt-4 -max_threads 20 -resume
python trimIt.py            -input_json character_pair_scenarios_asked4     -output_json character_pair_scenarios_trimmed4  -last_line_starts_with "{character_name2}: " -trim_lines_from_end 1 -trim_assistant_prompt -trim_blanks
python splitIt.py           -input_json character_pair_scenarios_trimmed4   -output_json character_pair_scenarios_split4    -new_key "conversation4"

first_prompt=$(cat <<'EOF'
Write a character roleplay dialogue using asterisk roleplay format based on the following character descriptions and scenario. (Each line in your response must be from the perspective of one of these characters)

## Characters
{character_name1} ({book1}):
{character_description1}
{character_name2} ({book2}):
{character_description2}

## Scenario:
{scenario}
EOF
)
assistant_prompt=$(cat <<'EOF'
{character_name1}: *{conversation1}

{character_name1}: *{conversation2}

{character_name1}: *{conversation3}

{character_name1}: *{conversation4}
EOF
)
python promptIt.py  -input_json character_pair_scenarios_split4     -output_json RPGPT_PublicDomain_v1 -first_prompt "$first_prompt" -assistant_prompt "$assistant_prompt"
