extends CharacterBody2D

@export var speed: float = 380.0

@onready var pause_menu = $"CanvasLayer/PauseMenu"

var _autosave_elapsed: float = 0.0
const AUTOSAVE_INTERVAL := 2.0

func _ready() -> void:
	pause_menu.visible = false
	get_tree().paused = false
	if SaveManager.has_save() and SaveManager.get_saved_scene_path() == get_tree().current_scene.scene_file_path:
		global_position = SaveManager.get_saved_player_position()
		speed = SaveManager.get_saved_player_speed(speed)
	$"CanvasLayer/PauseMenu/Resume".pressed.connect(_on_resume_pressed)
	$"CanvasLayer/PauseMenu/Menu".pressed.connect(_on_menu_pressed)

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
        "move_down"
	)

	velocity = direction * speed
	move_and_slide()
	_autosave_elapsed += _delta
	if _autosave_elapsed >= AUTOSAVE_INTERVAL:
		_autosave_elapsed = 0.0
		_save_progress()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var save_point: Node = get_tree().current_scene.get_node_or_null("SavePoint")
		if save_point != null and save_point.has_method("is_player_in_range") and save_point.call("is_player_in_range", self):
			save_point.call("save_player", self)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("pause"):
		_save_progress()
		get_tree().paused = true
		pause_menu.visible = true


func _exit_tree() -> void:
	_save_progress()


func _save_progress() -> void:
	if is_inside_tree() and get_tree().current_scene != null:
		SaveManager.save_player_state(
			get_tree().current_scene.scene_file_path,
			global_position,
			speed
		)


func _on_resume_pressed() -> void:
	pause_menu.visible = false
	get_tree().paused = false


func _on_menu_pressed() -> void:
	_save_progress()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")
