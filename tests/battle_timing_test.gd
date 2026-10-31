extends SceneTree
## Headless tests for AttackTiming and BlockTiming zones, signals, and timeouts.
##
## Run with:
##   godot --headless --path . --script res://tests/battle_timing_test.gd

var _failures: Array[String] = []
var _attack: AttackTiming
var _block: BlockTiming
var _attack_signals: Array = []
var _block_signals: Array = []


func _initialize() -> void:
	_attack = load("res://scenes/battle/attack_timing.tscn").instantiate() as AttackTiming
	_block = load("res://scenes/battle/block_timing.tscn").instantiate() as BlockTiming
	root.add_child(_attack)
	root.add_child(_block)
	await process_frame

	_attack.timing_finished.connect(_on_attack_finished)
	_block.timing_finished.connect(_on_block_finished)

	_test_attack_zones()
	_test_block_zones()
	_test_attack_signal_and_repeat_guard()
	_test_attack_input_action()
	_test_shared_timing_inputs()
	_test_marker_movement()
	_test_timeout_counts_as_zero()
	_test_configurable_zones()

	if _failures.is_empty():
		print("Battle timing test: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("Battle timing test: " + failure)
		quit(1)


func _test_attack_zones() -> void:
	_check(_attack.input_action == &"attack", "attack bar uses attack action")
	_check(_attack.evaluate_fraction(0.50)["zone"] == "Perfect", "attack center is Perfect")
	_check(is_equal_approx(_attack.evaluate_fraction(0.50)["value"], 1.5), "Perfect is 1.5x")
	_check(_attack.evaluate_fraction(0.35)["zone"] == "Good", "attack 0.35 is Good")
	_check(is_equal_approx(_attack.evaluate_fraction(0.35)["value"], 1.0), "Good is 1.0x")
	_check(_attack.evaluate_fraction(0.10)["zone"] == "Miss", "attack 0.10 is Miss")
	_check(is_equal_approx(_attack.evaluate_fraction(0.10)["value"], 0.5), "Miss is 0.5x")


func _test_block_zones() -> void:
	_check(_block.input_action == &"block", "block bar uses block action")
	_check(_block.evaluate_fraction(0.50)["zone"] == "Perfect", "block center is Perfect")
	_check(is_equal_approx(_block.evaluate_fraction(0.50)["value"], 1.0), "Perfect blocks 100%")
	_check(_block.evaluate_fraction(0.35)["zone"] == "Good", "block 0.35 is Good")
	_check(is_equal_approx(_block.evaluate_fraction(0.35)["value"], 0.75), "Good blocks 75%")
	_check(_block.evaluate_fraction(0.20)["zone"] == "Partial", "block 0.20 is Partial")
	_check(is_equal_approx(_block.evaluate_fraction(0.20)["value"], 0.5), "Partial blocks 50%")
	_check(_block.evaluate_fraction(0.05)["zone"] == "Miss", "block 0.05 is Miss")
	_check(is_equal_approx(_block.evaluate_fraction(0.05)["value"], 0.0), "Miss blocks 0%")


func _test_attack_signal_and_repeat_guard() -> void:
	_attack_signals.clear()
	_attack.start()
	_attack.marker_position = 0.5
	var result := _attack.submit_now()
	_check(result["zone"] == "Perfect", "submit_now returns evaluated zone")
	_check(_attack_signals.size() == 1, "attack emits exactly one result")
	_check(_attack_signals[0] == ["Perfect", 1.5], "attack signal payload")
	_check(not _attack.is_active, "attack deactivates after submit")

	var repeated := _attack.submit_now()
	_check(repeated.is_empty(), "repeated submit returns empty")
	_check(_attack_signals.size() == 1, "repeated submit does not emit")


func _test_attack_input_action() -> void:
	_attack_signals.clear()
	_attack.input_timeout = 8.0
	_attack.start()
	_attack.marker_position = 0.5
	var event := InputEventAction.new()
	event.action = &"attack"
	event.pressed = true
	_attack._input(event)
	_check(_attack_signals.size() == 1, "attack input action stops the marker")
	_check(_attack_signals[0] == ["Perfect", 1.5], "input action evaluates the zone")
	_attack._input(event)
	_check(_attack_signals.size() == 1, "second input action is ignored")


func _test_shared_timing_inputs() -> void:
	_attack_signals.clear()
	_attack.start()
	_attack.marker_position = 0.5
	_send_action(_attack, &"block")
	_check(_attack_signals.size() == 1, "attack bar also accepts X/block")

	_attack_signals.clear()
	_attack.start()
	_attack.marker_position = 0.5
	_send_action(_attack, &"ui_accept")
	_check(_attack_signals.size() == 1, "attack bar also accepts Enter/ui_accept")

	_block_signals.clear()
	_block.start()
	_block.marker_position = 0.5
	_send_action(_block, &"attack")
	_check(_block_signals.size() == 1, "block bar also accepts Z/attack")

	_block_signals.clear()
	_block.start()
	_block.marker_position = 0.5
	_send_action(_block, &"ui_accept")
	_check(_block_signals.size() == 1, "block bar also accepts Enter/ui_accept")


func _send_action(bar: TimingBar, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	bar._input(event)


func _test_marker_movement() -> void:
	_attack_signals.clear()
	_attack.marker_speed = 1.0
	_attack.input_timeout = 0.0
	_attack.start()
	_attack._process(0.25)
	_check(is_equal_approx(_attack.marker_position, 0.25), "marker moves at configured speed")
	_attack._process(1.0)
	_check(_attack.marker_position >= 0.0 and _attack.marker_position <= 1.0, "marker stays inside bar")
	_check(is_equal_approx(_attack.marker_position, 0.75), "marker bounces off right edge")
	_attack.stop()


func _test_timeout_counts_as_zero() -> void:
	_attack_signals.clear()
	_attack.input_timeout = 0.1
	_attack.start()
	_attack._process(0.2)
	_check(_attack_signals.size() == 1, "attack timeout emits one result")
	_check(_attack_signals[0] == ["Miss", 0.0], "attack timeout deals 0 damage")
	_check(not _attack.is_active, "attack timeout deactivates the bar")

	_block_signals.clear()
	_block.input_timeout = 0.1
	_block.start()
	_block._process(0.2)
	_check(_block_signals.size() == 1, "block timeout emits one result")
	_check(_block_signals[0] == ["Miss", 0.0], "block timeout gives 0% block")
	_check(not _block.is_active, "block timeout deactivates the bar")


func _test_configurable_zones() -> void:
	_attack.perfect_start = 0.20
	_attack.perfect_end = 0.30
	_check(_attack.evaluate_fraction(0.25)["zone"] == "Perfect", "custom attack perfect range works")
	_check(_attack.evaluate_fraction(0.50)["zone"] == "Good", "old perfect spot becomes Good")

	_block.good_start = 0.25
	_block.good_end = 0.75
	_check(_block.evaluate_fraction(0.30)["zone"] == "Good", "custom block good range works")
	_check(is_equal_approx(_block.evaluate_fraction(0.30)["value"], 0.75), "custom block value preserved")


func _on_attack_finished(zone: String, value: float) -> void:
	_attack_signals.append([zone, value])


func _on_block_finished(zone: String, value: float) -> void:
	_block_signals.append([zone, value])


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
