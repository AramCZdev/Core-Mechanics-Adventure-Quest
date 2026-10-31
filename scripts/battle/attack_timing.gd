extends TimingBar
class_name AttackTiming
## Applies the attack damage multiplier based on marker accuracy.
##
## The bar runs left-to-right and bounces, so the player can retry a pass if
## they mistime it. Every zone is configurable in the inspector.

@export_range(0.0, 1.0, 0.01) var perfect_start: float = 0.45
@export_range(0.0, 1.0, 0.01) var perfect_end: float = 0.55
@export_range(0.0, 1.0, 0.01) var good_start: float = 0.30
@export_range(0.0, 1.0, 0.01) var good_end: float = 0.70

@export_range(0.1, 10.0, 0.1) var perfect_multiplier: float = 1.5
@export_range(0.1, 10.0, 0.1) var good_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.1) var miss_multiplier: float = 0.5

var _perfect_color: Color = Color(0.98, 0.78, 0.25, 0.9)
var _good_color: Color = Color(0.30, 0.72, 0.42, 0.8)
var _miss_color: Color = Color(0.55, 0.16, 0.20, 0.75)


func _init() -> void:
	input_action = &"attack"
	extra_input_actions = [&"block", &"ui_accept"]
	marker_speed = 0.85


func _get_zones() -> Array[Dictionary]:
	return [
		{
			"name": "Perfect",
			"start": perfect_start,
			"end": perfect_end,
			"value": perfect_multiplier,
			"color": _perfect_color,
		},
		{
			"name": "Good",
			"start": good_start,
			"end": good_end,
			"value": good_multiplier,
			"color": _good_color,
		},
		{
			"name": "Miss",
			"start": 0.0,
			"end": 1.0,
			"value": miss_multiplier,
			"color": _miss_color,
		},
	]


func get_legend() -> String:
	return "Perfect x%.1f   Good x%.1f   Miss x%.1f" % [
		perfect_multiplier,
		good_multiplier,
		miss_multiplier,
	]
