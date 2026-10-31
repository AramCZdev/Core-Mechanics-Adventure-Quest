extends Node2D



func _on_dialogue_body_entered(_body: Node2D) -> void:
	DialogueManager.start_dialogue("res://dialogue/example_conversation.json")
