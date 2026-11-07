extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)


func _on_start_cutscene_body_entered(_body: Node2D) -> void:
	DialogueManager.start_dialogue("res://dialogue/monke.json")

func _on_dialogue_finished(file_path: String, _last_node_id: String) -> void:
	if file_path != "res://dialogue/monke.json":
		return
	animation_player.play("monkey_jumps")
	$"Start Cutscene".queue_free() 

func _on_button_body_entered(body: Node2D) -> void:
	$"Wall".queue_free()
