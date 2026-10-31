extends Control
## Standalone demo harness for the dialogue system.

@export_file("*.json") var dialogue_file: String = "res://dialogue/example_conversation.json"

@onready var _event_label: Label = %EventLabel
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
    DialogueManager.event_triggered.connect(_on_dialogue_event)
    DialogueManager.dialogue_started.connect(_on_dialogue_started)
    DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
    DialogueManager.dialogue_error.connect(_on_dialogue_error)
    _event_label.text = "Game events will appear here."
    _hint_label.text = "Press E / Enter / Space / Z to start and advance dialogue."


func _unhandled_input(event: InputEvent) -> void:
    if DialogueManager.is_active:
        return
    if not event.is_action_pressed("interact"):
        return

    if DialogueManager.start_dialogue(dialogue_file):
        get_viewport().set_input_as_handled()


func _on_dialogue_started(_file_path: String, _start_node: String) -> void:
    _hint_label.text = "Interact: finish text / advance. Up-Down or W-S: choose."


func _on_dialogue_finished(_file_path: String, _last_node_id: String) -> void:
    _hint_label.text = "Press E / Enter / Space / Z to start again."


func _on_dialogue_event(event_name: String, payload: Variant) -> void:
    _event_label.text = "Game event: %s  |  data: %s" % [event_name, str(payload)]


func _on_dialogue_error(message: String) -> void:
    _event_label.text = "Dialogue error: %s" % message
