extends CharacterBody2D

@export var speed: float = 380.0

@onready var pause_menu = $"CanvasLayer/PauseMenu"

func _ready() -> void:
	pause_menu.visible = false
	get_tree().paused = false

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
        "move_down"
	)

	velocity = direction * speed
	move_and_slide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = true
		pause_menu.visible = true
