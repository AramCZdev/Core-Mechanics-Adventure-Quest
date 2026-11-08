extends Node2D

const TV_ENEMY: BattleEnemy = preload("res://battle/enemies/broken tv/broken tv.tres")
@onready var battle_ui = $CanvasLayer/BattleUI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	battle_ui.battle_finished.connect(_on_battle_finished)

func _on_battle_finished(victory: bool) -> void:
	if victory:
		var tv := get_node_or_null("Tv")
		if tv != null:
			tv.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_tv_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	if DialogueManager.is_active:
		return
	battle_ui.begin_battle(TV_ENEMY)
