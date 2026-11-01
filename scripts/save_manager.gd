extends Node
## Small single-slot save system for player progress.

const SAVE_PATH := "user://savegame.cfg"

var _config := ConfigFile.new()
var _has_save := false


func _ready() -> void:
	_has_save = _config.load(SAVE_PATH) == OK


func has_save() -> bool:
	return _has_save


func get_saved_scene_path() -> String:
	if not _has_save:
		return ""
	return str(_config.get_value("progress", "scene_path", ""))


func get_saved_player_position() -> Vector2:
	if not _has_save:
		return Vector2.ZERO
	return _config.get_value("progress", "player_position", Vector2.ZERO)


func get_saved_player_speed(default_speed: float = 380.0) -> float:
	if not _has_save:
		return default_speed
	return float(_config.get_value("progress", "player_speed", default_speed))


func save_player_state(scene_path: String, player_position: Vector2, player_speed: float = 380.0) -> bool:
	if scene_path.is_empty():
		return false

	_config.set_value("progress", "scene_path", scene_path)
	_config.set_value("progress", "player_position", player_position)
	_config.set_value("progress", "player_speed", player_speed)
	var result := _config.save(SAVE_PATH)
	_has_save = result == OK
	if result != OK:
		push_error("SaveManager: could not write save file (error %d)." % result)
	return _has_save


func delete_save() -> bool:
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var result := DirAccess.remove_absolute(absolute_path)
		if result != OK:
			push_error("SaveManager: could not delete save file (error %d)." % result)
			return false
	_config.clear()
	_has_save = false
	return true
