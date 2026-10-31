extends Area2D
class_name DialogueTrigger
## Optional convenience component: press interact while a body is inside this
## Area2D to start a dialogue file.
##
## Collision layers decide which bodies can trigger it. Attach this to an
## NPC's Area2D, or call `start()` from your own interaction code instead.

@export_file("*.json") var dialogue_file: String = ""
@export var start_node: String = ""
@export var one_shot: bool = false

var _body_inside: bool = false
var _used: bool = false


func _ready() -> void:
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
    if not _body_inside or _used:
        return
    if DialogueManager.is_active:
        return
    if not event.is_action_pressed("interact"):
        return

    if start():
        get_viewport().set_input_as_handled()


## Starts the configured conversation. Returns true when it was started.
func start() -> bool:
    if _used or dialogue_file.strip_edges().is_empty():
        return false

    var started := DialogueManager.start_dialogue(dialogue_file, start_node)
    if started and one_shot:
        _used = true
    return started


func _on_body_entered(body: Node2D) -> void:
    if body is CharacterBody2D:
        _body_inside = true


func _on_body_exited(body: Node2D) -> void:
    if body is CharacterBody2D:
        _body_inside = false
