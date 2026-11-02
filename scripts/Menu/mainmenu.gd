extends Control

const GAME_SCENE := "res://scenes/Gameplay/game_test_scene.tscn"

@onready var _main_options: VBoxContainer = $MainMenuOptions
@onready var _play_options: VBoxContainer = $PlayOptions
@onready var _start_button: Button = $PlayOptions/Start
@onready var _reset_button: Button = $PlayOptions/Reset
@onready var _hero_name_panel: VBoxContainer = $HeroNamePanel
@onready var _hero_name_input: LineEdit = $HeroNamePanel/HeroNameInput


func _ready() -> void:
	_main_options.show()
	_play_options.hide()
	_hero_name_panel.hide()
	$MainMenuOptions/Play.pressed.connect(_on_play_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	$PlayOptions/Back.pressed.connect(_on_back_pressed)
	$HeroNamePanel/Begin.pressed.connect(_on_begin_pressed)
	$HeroNamePanel/Cancel.pressed.connect(_on_name_cancel_pressed)
	_hero_name_input.text_submitted.connect(_on_name_submitted)
	_refresh_save_buttons()



func _on_achievements_pressed() -> void:
	get_tree().change_scene_to_file("res://addons/SimpleAchievement/ui/AchievementViewer.tscn")


func _on_play_pressed() -> void:
	_main_options.hide()
	_play_options.show()


func _on_start_pressed() -> void:
	if SaveManager.has_save():
		var scene_path := GAME_SCENE
		var saved_scene := SaveManager.get_saved_scene_path()
		if not saved_scene.is_empty() and ResourceLoader.exists(saved_scene):
			scene_path = saved_scene
		else:
			SaveManager.delete_save()
		get_tree().change_scene_to_file(scene_path)
		return

	_play_options.hide()
	_hero_name_input.clear()
	_hero_name_panel.show()
	_hero_name_input.grab_focus()


func _on_begin_pressed() -> void:
	$"AnimationPlayer".play("start")
	$"HeroNamePanel/Begin".disabled = true
	$"HeroNamePanel/Cancel".disabled = true

func _on_name_submitted(hero_name: String) -> void:
	_start_new_game(hero_name)


func _on_name_cancel_pressed() -> void:
	_hero_name_panel.hide()
	_play_options.show()


func _start_new_game(hero_name: String) -> void:
	SaveManager.begin_new_game(hero_name)
	get_tree().change_scene_to_file(GAME_SCENE)


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



func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "start":
		_start_new_game(_hero_name_input.text)
