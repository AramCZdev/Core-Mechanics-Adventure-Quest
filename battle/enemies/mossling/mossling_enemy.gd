extends BattleEnemy
## Mossling enemy definition.
##
## To make another enemy, duplicate this folder, rename the three files, then
## edit the defaults below. The .tres keeps the script reference, and the
## .tscn is a ready-to-run battle scene for this enemy.

func _init() -> void:
	display_name = "Mossling"
	max_hp = 60
	attack_damage = 12
	damage_variance = 2
	talk_lines = PackedStringArray([
		"The Mossling tilts its head.",
		"You compliment the Mossling's moss. It seems pleased.",
		"The Mossling is not much of a conversationalist.",
	])
	description = "A damp little creature guarding the forest path."
	can_win_by_talking = true
	talks_to_win = 3
	talk_victory_text = "The Mossling decides you are friendly and lets you pass."
	turn_lines = PackedStringArray([
		"The Mossling eyes you warily.",
		"The Mossling's leaves rustle.",
		"The Mossling seems to be listening.",
		"The Mossling is still not attacking.",
	])
	texture = preload("res://assets/Textures/Enemies/Moosling.png")
