extends CharacterBody2D

@export var speed: float = 380.0

@onready var pause_menu = $"CanvasLayer/PauseMenu"
@onready var stats_menu = $"CanvasLayer/StatsMenu"
@onready var stats_name_label: Label = $"CanvasLayer/StatsMenu/Content/HeroName"
@onready var stats_hp_label: Label = $"CanvasLayer/StatsMenu/Content/HP"
@onready var stats_attack_label: Label = $"CanvasLayer/StatsMenu/Content/Attack"
@onready var stats_gold_label: Label = $"CanvasLayer/StatsMenu/Content/Gold"
@onready var stats_potions_label: Label = $"CanvasLayer/StatsMenu/Content/Potions"
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var _facing_direction: String = "down"
var _is_hurting: bool = false

func _ready() -> void:
	pause_menu.visible = false
	stats_menu.visible = false
	get_tree().paused = false
	if animated_sprite != null:
		animated_sprite.animation = "walk_down"
		animated_sprite.stop()
		animated_sprite.frame = 0
		animated_sprite.animation_finished.connect(_on_animation_finished)
	if SaveManager.has_save() and get_tree().current_scene != null and SaveManager.get_saved_scene_path() == get_tree().current_scene.scene_file_path:
		global_position = SaveManager.get_saved_player_position()
		speed = SaveManager.get_saved_player_speed(speed)
	$"CanvasLayer/PauseMenu/Resume".pressed.connect(_on_resume_pressed)
	$"CanvasLayer/PauseMenu/Menu".pressed.connect(_on_menu_pressed)
	$"CanvasLayer/StatsMenu/Content/Close".pressed.connect(_toggle_stats_menu)

func _physics_process(_delta: float) -> void:
	if stats_menu.visible:
		velocity = Vector2.ZERO
		_update_idle_animation()
		return

	if _is_hurting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed
	move_and_slide()
	_update_movement_animation(direction)


func _update_movement_animation(direction: Vector2) -> void:
	if animated_sprite == null or _is_hurting:
		return

	if direction == Vector2.ZERO:
		_update_idle_animation()
		return

	if absf(direction.x) > absf(direction.y):
		if direction.x > 0.0:
			_facing_direction = "right"
		else:
			_facing_direction = "left"
	else:
		if direction.y > 0.0:
			_facing_direction = "down"
		else:
			_facing_direction = "up"

	var anim_name := "walk_" + _facing_direction
	if animated_sprite.animation != anim_name or not animated_sprite.is_playing():
		animated_sprite.play(anim_name)


func _update_idle_animation() -> void:
	if animated_sprite == null or _is_hurting:
		return
	var anim_name := "walk_" + _facing_direction
	if animated_sprite.animation != anim_name:
		animated_sprite.animation = anim_name
	animated_sprite.stop()
	animated_sprite.frame = 0


func play_hurt(direction_override: String = "") -> void:
	if animated_sprite == null:
		return
	var dir := direction_override if not direction_override.is_empty() else _facing_direction
	if not dir in ["up", "down", "left", "right"]:
		dir = "down"
	_is_hurting = true
	animated_sprite.play("hurt_" + dir)


func _on_animation_finished() -> void:
	if animated_sprite != null and animated_sprite.animation.begins_with("hurt_"):
		_is_hurting = false
		_update_idle_animation()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_CTRL:
		_toggle_stats_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		for interactable in get_tree().get_nodes_in_group("interactable"):
			if interactable.has_method("is_player_in_range") and interactable.call("is_player_in_range", self):
				interactable.call("interact", self)
				get_viewport().set_input_as_handled()
				return
		var strength_crystal: Node = get_tree().current_scene.get_node_or_null("StrengthCrystal")
		if strength_crystal != null and strength_crystal.has_method("is_player_in_range") and strength_crystal.call("is_player_in_range", self):
			strength_crystal.call("interact", self)
			get_viewport().set_input_as_handled()
			return
		var save_point: Node = get_tree().current_scene.get_node_or_null("SavePoint")
		if save_point != null and save_point.has_method("is_player_in_range") and save_point.call("is_player_in_range", self):
			if save_point.has_method("interact"):
				save_point.call("interact", self)
			else:
				save_point.call("save_player", self)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		get_tree().paused = true
		pause_menu.visible = true


func _on_resume_pressed() -> void:
	pause_menu.visible = false
	get_tree().paused = false


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")


func _toggle_stats_menu() -> void:
	stats_menu.visible = not stats_menu.visible
	if stats_menu.visible:
		var health := SaveManager.get_player_health(40, 40)
		var inventory := SaveManager.get_inventory()
		var potions := int(inventory.get("health_potion", 0)) + int(inventory.get("greater_health_potion", 0))
		stats_name_label.text = "Hero: %s" % SaveManager.get_hero_name()
		stats_hp_label.text = "HP: %d / %d" % [health.x, health.y]
		stats_attack_label.text = "Attack: %d" % SaveManager.get_player_attack(12)
		stats_gold_label.text = "Gold: %d" % SaveManager.get_gold()
		stats_potions_label.text = "Potions: %d" % potions
