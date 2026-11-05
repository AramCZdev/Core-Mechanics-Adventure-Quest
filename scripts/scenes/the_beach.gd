extends Node2D

const DUMMY_ENEMY: BattleEnemy = preload("res://battle/enemies/dummy/dummy.tres")

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player: CharacterBody2D = $Player
@onready var old_man: Node2D = $"Old Man"
@onready var old_man_sprite: AnimatedSprite2D = $"Old Man/AnimatedSprite2D"
@onready var battle_ui: BattleUI = $CanvasLayer/BattleUI
@onready var shop: Control = $CanvasLayer/Shop
@onready var dummy: Area2D = $Dummy
@onready var barrier_collision: CollisionShape2D = $"Barrier/CollisionShape2D"

var _old_man_last_position: Vector2
var _dummy_battle_started: bool = false
var _dummy_battle_completed: bool = false
var _path_shown: bool = false

func _ready() -> void:
	_dummy_battle_completed = SaveManager.has_defeated_dummy_boss()
	if _dummy_battle_completed:
		dummy.queue_free()
		barrier_collision.disabled = true
	_old_man_last_position = old_man.global_position
	if not _dummy_battle_completed:
		player.begin_hurt_cutscene()
		animation_player.animation_finished.connect(_on_animation_finished)
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
		battle_ui.battle_exited.connect(_on_battle_exited)
		animation_player.play("start")


func _process(_delta: float) -> void:
	var moved := old_man.global_position.distance_to(_old_man_last_position) > 0.1
	_old_man_last_position = old_man.global_position
	if moved:
		if old_man_sprite.animation != "walk":
			old_man_sprite.play("walk")
	elif old_man_sprite.animation != "idle":
		old_man_sprite.play("idle")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "start":
		player.end_hurt_cutscene()
		DialogueManager.start_dialogue("res://dialogue/oldman.json")
	if anim_name == "entrance":
		get_tree().change_scene_to_file("res://scenes/Gameplay/game_test_scene.tscn")

func _on_dummy_body_entered(body: Node2D) -> void:
	if _dummy_battle_started or body != player:
		return
	if DialogueManager.is_active:
		return
	_dummy_battle_started = true
	battle_ui.begin_battle(DUMMY_ENEMY)


func _on_shop_requested(shop_id: String) -> void:
	shop.open_shop(shop_id)


func _on_battle_exited(victory: bool) -> void:
	if victory and not _dummy_battle_completed:
		_dummy_battle_completed = true
		SaveManager.mark_dummy_boss_defeated()
		dummy.queue_free()
		DialogueManager.start_dialogue("res://dialogue/after_training.json")
		barrier_collision.disabled = true
		_path_shown = true
	else:
		_dummy_battle_started = false

func _on_dialogue_finished(file_path: String, _last_node_id: String) -> void:
	if not _path_shown or file_path != "res://dialogue/after_training.json":
		return
	_path_shown = false
	animation_player.play("training_done")


func _on_entrance_body_entered(_body: Node2D) -> void:
	animation_player.play("entrance")
