extends Control
class_name TimingBar
## Shared marker-and-zones widget used by AttackTiming and BlockTiming.
##
## Subclasses only describe their zones and defaults; movement, input handling,
## hit evaluation, and drawing live here so both timing mechanics behave the
## same way. Zones are ordered from most to least specific. The final zone
## should cover 0.0-1.0 as the fallback (Miss).
##
## This node is presentation-only. It emits `timing_finished` exactly once per
## `start()`; the battle UI forwards the result to BattleManager.

signal timing_finished(zone: String, value: float)
signal timing_timeout

## How many full bar widths the marker travels per second.
@export_range(0.05, 10.0, 0.05, "suffix:bars/sec") var marker_speed: float = 0.85

## Where the marker starts (0 = left edge, 1 = right edge).
@export_range(0.0, 1.0, 0.01) var marker_start: float = 0.0

## Input action used to stop the marker.
@export var input_action: StringName = &"attack"

## Additional actions that also stop the marker. By default both timing bars
## accept Z (attack), X (block), and Enter/Space (ui_accept).
@export var extra_input_actions: Array[StringName] = [&"block", &"ui_accept"]

## Safety net: after this many seconds the bar counts as a Miss with value 0
## (0 damage for attacks, 0% block). No timer is shown in the UI.
## Set to 0 to disable the timeout (the marker will bounce forever).
@export_range(0.0, 60.0, 0.5, "suffix:s") var input_timeout: float = 8.0

@export var track_color: Color = Color(0.07, 0.08, 0.11, 0.95)
@export var border_color: Color = Color(0.9, 0.9, 0.9, 1.0)
@export var marker_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var marker_position: float = 0.0
var is_active: bool = false
var last_zone: String = ""
var last_value: float = 0.0

var _direction: float = 1.0
var _elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	queue_redraw()


func start() -> void:
	is_active = true
	marker_position = clampf(marker_start, 0.0, 1.0)
	_direction = 1.0
	_elapsed = 0.0
	last_zone = ""
	last_value = 0.0
	show()
	set_process(true)
	queue_redraw()


func stop() -> void:
	is_active = false
	set_process(false)
	queue_redraw()


## Stops the marker now and emits the result. Returns the evaluated zone
## dictionary (empty if the bar was not active). Safe to call repeatedly:
## only the first call while active produces a signal.
func submit_now() -> Dictionary:
	if not is_active:
		return {}
	var result := evaluate_fraction(marker_position)
	_finish(result)
	return result


## Pure hit evaluation, also used by tests.
func evaluate_fraction(fraction: float) -> Dictionary:
	var value := clampf(fraction, 0.0, 1.0)
	for zone in _get_zones():
		var start: float = minf(float(zone.get("start", 0.0)), float(zone.get("end", 1.0)))
		var end: float = maxf(float(zone.get("start", 0.0)), float(zone.get("end", 1.0)))
		if value >= start and value <= end:
			return {
				"zone": str(zone.get("name", "Miss")),
				"value": float(zone.get("value", 0.0)),
			}
	return {"zone": "Miss", "value": 0.0}


## Override in subclasses. Ordered narrowest first; the last zone should span
## the whole bar as the fallback.
func _get_zones() -> Array[Dictionary]:
	return []


func _process(delta: float) -> void:
	if not is_active:
		return

	_elapsed += delta
	if input_timeout > 0.0 and _elapsed >= input_timeout:
		timing_timeout.emit()
		_finish(_timeout_result())
		return

	marker_position += _direction * marker_speed * delta
	while marker_position > 1.0 or marker_position < 0.0:
		if marker_position > 1.0:
			marker_position = 2.0 - marker_position
			_direction = -1.0
		elif marker_position < 0.0:
			marker_position = -marker_position
			_direction = 1.0

	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if _matches_stop_action(event):
		submit_now()
		get_viewport().set_input_as_handled()


func _matches_stop_action(event: InputEvent) -> bool:
	if InputMap.has_action(input_action) and event.is_action_pressed(input_action):
		return true
	for action in extra_input_actions:
		if action == input_action:
			continue
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return true
	return false


func _finish(result: Dictionary) -> void:
	last_zone = str(result.get("zone", "Miss"))
	last_value = float(result.get("value", 0.0))
	stop()
	timing_finished.emit(last_zone, last_value)


## Timeouts always count as a full miss: 0 damage or 0% block, regardless of
## the configured Miss value. Pressing late still uses the normal Miss zone.
func _timeout_result() -> Dictionary:
	var zones := _get_zones()
	if zones.is_empty():
		return {"zone": "Miss", "value": 0.0}
	var last: Dictionary = zones[zones.size() - 1]
	return {
		"zone": str(last.get("name", "Miss")),
		"value": 0.0,
	}


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, track_color)

	# Draw broad zones first so narrower (better) zones sit on top.
	var zones := _get_zones()
	for index in range(zones.size() - 1, -1, -1):
		var zone: Dictionary = zones[index]
		var start: float = minf(float(zone.get("start", 0.0)), float(zone.get("end", 1.0)))
		var end: float = maxf(float(zone.get("start", 0.0)), float(zone.get("end", 1.0)))
		var color: Color = zone.get("color", Color.WHITE)
		draw_rect(
			Rect2(size.x * start, 0.0, size.x * (end - start), size.y),
			color
		)

	draw_rect(rect, border_color, false, 3.0)

	var marker_x := clampf(marker_position, 0.0, 1.0) * size.x
	draw_rect(Rect2(marker_x - 2.0, -6.0, 4.0, size.y + 12.0), marker_color)
