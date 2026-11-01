extends TimingBar
class_name BlockTiming
## Applies damage reduction based on marker accuracy.
##
## Perfect - 100% reduction, Good - 75%, Partial - 50%, Miss - 0%.
## Ranges and values are configurable in the inspector.

@export_range(0.0, 1.0, 0.01) var perfect_start: float = 0.45
@export_range(0.0, 1.0, 0.01) var perfect_end: float = 0.55
@export_range(0.0, 1.0, 0.01) var good_start: float = 0.30
@export_range(0.0, 1.0, 0.01) var good_end: float = 0.70
@export_range(0.0, 1.0, 0.01) var partial_start: float = 0.15
@export_range(0.0, 1.0, 0.01) var partial_end: float = 0.85

@export_range(0.0, 1.0, 0.01) var perfect_reduction: float = 1.0
@export_range(0.0, 1.0, 0.01) var good_reduction: float = 0.75
@export_range(0.0, 1.0, 0.01) var partial_reduction: float = 0.5
@export_range(0.0, 1.0, 0.01) var miss_reduction: float = 0.0

var _perfect_color: Color = Color(0.98, 0.78, 0.25, 0.9)
var _good_color: Color = Color(0.30, 0.72, 0.42, 0.8)
var _partial_color: Color = Color(0.85, 0.55, 0.22, 0.75)
var _miss_color: Color = Color(0.55, 0.16, 0.20, 0.75)


func _init() -> void:
	input_action = &"block"
	extra_input_actions = [&"attack", &"ui_accept"]
	marker_speed = 1.15
	squares_enabled = true


func _get_zones() -> Array[Dictionary]:
	return [
		{
			"name": "Perfect",
			"start": perfect_start,
			"end": perfect_end,
			"value": perfect_reduction,
			"color": _perfect_color,
		},
		{
			"name": "Good",
			"start": good_start,
			"end": good_end,
			"value": good_reduction,
			"color": _good_color,
		},
		{
			"name": "Partial",
			"start": partial_start,
			"end": partial_end,
			"value": partial_reduction,
			"color": _partial_color,
		},
		{
			"name": "Miss",
			"start": 0.0,
			"end": 1.0,
			"value": miss_reduction,
			"color": _miss_color,
		},
	]


func get_legend() -> String:
	return "Perfect %d%%   Good %d%%   Partial %d%%   Miss %d%%" % [
		roundi(perfect_reduction * 100.0),
		roundi(good_reduction * 100.0),
		roundi(partial_reduction * 100.0),
		roundi(miss_reduction * 100.0),
	]
