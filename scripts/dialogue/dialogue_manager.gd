extends Node
## Central controller for dialogue data and state.
##
## Register this script as the autoload singleton `DialogueManager`.
## UI components listen to its signals; gameplay code starts conversations,
## ends them, or connects to `event_triggered` for quest hooks.

signal dialogue_started(file_path: String, start_node: String)
signal node_changed(node_id: String, node: Dictionary, portrait: Texture2D)
signal choices_presented(choices: Array)
signal choice_made(choice_index: int, choice: Dictionary)
signal event_triggered(event_name: String, payload: Variant)
signal dialogue_finished(file_path: String, last_node_id: String)
signal dialogue_error(message: String)

const DEFAULT_DIALOGUE_DIRECTORY := "res://dialogue"

## True while a conversation is running. A second start is refused.
var is_active: bool = false
var current_file_path: String = ""
var current_node_id: String = ""
var current_node: Dictionary = {}
var current_choices: Array = []

var _nodes: Dictionary = {}
var _start_node_id: String = ""
var _portrait_cache: Dictionary = {}


## Starts a conversation from `dialogue_path`.
## Paths may be absolute resource paths or shorthand such as
## "example_conversation" / "example_conversation.json".
func start_dialogue(dialogue_path: String, start_node: String = "") -> bool:
    if is_active:
        _report_error(
            "A dialogue session is already active. Finish it before starting another."
        )
        return false

    var resolved_path := _resolve_dialogue_path(dialogue_path)
    var load_result := _load_json_file(resolved_path)
    if not load_result["ok"]:
        _report_error(str(load_result["error"]))
        return false

    var root: Dictionary = load_result["data"]
    var nodes_value: Variant = root.get("nodes", null)
    if typeof(nodes_value) != TYPE_DICTIONARY:
        _report_error(
            "Dialogue file '%s' must contain a 'nodes' object." % resolved_path
        )
        return false

    var nodes: Dictionary = nodes_value
    if nodes.is_empty():
        _report_error("Dialogue file '%s' contains no nodes." % resolved_path)
        return false

    var requested_start := start_node.strip_edges()
    if requested_start.is_empty():
        requested_start = str(root.get("start_node", root.get("start", ""))).strip_edges()
    if requested_start.is_empty():
        requested_start = str(nodes.keys()[0])

    if not nodes.has(requested_start):
        _report_error(
            "Start node '%s' was not found in '%s'." % [requested_start, resolved_path]
        )
        return false
    if typeof(nodes[requested_start]) != TYPE_DICTIONARY:
        _report_error(
            "Start node '%s' in '%s' must be an object." % [requested_start, resolved_path]
        )
        return false

    current_file_path = resolved_path
    current_node_id = ""
    current_node = {}
    current_choices = []
    _nodes = nodes
    _start_node_id = requested_start
    is_active = true

    dialogue_started.emit(current_file_path, _start_node_id)
    _enter_node(_start_node_id)
    return true


## Advances to the current node's `next` node, or ends the conversation.
## Returns false when there is no active session or a choice must be made.
func advance() -> bool:
    if not is_active:
        return false
    if not current_choices.is_empty():
        return false

    var next_id := _node_id_from(current_node.get("next", ""))
    if next_id.is_empty():
        end_dialogue()
    else:
        _enter_node(next_id)
    return true


## Selects a choice by its index in the most recently presented choice list.
func select_choice(choice_index: int) -> bool:
    if not is_active:
        _report_error("Cannot select a choice: no dialogue session is active.")
        return false
    if current_choices.is_empty():
        _report_error("Cannot select a choice: the current node has no choices.")
        return false
    if choice_index < 0 or choice_index >= current_choices.size():
        _report_error(
            "Choice index %d is out of range (0-%d)."
            % [choice_index, current_choices.size() - 1]
        )
        return false

    var choice: Dictionary = current_choices[choice_index]
    current_choices = []

    choice_made.emit(choice_index, choice.duplicate(true))
    _emit_event_from(choice)

    var next_id := _node_id_from(choice.get("next", ""))
    if next_id.is_empty():
        end_dialogue()
    else:
        _enter_node(next_id)
    return true


## Ends the active conversation immediately. Safe to call at any time.
func end_dialogue() -> void:
    if not is_active:
        return

    var finished_file := current_file_path
    var finished_node := current_node_id
    _clear_state()
    dialogue_finished.emit(finished_file, finished_node)


func has_choices() -> bool:
    return is_active and not current_choices.is_empty()


func _enter_node(node_id: String) -> void:
    if not _nodes.has(node_id):
        _fail_and_end(
            "Dialogue node '%s' was not found in '%s'." % [node_id, current_file_path]
        )
        return

    var node_value: Variant = _nodes[node_id]
    if typeof(node_value) != TYPE_DICTIONARY:
        _fail_and_end(
            "Dialogue node '%s' in '%s' must be an object." % [node_id, current_file_path]
        )
        return

    var node_data: Dictionary = node_value
    var choice_result := _build_choices(node_data, node_id)
    if not choice_result["ok"]:
        _fail_and_end(str(choice_result["error"]))
        return

    current_node_id = node_id
    current_node = node_data.duplicate(true)
    current_choices = choice_result["choices"]

    var portrait := _load_portrait(_node_id_from(node_data.get("portrait", "")))
    node_changed.emit(
        current_node_id,
        current_node.duplicate(true),
        portrait
    )

    _emit_event_from(current_node)

    if not current_choices.is_empty():
        choices_presented.emit(current_choices.duplicate(true))


func _build_choices(node_data: Dictionary, node_id: String) -> Dictionary:
    var raw_choices: Variant = node_data.get("choices", [])
    if raw_choices == null:
        return {"ok": true, "choices": []}
    if typeof(raw_choices) != TYPE_ARRAY:
        return {
            "ok": false,
            "error": "Node '%s' has a 'choices' field that is not an array." % node_id,
        }

    var parsed_choices: Array = []
    for index in raw_choices.size():
        var raw_choice: Variant = raw_choices[index]
        if typeof(raw_choice) != TYPE_DICTIONARY:
            return {
                "ok": false,
                "error": "Choice %d in node '%s' must be an object." % [index, node_id],
            }

        var choice: Dictionary = raw_choice
        var choice_text := str(choice.get("text", ""))
        if choice_text.strip_edges().is_empty():
            return {
                "ok": false,
                "error": "Choice %d in node '%s' is missing 'text'." % [index, node_id],
            }

        var cleaned := choice.duplicate(true)
        cleaned["text"] = choice_text
        cleaned["next"] = _node_id_from(choice.get("next", ""))
        parsed_choices.append(cleaned)

    return {"ok": true, "choices": parsed_choices}


func _emit_event_from(source: Dictionary) -> void:
    if not source.has("event"):
        return

    var event_value: Variant = source["event"]
    if typeof(event_value) == TYPE_STRING:
        var event_name := str(event_value).strip_edges()
        if not event_name.is_empty():
            event_triggered.emit(event_name, null)
        return

    if typeof(event_value) == TYPE_DICTIONARY:
        var event_data: Dictionary = event_value
        var event_name := str(event_data.get("name", "")).strip_edges()
        if event_name.is_empty():
            push_warning("DialogueManager: 'event' object is missing a 'name'.")
            return
        event_triggered.emit(event_name, event_data.get("data", null))
        return

    push_warning("DialogueManager: 'event' must be a string or an object.")


func _load_json_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"ok": false, "error": "Dialogue file not found: %s" % path}

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {
            "ok": false,
            "error": "Could not open dialogue file '%s' (error %d)."
            % [path, FileAccess.get_open_error()],
        }

    var text := file.get_as_text()
    file.close()

    var json := JSON.new()
    var parse_error := json.parse(text)
    if parse_error != OK:
        return {
            "ok": false,
            "error": "Invalid JSON in '%s' at line %d: %s"
            % [path, json.get_error_line(), json.get_error_message()],
        }

    if typeof(json.data) != TYPE_DICTIONARY:
        return {
            "ok": false,
            "error": "Dialogue file '%s' must contain a JSON object at its root." % path,
        }

    return {"ok": true, "error": "", "data": json.data}


func _load_portrait(path: String) -> Texture2D:
    if path.is_empty():
        return null
    if _portrait_cache.has(path):
        return _portrait_cache[path]

    if not ResourceLoader.exists(path, "Texture2D"):
        push_warning("DialogueManager: portrait texture not found: %s" % path)
        _portrait_cache[path] = null
        return null

    var resource := ResourceLoader.load(path, "Texture2D")
    if resource is Texture2D:
        var texture := resource as Texture2D
        _portrait_cache[path] = texture
        return texture

    push_warning("DialogueManager: '%s' is not a Texture2D." % path)
    _portrait_cache[path] = null
    return null


func _resolve_dialogue_path(path: String) -> String:
    var cleaned := path.strip_edges()
    if cleaned.begins_with("res://") or cleaned.begins_with("user://"):
        return cleaned
    if cleaned.get_extension().is_empty():
        cleaned += ".json"
    return DEFAULT_DIALOGUE_DIRECTORY.path_join(cleaned)


func _node_id_from(value: Variant) -> String:
    if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
        return String(value).strip_edges()
    return ""


func _fail_and_end(message: String) -> void:
    _report_error(message)
    end_dialogue()


func _report_error(message: String) -> void:
    push_warning("DialogueManager: %s" % message)
    dialogue_error.emit(message)


func _clear_state() -> void:
    is_active = false
    current_file_path = ""
    current_node_id = ""
    current_node = {}
    current_choices = []
    _nodes = {}
    _start_node_id = ""
