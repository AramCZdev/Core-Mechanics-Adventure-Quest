extends BattleEnemy
## Broken TV enemy definition.
##
## A fourth-wall-breaking foe that glitches the battle screen, renames Talk to
## Cry, locks the player's HP to 20 for the fight, deals 5 HP on a missed block,
## and places triangle-marked squares on the attack bar that multiply damage by
## 1.5x. It can only be beaten by damage: crying never wins it.

const TV_TEXTURE := preload("res://assets/Textures/Gameplay/Objects/TV.png")


func _init() -> void:
	display_name = "Broken TV"
	max_hp = 500
	attack_damage = 5
	damage_variance = 0
	description = "A busted television that knows more about you than it should."
	texture = TV_TEXTURE

	# Instead of Talk the player Cries, and it never works.
	talk_action_label = "Cry"
	talk_lines = PackedStringArray([
		"You tried to cry but you have no eyes.",
	])
	no_talk_lines_text = "You tried to cry but you have no eyes."
	can_win_by_talking = false

	# The fight is unwinnable by talking; you have to damage it down to 0 HP.

	# The Broken TV forces your HP down to 20 for the duration of the battle.
	player_hp_override = 20

	# Visual CRT glitching / static jitter during the battle.
	is_glitching = true

	# Some attack-bar squares carry a triangle that multiplies damage by 1.5x.
	triangle_squares_enabled = true
	triangle_multiplier = 1.5

	# Fourth-wall-breaking turn lines that reference the player's operating system.
	var os_name := OS.get_name()
	turn_lines = PackedStringArray([
		"Your operating system (%s) is running hot." % os_name,
		"The Broken TV flickers in perfect sync with your monitor.",
		"I can see your desktop, %s." % os_name,
		"Your OS: %s. I know everything." % os_name,
		"Error 404: courage not found.",
		"Static fills your screen. Static fills your mind.",
	])

	intro_text = "A Broken TV blocks your path! It hums with static and knows your OS (%s)." % OS.get_name()
