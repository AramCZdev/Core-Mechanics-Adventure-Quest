extends Area2D
## Interactable shopkeeper that asks the current scene to open a shop.
##
## Scenes can handle `shop_requested` themselves (like game_test_scene.tscn).
## When nothing is connected, the NPC finds the scene's shop window or creates
## one on demand, so it works in any room just by dropping it in.

signal shop_requested(shop_id: String)

const SHOP_SCENE: PackedScene = preload("res://scenes/shop.tscn")

@export var shop_id: String = "general_store"
@export var prompt_text: String = "Press E to shop"

@onready var _prompt: Label = get_node_or_null("Prompt") as Label

var _player_in_range: CharacterBody2D


func _ready() -> void:
	# Make the NPC discoverable by the player's interact key even when the
	# scene instance forgot to add the group in the editor.
	add_to_group("interactable")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if _prompt != null:
		_prompt.hide()


func is_player_in_range(player: CharacterBody2D) -> bool:
	return _player_in_range == player


func interact(player: CharacterBody2D) -> void:
	if not is_player_in_range(player):
		return
	shop_requested.emit(shop_id)
	# If no scene script is listening, open the shop ourselves.
	if shop_requested.get_connections().is_empty():
		_open_shop_ui()


func _open_shop_ui() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var shop := _find_shop_ui(current_scene)
	if shop == null:
		shop = _create_shop_ui(current_scene)
	if shop != null and shop.has_method("open_shop"):
		shop.call("open_shop", shop_id)


func _find_shop_ui(root: Node) -> Node:
	for node in root.find_children("*", "", true, false):
		if node.has_method("open_shop"):
			return node
	return null


func _create_shop_ui(root: Node) -> Node:
	var canvas := root.get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		root.add_child(canvas)

	var shop := SHOP_SCENE.instantiate()
	canvas.add_child(shop)
	return shop


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_in_range = body
		if _prompt != null:
			_prompt.text = prompt_text
			_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		if _prompt != null:
			_prompt.hide()
