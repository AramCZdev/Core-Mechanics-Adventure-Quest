extends SceneTree
## Headless smoke test for DialogueManager.
##
## Run with:
##   godot --headless --path . --script res://tests/dialogue_smoke_test.gd

var _manager: Node
var _failures: Array[String] = []
var _events: Array = []
var _errors: Array[String] = []
var _finished_count: int = 0


func _initialize() -> void:
    _manager = load("res://scripts/dialogue/dialogue_manager.gd").new()
    root.add_child(_manager)
    _manager.connect("event_triggered", _on_event)
    _manager.connect("dialogue_error", _on_error)
    _manager.connect("dialogue_finished", _on_finished)

    _test_example_flow()
    _test_multiple_sessions_guard()
    _test_start_node_override()
    _test_invalid_json()
    _test_missing_node()
    _test_missing_file()

    if _failures.is_empty():
        print("Dialogue smoke test: PASS")
        quit(0)
    else:
        for failure in _failures:
            push_error("Dialogue smoke test: " + failure)
        quit(1)


func _test_example_flow() -> void:
    _events.clear()
    _check(_start("res://dialogue/example_conversation.json"), "example dialogue starts")
    _check(_node_id() == "narrator_intro", "starts on start_node")

    _check(_call_bool("advance"), "advance to Mira")
    _check(_node_id() == "mira_greeting", "second node reached")
    _check(_has_event("met_mira"), "node event emitted")

    _check(_call_bool("advance"), "advance to offer")
    _check(_node_id() == "mira_offer", "offer node reached")
    _check(_call_bool("has_choices"), "offer has choices")

    _check(not _call_bool("advance"), "advance is refused while choosing")
    _check(_node_id() == "mira_offer", "refused advance does not move")

    _check(_call_bool("select_choice", 1), "choice selection works")
    _check(_node_id() == "mira_bargain", "choice branch reached")

    _check(_call_bool("advance"), "branch loops back")
    _check(_node_id() == "mira_offer", "looped to offer")

    _check(_call_bool("select_choice", 0), "accept choice works")
    _check(_node_id() == "mira_accept", "accept node reached")
    _check(_has_event("quest_started"), "choice event emitted")
    _check(_event_payload_has("quest_started", "quest_id", "relight_the_lantern"), "event payload is preserved")

    _check(_call_bool("advance"), "advance to farewell")
    _check(_node_id() == "mira_farewell", "farewell node reached")
    _check(_call_bool("advance"), "finishing last node succeeds")
    _check(not _is_active(), "dialogue ended")
    _check(_finished_count == 1, "finished signal emitted once")


func _test_multiple_sessions_guard() -> void:
    _check(_start("res://dialogue/example_conversation.json"), "guard test dialogue starts")
    _check(not _start("res://dialogue/merchant.json"), "second session is refused")
    _check(_is_active(), "first session remains active")
    _check(_errors.size() > 0, "second-session error emitted")
    _call_void("end_dialogue")
    _check(not _is_active(), "forced end clears active state")


func _test_start_node_override() -> void:
    _check(_start("merchant", "tobin_maps"), "shorthand path + start override works")
    _check(_node_id() == "tobin_maps", "override node reached")
    _check(_call_bool("advance"), "advance from override")
    _check(_node_id() == "tobin_goodbye", "override branch reached")
    _check(_call_bool("advance"), "final node ends")
    _check(not _is_active(), "override dialogue ended")


func _test_invalid_json() -> void:
    var path := "user://dialogue_invalid_test.json"
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string("{ this is not valid json")
    file.close()

    _check(not _start(path), "invalid JSON is refused")
    _check(not _is_active(), "invalid JSON leaves manager inactive")
    _check(_errors.size() > 0, "invalid JSON emits error")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_missing_node() -> void:
    var path := "user://dialogue_missing_node_test.json"
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(
        '{"start_node":"a","nodes":{"a":{"text":"Hello","next":"does_not_exist"}}}'
    )
    file.close()

    _check(_start(path), "missing-node dialogue starts")
    _check(_call_bool("advance"), "advance is processed")
    _check(not _is_active(), "missing node ends the session")
    _check(_errors.size() > 0, "missing node emits error")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_missing_file() -> void:
    _check(not _start("res://dialogue/does_not_exist.json"), "missing file is refused")
    _check(not _is_active(), "missing file leaves manager inactive")


func _start(path: String, start_node: String = "") -> bool:
    return bool(_manager.call("start_dialogue", path, start_node))


func _call_bool(method: String, argument: Variant = null) -> bool:
    if argument == null:
        return bool(_manager.call(method))
    return bool(_manager.call(method, argument))


func _call_void(method: String) -> void:
    _manager.call(method)


func _is_active() -> bool:
    return bool(_manager.get("is_active"))


func _node_id() -> String:
    return str(_manager.get("current_node_id"))


func _has_event(event_name: String) -> bool:
    for event in _events:
        if event[0] == event_name:
            return true
    return false


func _event_payload_has(event_name: String, key: String, expected: Variant) -> bool:
    for event in _events:
        if event[0] != event_name:
            continue
        var payload: Variant = event[1]
        if typeof(payload) == TYPE_DICTIONARY and payload.get(key, null) == expected:
            return true
    return false


func _on_event(event_name: String, payload: Variant) -> void:
    _events.append([event_name, payload])


func _on_error(message: String) -> void:
    _errors.append(message)


func _on_finished(_file_path: String, _last_node_id: String) -> void:
    _finished_count += 1


func _check(condition: bool, label: String) -> void:
    if not condition:
        _failures.append(label)
