extends Node2D

const DUMMY_ENEMY: BattleEnemy = preload("res://battle/enemies/dummy/dummy.tres")

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player: CharacterBody2D = $Player
@onready var old_man: Node2D = $"Old Man"
@onready var old_man_sprite: AnimatedSprite2D = $"Old Man/AnimatedSprite2D"
@onready var battle_ui: BattleUI = $CanvasLayer/BattleUI
@onready var dummy: Area2D = $Dummy

var _old_man_last_position: Vector2
var _dummy_battle_started: bool = false

func _ready() -> void:
	_old_man_last_position = old_man.global_position
	player.begin_hurt_cutscene()
	animation_player.animation_finished.connect(_on_animation_finished)
	battle_ui.battle_finished.connect(_on_battle_finished)
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
	if anim_name != &"start":
		return
	player.end_hurt_cutscene()
	DialogueManager.start_dialogue("res://dialogue/oldman.json")


func _on_dummy_body_entered(body: Node2D) -> void:
	if _dummy_battle_started or body != player:
		return
	if DialogueManager.is_active:
		return
	_dummy_battle_started = true
	battle_ui.begin_battle(DUMMY_ENEMY)


func _on_battle_finished(victory: bool) -> void:
	if victory:
		dummy.queue_free()
	else:
		_dummy_battle_started = false
