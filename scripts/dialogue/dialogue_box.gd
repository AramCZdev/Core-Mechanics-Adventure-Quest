extends Control
class_name DialogueBox
## Presentation layer for the dialogue system.
##
## Listens to the DialogueManager autoload, renders the current node, animates
## text, and handles interact / choice navigation input.

const CHOICE_SCENE: PackedScene = preload("res://scenes/dialogue/dialogue_choice.tscn")

@export var dialogue_manager_path: NodePath = ^"/root/DialogueManager"

## Default reveal speed in characters per second. A node may override this
## with its optional `typing_speed` field. Zero means "show instantly".
@export_range(0.0, 240.0, 1.0, "suffix:chars/sec") var typing_speed: float = 35.0

## Used when a node has no portrait path, or when its portrait fails to load.
@export var default_portrait: Texture2D

## Pauses gameplay while a conversation is open. Disable this if your game
## needs to keep processing during dialogue.
@export var pause_gameplay: bool = true

@onready var _dialogue_panel: PanelContainer = %DialoguePanel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _portrait_frame: PanelContainer = %PortraitFrame
@onready var _portrait: TextureRect = %Portrait
@onready var _dialogue_text: RichTextLabel = %DialogueText
@onready var _continue_indicator: Label = %ContinueIndicator
@onready var _choices_panel: PanelContainer = %ChoicesPanel
@onready var _choice_list: VBoxContainer = %ChoiceList

var _manager: Node
var _is_open: bool = false
var _is_typing: bool = false
var _choices_open: bool = false
var _pending_choices: Array = []
var _choice_buttons: Array[DialogueChoice] = []
var _revealed_characters: float = 0.0
var _total_characters: int = 0
var _current_typing_speed: float = 35.0
var _blink_time: float = 0.0
var _was_tree_paused_before_dialogue: bool = false


func _ready() -> void:
    # Keep the box responsive even when gameplay is paused.
    process_mode = Node.PROCESS_MODE_ALWAYS
    hide()
    _choices_panel.hide()
    _continue_indicator.hide()
    _portrait_frame.hide()

    _manager = get_node_or_null(dialogue_manager_path)
    if _manager == null:
        push_error(
            "DialogueBox: manager not found at '%s'. Add the DialogueManager autoload."
            % dialogue_manager_path
        )
        set_process(false)
        set_process_input(false)
        return

    _manager.dialogue_started.connect(_on_dialogue_started)
    _manager.node_changed.connect(_on_node_changed)
    _manager.choices_presented.connect(_on_choices_presented)
    _manager.dialogue_finished.connect(_on_dialogue_finished)
    _manager.dialogue_error.connect(_on_dialogue_error)


func _process(delta: float) -> void:
    if not _is_open:
        return

    if _is_typing:
        if _current_typing_speed <= 0.0:
            _finish_typing()
            return

        _revealed_characters += _current_typing_speed * delta
        var shown := int(_revealed_characters)
        if shown >= _total_characters:
            _finish_typing()
        else:
            _dialogue_text.visible_characters = shown
        return

    if not _choices_open:
        _blink_time += delta
        _continue_indicator.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_blink_time * 4.0))


func _input(event: InputEvent) -> void:
    if not _is_open:
        return

    if event.is_action_pressed("interact"):
        _handle_interact()
        get_viewport().set_input_as_handled()
        return

    if not _choices_open:
        return

    if event.is_action_pressed("move_up"):
        _move_choice(-1)
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("move_down"):
        _move_choice(1)
        get_viewport().set_input_as_handled()


func _on_dialogue_started(_file_path: String, _start_node: String) -> void:
    _is_open = true
    _was_tree_paused_before_dialogue = get_tree().paused
    if pause_gameplay:
        get_tree().paused = true
    show()


func _on_node_changed(_node_id: String, node: Dictionary, portrait: Texture2D) -> void:
    if not _is_open:
        return

    _choices_open = false
    _pending_choices.clear()
    _clear_choice_buttons()
    _choices_panel.hide()
    _continue_indicator.hide()

    var speaker := str(node.get("speaker", ""))
    _speaker_label.text = speaker
    _speaker_label.visible = not speaker.strip_edges().is_empty()

    var resolved_portrait: Texture2D = portrait
    if resolved_portrait == null:
        resolved_portrait = default_portrait
    _portrait.texture = resolved_portrait
    _portrait_frame.visible = resolved_portrait != null

    _dialogue_text.text = str(node.get("text", ""))
    _dialogue_text.visible_characters = 0
    _total_characters = _dialogue_text.get_total_character_count()
    _revealed_characters = 0.0
    _current_typing_speed = _resolve_typing_speed(node)
    _is_typing = true

    if _total_characters <= 0 or _current_typing_speed <= 0.0:
        _finish_typing()


func _on_choices_presented(choices: Array) -> void:
    if not _is_open:
        return
    _pending_choices = choices.duplicate(true)
    if not _is_typing:
        _show_choices()


func _on_dialogue_finished(_file_path: String, _last_node_id: String) -> void:
    if not _is_open:
        return

    _is_open = false
    _is_typing = false
    _choices_open = false
    _pending_choices.clear()
    _clear_choice_buttons()
    _choices_panel.hide()
    _continue_indicator.hide()
    _dialogue_text.text = ""
    _speaker_label.text = ""
    _portrait.texture = null
    _portrait_frame.hide()
    hide()

    if pause_gameplay:
        get_tree().paused = _was_tree_paused_before_dialogue


func _on_dialogue_error(message: String) -> void:
    push_warning("DialogueBox: %s" % message)


func _handle_interact() -> void:
    if _is_typing:
        _finish_typing()
    elif _choices_open:
        _choose_focused_choice()
    else:
        _manager.advance()


func _finish_typing() -> void:
    _is_typing = false
    _dialogue_text.visible_characters = -1

    if not _pending_choices.is_empty():
        _show_choices()
    else:
        _blink_time = 0.0
        _continue_indicator.modulate.a = 1.0
        _continue_indicator.show()


func _resolve_typing_speed(node: Dictionary) -> float:
    if not node.has("typing_speed"):
        return typing_speed

    var value: Variant = node["typing_speed"]
    if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
        return maxf(0.0, float(value))
    return typing_speed


func _show_choices() -> void:
    if not _is_open or _pending_choices.is_empty():
        return

    _choices_open = true
    _continue_indicator.hide()
    _clear_choice_buttons()

    for index in _pending_choices.size():
        var choice_value: Variant = _pending_choices[index]
        if typeof(choice_value) != TYPE_DICTIONARY:
            continue

        var choice_data: Dictionary = choice_value
        var button := CHOICE_SCENE.instantiate() as DialogueChoice
        if button == null:
            continue

        button.setup(index, str(choice_data.get("text", "")))
        button.choice_chosen.connect(_on_choice_chosen)
        _choice_list.add_child(button)
        _choice_buttons.append(button)

    _pending_choices.clear()
    _choices_panel.show()

    if _choice_buttons.is_empty():
        _choices_open = false
        _continue_indicator.show()
        return

    _choice_buttons[0].call_deferred("grab_focus")


func _move_choice(direction: int) -> void:
    if _choice_buttons.is_empty():
        return

    var current_index := 0
    var focus_owner := get_viewport().gui_get_focus_owner()
    var found_index := _choice_buttons.find(focus_owner)
    if found_index >= 0:
        current_index = found_index

    var target_index := posmod(current_index + direction, _choice_buttons.size())
    _choice_buttons[target_index].grab_focus()


func _choose_focused_choice() -> void:
    if _choice_buttons.is_empty():
        return

    var selected_index := 0
    var focus_owner := get_viewport().gui_get_focus_owner()
    var found_index := _choice_buttons.find(focus_owner)
    if found_index >= 0:
        selected_index = found_index

    _on_choice_chosen(selected_index)


func _on_choice_chosen(index: int) -> void:
    if not _is_open or not _choices_open:
        return

    _choices_open = false
    _choices_panel.hide()
    _clear_choice_buttons()
    _pending_choices.clear()
    _manager.select_choice(index)


func _clear_choice_buttons() -> void:
    for child in _choice_list.get_children():
        _choice_list.remove_child(child)
        child.queue_free()
    _choice_buttons.clear()
