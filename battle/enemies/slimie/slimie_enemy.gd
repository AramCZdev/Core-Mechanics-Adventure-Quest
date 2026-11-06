extends BattleEnemy
## Mossling enemy definition.
##
## To make another enemy, duplicate this folder, rename the three files, then
## edit the defaults below. The .tres keeps the script reference, and the
## .tscn is a ready-to-run battle scene for this enemy.

func _init() -> void:
	display_name = "Slimie"
	max_hp = 60
	attack_damage = 12
	damage_variance = 2
	talk_lines = PackedStringArray([
		"The Slimie tilts its head.",
		"You compliment the Slimie stickines. It seems pleased.",
		"The Slimie wants to talk more.",
	])
	description = "Just a cute slime."
	can_win_by_talking = true
	talks_to_win = 3
	talk_victory_text = "The Slimie likes to talk with you."
	turn_lines = PackedStringArray([
		"The Slimie is scared.",
		"The Slimie is standing.",
		"The Slimie is remembering of how they attacked a tower.",
		"The Slimie is wobbly.",
	])
	texture = preload("res://assets/Textures/Enemies/Slimie.png")
