extends CharacterBody2D

signal respawned

@export var speed: float = 380.0

@export_group("Death")
## Seconds to hold the fallen pose before respawning at the last save point.
@export_range(0.0, 10.0, 0.1, "suffix:s") var respawn_delay: float = 1.5

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
var _cutscene_locked: bool = false
var _is_dead: bool = false
var _respawn_timer: Timer

func _ready() -> void:
	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	add_child(_respawn_timer)

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
		rotation = SaveManager.get_saved_player_rotation(rotation)
		if animated_sprite != null:
			animated_sprite.rotation = SaveManager.get_saved_sprite_rotation(animated_sprite.rotation)
	$"CanvasLayer/PauseMenu/Resume".pressed.connect(_on_resume_pressed)
	$"CanvasLayer/PauseMenu/Menu".pressed.connect(_on_menu_pressed)
	$"CanvasLayer/StatsMenu/Content/Close".pressed.connect(_toggle_stats_menu)

func _physics_process(_delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _cutscene_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

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
	if animated_sprite == null or _is_hurting or _cutscene_locked or _is_dead:
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
	if animated_sprite == null or _is_hurting or _cutscene_locked or _is_dead:
		return
	var anim_name := "walk_" + _facing_direction
	if animated_sprite.animation != anim_name:
		animated_sprite.animation = anim_name
	animated_sprite.stop()
	animated_sprite.frame = 0


func play_hurt(direction_override: String = "") -> void:
	if animated_sprite == null or _is_dead:
		return
	var dir := direction_override if not direction_override.is_empty() else _facing_direction
	if not dir in ["up", "down", "left", "right"]:
		dir = "down"
	_is_hurting = true
	animated_sprite.play("hurt_" + dir)


func begin_hurt_cutscene() -> void:
	_cutscene_locked = true
	_is_hurting = false
	velocity = Vector2.ZERO
	show_hurt_pose("down")


func end_hurt_cutscene() -> void:
	_cutscene_locked = false
	_is_hurting = false
	_update_idle_animation()


func show_hurt_pose(direction: String = "down") -> void:
	if animated_sprite == null:
		return
	var dir := direction if direction in ["up", "down", "left", "right"] else "down"
	_facing_direction = dir
	var anim_name := "hurt_" + dir
	animated_sprite.play(anim_name)
	animated_sprite.pause()
	# The hurt animations end on the resting hurt frame (hurt/down/00.png for "down").
	animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count(anim_name) - 1


## Plays the death animation and locks the player in a fallen pose. Called by
## BattleUI after a lost battle. Safe to call more than once.
func play_death(direction_override: String = "") -> void:
	if _is_dead:
		return

	_is_dead = true
	_is_hurting = false
	_cutscene_locked = true
	velocity = Vector2.ZERO
	stats_menu.visible = false

	if animated_sprite == null:
		_schedule_respawn()
		return

	var dir := direction_override if not direction_override.is_empty() else _facing_direction
	if not dir in ["up", "down", "left", "right"]:
		dir = "down"
	_facing_direction = dir

	var anim_name := "death_" + dir
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		# Fallback for packs that do not ship death frames.
		anim_name = "hurt_" + dir
	animated_sprite.play(anim_name)
	_schedule_respawn()


func is_dead() -> bool:
	return _is_dead


## Waits for the death animation to finish (plus a short hold on the fallen
## pose) before returning the player to the last save point.
func _schedule_respawn() -> void:
	if _respawn_timer == null or not _respawn_timer.is_stopped():
		return

	var delay := respawn_delay
	if animated_sprite != null and animated_sprite.sprite_frames != null:
		var anim_name := animated_sprite.animation
		if not anim_name.is_empty() and animated_sprite.sprite_frames.has_animation(anim_name):
			var frame_count := animated_sprite.sprite_frames.get_frame_count(anim_name)
			var speed_scale := animated_sprite.sprite_frames.get_animation_speed(anim_name)
			if speed_scale > 0.0:
				delay += float(frame_count) / speed_scale
	_respawn_timer.start(maxf(delay, 0.0))


func _on_respawn_timer_timeout() -> void:
	_respawn_after_death()


## Resets the player pose and state after the death animation finishes without
## teleporting to a save point, allowing the battle to restart in place.
func _respawn_after_death() -> void:
	_is_dead = false
	_is_hurting = false
	_cutscene_locked = false
	velocity = Vector2.ZERO

	if animated_sprite != null:
		animated_sprite.modulate = Color.WHITE
		_update_idle_animation()

	respawned.emit()


## Puts the player back at the last save point with full HP. The pre-battle
## inventory was already restored by BattleManager when the defeat was handled.
func _respawn_at_last_save_point() -> void:
	var health := SaveManager.get_player_health(40, 40)
	SaveManager.set_player_health(health.y, health.y)

	var saved_scene := SaveManager.get_saved_scene_path()
	var current_scene := get_tree().current_scene
	if (
		SaveManager.has_save()
		and not saved_scene.is_empty()
		and current_scene != null
		and saved_scene != current_scene.scene_file_path
	):
		# The save point is in another room. Reload it; the new player
		# positions itself at the save point during _ready().
		var error := get_tree().change_scene_to_file(saved_scene)
		if error == OK:
			return
		# If the saved room cannot load, fall back to respawning in place.

	_is_dead = false
	_is_hurting = false
	_cutscene_locked = false
	velocity = Vector2.ZERO

	if SaveManager.has_save():
		global_position = SaveManager.get_saved_player_position()
		speed = SaveManager.get_saved_player_speed(speed)
		rotation = SaveManager.get_saved_player_rotation(rotation)
		if animated_sprite != null:
			animated_sprite.rotation = SaveManager.get_saved_sprite_rotation(animated_sprite.rotation)

	if animated_sprite != null:
		animated_sprite.modulate = Color.WHITE
		_update_idle_animation()

	respawned.emit()


func _on_animation_finished() -> void:
	if animated_sprite == null:
		return
	if _is_dead:
		# Death animations are one-shot; hold the final frame.
		return
	if animated_sprite.animation.begins_with("hurt_"):
		_is_hurting = false
		_update_idle_animation()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = true
		pause_menu.visible = true
		return
	if _is_dead:
		return
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
