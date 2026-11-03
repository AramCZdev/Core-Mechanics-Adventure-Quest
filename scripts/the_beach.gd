extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	player.begin_hurt_cutscene()
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("start")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != &"start":
		player.end_hurt_cutscene()
