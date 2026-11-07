extends BattleEnemy
## Monkey enemy definition.
##
## The Monkey cannot be beaten by damage or talking in a normal fight. Instead
## the player wins by surviving 20 full turns.

const MONKEY_TEXTURE := preload(
	"res://assets/Free Asset Packs/Monkey Forest Asset Pack/Player/Monkey Idle 1.png"
)

const SURVIVE_TURNS := 20


func _init() -> void:
	display_name = "Monkey"
	max_hp = 9999
	attack_damage = 50
	damage_variance = 2
	description = "A mischievous monkey that tests your endurance."
	can_win_by_talking = false
	turn_lines = PackedStringArray([
		"The Monkey chatters and bares its teeth.",
		"The Monkey bounces from foot to foot.",
		"The Monkey winds up another swing.",
		"The Monkey looks like it is enjoying this.",
	])
	survive_turns_to_win = SURVIVE_TURNS
	survival_victory_text = "You survived %d turns. The Monkey grows bored and lets you pass." % SURVIVE_TURNS
	texture = MONKEY_TEXTURE
