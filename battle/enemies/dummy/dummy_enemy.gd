extends BattleEnemy
## Training dummy used for the tutorial battle.
##
## The player's first three turns are restricted to Attack, Defend, then Talk.
## Talking on the third turn wins the battle.

const DUMMY_TEXTURE := preload("res://assets/Textures/Gameplay/Objects/beach.svg")


func _init() -> void:
	display_name = "Dummy"
	max_hp = 100
	attack_damage = 0
	damage_variance = 0
	description = "A straw training dummy used for practice."
	texture = DUMMY_TEXTURE
	talk_lines = PackedStringArray([
		"You talk to the dummy. It listens politely.",
	])
	no_talk_lines_text = "The dummy does not respond."
	can_win_by_talking = true
	talks_to_win = 1
	talk_victory_text = "The dummy wobbles and falls over. You win!"
	turn_lines = PackedStringArray([
		"Turn 1: Attack the dummy!",
		"Turn 2: Defend yourself!",
		"Turn 3: Talk to the dummy!",
	])
	turn_action_restrictions = PackedStringArray([
		"attack",
		"defend",
		"talk",
	])
