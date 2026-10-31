extends Node2D

@onready var battle_ui: BattleUI = $CanvasLayer/BattleUI

func _on_dialogue_body_entered(_body: Node2D) -> void:
	DialogueManager.start_dialogue("res://dialogue/example_conversation.json")

func _on_enemy_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not battle_ui.visible:
		battle_ui.show()
		battle_ui.begin_battle(
			load("res://battle/enemies/mossling/mossling.tres")
		)