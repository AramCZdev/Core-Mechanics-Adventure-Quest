extends Area2D
## Interactable shopkeeper that asks the current scene to open a shop.

signal shop_requested(shop_id: String)

@export var shop_id: String = "general_store"
@export var prompt_text: String = "Press E to shop"

@onready var _prompt: Label = $Prompt

var _player_in_range: CharacterBody2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.hide()


func is_player_in_range(player: CharacterBody2D) -> bool:
	return _player_in_range == player


func interact(player: CharacterBody2D) -> void:
	if is_player_in_range(player):
		shop_requested.emit(shop_id)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = body
		_prompt.text = prompt_text
		_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_prompt.hide()
