extends Area2D
## Interactable checkpoint that writes the current player's saved state.

@onready var _prompt: Label = $Prompt
@onready var texture: Node2D = $Texture

var _player_in_range: CharacterBody2D


func _ready() -> void:
	_prompt.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_player_in_range(player: CharacterBody2D) -> bool:
	return _player_in_range == player


func interact(player: CharacterBody2D) -> void:
	save_player(player)


func save_player(player: CharacterBody2D) -> void:
	if not is_player_in_range(player):
		return

	var sprite := player.get_node_or_null("AnimatedSprite2D") as Node2D
	var sprite_rotation := sprite.rotation if sprite != null else 0.0
	var saved := SaveManager.save_player_state(
		get_tree().current_scene.scene_file_path,
		player.global_position,
		float(player.get("speed")),
		player.rotation,
		sprite_rotation
	)
	_prompt.text = "Game saved!" if saved else "Save failed"
	var save_sfx := get_node_or_null("SaveSfx") as AudioStreamPlayer2D
	if save_sfx != null:
		save_sfx.play()
	texture.rotate(90)
	await get_tree().create_timer(0.5).timeout
	texture.rotate(-90)
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(_player_in_range):
		_prompt.text = "Press E to save"


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = body
		_prompt.text = "Press E to save"
		_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_prompt.hide()
