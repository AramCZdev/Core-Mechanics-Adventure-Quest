extends Control

const GAME_SCENE := "res://scenes/Gameplay/game_test_scene.tscn"

@onready var _main_options: VBoxContainer = $MainMenuOptions
@onready var _play_options: VBoxContainer = $PlayOptions
@onready var _start_button: Button = $PlayOptions/Start
@onready var _reset_button: Button = $PlayOptions/Reset


func _ready() -> void:
	_main_options.show()
	_play_options.hide()
	$MainMenuOptions/Play.pressed.connect(_on_play_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	$PlayOptions/Back.pressed.connect(_on_back_pressed)
	_refresh_save_buttons()



func _on_achievements_pressed() -> void:
	get_tree().change_scene_to_file("res://addons/SimpleAchievement/ui/AchievementViewer.tscn")


func _on_play_pressed() -> void:
	_main_options.hide()
	_play_options.show()


func _on_start_pressed() -> void:
	var scene_path := GAME_SCENE
	if SaveManager.has_save():
		var saved_scene := SaveManager.get_saved_scene_path()
		if not saved_scene.is_empty() and ResourceLoader.exists(saved_scene):
			scene_path = saved_scene
		else:
			SaveManager.delete_save()
	get_tree().change_scene_to_file(scene_path)


func _on_reset_pressed() -> void:
	if SaveManager.delete_save():
		_refresh_save_buttons()


func _on_back_pressed() -> void:
	_play_options.hide()
	_main_options.show()


func _refresh_save_buttons() -> void:
	var save_exists: bool = SaveManager.has_save()
	_start_button.text = "Continue" if save_exists else "New Game"
	_reset_button.visible = true
	_reset_button.disabled = not save_exists
	_reset_button.text = "Delete Save"
