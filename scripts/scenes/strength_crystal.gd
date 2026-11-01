extends Area2D
## One-time upgrade that permanently increases the player's battle stats.

@onready var _prompt: Label = $Prompt
@onready var _crystal: ColorRect = $Crystal

var _player_in_range: CharacterBody2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if SaveManager.has_claimed_strength_crystal():
		_crystal.modulate = Color(0.35, 0.35, 0.35, 1.0)
	_prompt.hide()


func is_player_in_range(player: CharacterBody2D) -> bool:
	return _player_in_range == player


func interact(player: CharacterBody2D) -> void:
	if not is_player_in_range(player):
		return
	if SaveManager.claim_strength_crystal(
		get_tree().current_scene.scene_file_path,
		player.global_position,
		float(player.get("speed"))
	):
		_crystal.modulate = Color(0.35, 0.35, 0.35, 1.0)
		_prompt.text = "Stronger! +10 HP, +3 Attack"
	else:
		_prompt.text = "This crystal is dormant"


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = body
		_prompt.text = "Press E: +10 HP, +3 Attack" if not SaveManager.has_claimed_strength_crystal() else "This crystal is dormant"
		_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_prompt.hide()
