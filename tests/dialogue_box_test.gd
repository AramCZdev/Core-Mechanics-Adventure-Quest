extends Node
## Headless integration test for DialogueBox input, typewriter, and choices.
##
## Run as a scene (so the DialogueManager autoload exists):
##   godot --headless --path . res://tests/dialogue_box_test.tscn

var _failures: Array[String] = []
var _box: Control
var _manager: Node


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _manager = get_node("/root/DialogueManager")

    _box = load("res://scenes/dialogue/dialogue_box.tscn").instantiate()
    _box.set("pause_gameplay", false)
    add_child(_box)
    await get_tree().process_frame

    await _run_test()

    if _failures.is_empty():
        print("Dialogue box test: PASS")
        get_tree().quit(0)
    else:
        for failure in _failures:
            push_error("Dialogue box test: " + failure)
        get_tree().quit(1)


func _run_test() -> void:
    _check(not _box.visible, "box is hidden before dialogue")

    var trigger_script: Script = load("res://scripts/dialogue/dialogue_trigger.gd")
    _check(trigger_script != null, "optional DialogueTrigger script loads")

    var dialogue_text: RichTextLabel = _box.get_node("%DialogueText")
    var indicator: Label = _box.get_node("%ContinueIndicator")
    var choices_panel: PanelContainer = _box.get_node("%ChoicesPanel")
    var choice_list: VBoxContainer = _box.get_node("%ChoiceList")
    var dialogue_panel: PanelContainer = _box.get_node("%DialoguePanel")

    _check(bool(_manager.call("start_dialogue", "res://dialogue/example_conversation.json")), "dialogue starts")
    _check(_box.visible, "box is visible during dialogue")
    _check(dialogue_text.visible_characters == 0, "text starts hidden for typewriter")
    _check(not indicator.visible, "continue indicator hidden while typing")

    await get_tree().process_frame
    _check(dialogue_text.text != "", "node text is rendered")

    await _press("interact")
    _check(dialogue_text.visible_characters == -1, "interact finishes typewriter")
    _check(indicator.visible, "continue indicator appears after typing")

    await _press("interact")
    _check(str(_manager.get("current_node_id")) == "mira_greeting", "interact advances node")

    await _press("interact")
    await _press("interact")
    _check(str(_manager.get("current_node_id")) == "mira_offer", "second advance works")

    await _press("interact")
    _check(choices_panel.visible, "choices appear after typing")
    _check(choice_list.get_child_count() == 3, "all choices are created")
    _check(not indicator.visible, "indicator hides while choosing")
    await get_tree().process_frame
    _check(choices_panel.size.y > 0.0, "choice panel has a layout height")
    _check(
        choices_panel.position.y + choices_panel.size.y <= dialogue_panel.position.y,
        "choice panel sits above the dialogue box"
    )

    await get_tree().process_frame
    await _press("move_down")
    var focus_owner := get_viewport().gui_get_focus_owner()
    _check(focus_owner == choice_list.get_child(1), "down key moves choice focus")

    await _press("move_up")
    focus_owner = get_viewport().gui_get_focus_owner()
    _check(focus_owner == choice_list.get_child(0), "up key moves choice focus")

    await _press("move_down")
    await _press("interact")
    _check(str(_manager.get("current_node_id")) == "mira_bargain", "interact selects focused choice")
    _check(not choices_panel.visible, "choices hide after selection")

    _manager.call("end_dialogue")
    await get_tree().process_frame
    _check(not _box.visible, "box hides when dialogue ends")

    await _test_pause_behavior()


func _test_pause_behavior() -> void:
    _box.set("pause_gameplay", true)
    _check(bool(_manager.call("start_dialogue", "res://dialogue/merchant.json")), "pause test dialogue starts")
    _check(get_tree().paused, "tree pauses during dialogue")

    var dialogue_text: RichTextLabel = _box.get_node("%DialogueText")
    await get_tree().process_frame
    await _press("interact")
    _check(dialogue_text.visible_characters == -1, "input still works while paused")

    _manager.call("end_dialogue")
    await get_tree().process_frame
    _check(not get_tree().paused, "tree unpauses after dialogue")
    _check(not _box.visible, "box hides after paused dialogue")


func _press(action: String) -> void:
    var press_event := InputEventAction.new()
    press_event.action = action
    press_event.pressed = true
    Input.parse_input_event(press_event)

    var release_event := InputEventAction.new()
    release_event.action = action
    release_event.pressed = false
    Input.parse_input_event(release_event)

    await get_tree().process_frame
    await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
    if not condition:
        _failures.append(label)
