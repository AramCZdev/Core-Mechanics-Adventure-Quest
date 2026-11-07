extends Node2D


func _on_start_cutscene_body_entered(_body: Node2D) -> void:
	DialogueManager.start_dialogue("res://dialogue/monke.json")
