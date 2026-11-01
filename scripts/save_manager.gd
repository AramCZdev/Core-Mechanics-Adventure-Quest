extends Node
## Small single-slot save system for player progress.

const SAVE_PATH := "user://savegame.cfg"

var _config := ConfigFile.new()
var _has_save := false
var _player_hp: int = 40
var _player_max_hp: int = 40
var _player_attack: int = 12
var _hero_name := "Hero"


func _ready() -> void:
	_has_save = _config.load(SAVE_PATH) == OK
	if _has_save:
		_player_max_hp = maxi(1, int(_config.get_value("player", "max_hp", _player_max_hp)))
		_player_hp = clampi(int(_config.get_value("player", "hp", _player_max_hp)), 0, _player_max_hp)
		_player_attack = maxi(0, int(_config.get_value("player", "attack", _player_attack)))
		_hero_name = str(_config.get_value("player", "hero_name", _hero_name))


func has_save() -> bool:
	return _has_save


func set_hero_name(hero_name: String) -> void:
	_hero_name = hero_name.strip_edges().left(20)
	if _hero_name.is_empty():
		_hero_name = "Hero"
	_config.set_value("player", "hero_name", _hero_name)


func get_hero_name() -> String:
	return _hero_name


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


func get_player_health(default_hp: int, default_max_hp: int) -> Vector2i:
	if not _has_save:
		return Vector2i(default_hp, default_max_hp)
	var max_hp := maxi(1, _player_max_hp)
	return Vector2i(clampi(_player_hp, 0, max_hp), max_hp)


func set_player_health(current_hp: int, max_hp: int) -> void:
	_player_max_hp = maxi(1, max_hp)
	_player_hp = clampi(current_hp, 0, _player_max_hp)
	if _has_save:
		_config.set_value("player", "hp", _player_hp)
		_config.set_value("player", "max_hp", _player_max_hp)
		var result := _config.save(SAVE_PATH)
		if result != OK:
			push_error("SaveManager: could not update player HP (error %d)." % result)


func get_player_attack(default_attack: int) -> int:
	return _player_attack if _has_save else default_attack


func reward_battle_victory(current_hp: int, max_hp: int, attack: int) -> Vector3i:
	_player_max_hp = maxi(1, max_hp) + 5
	_player_hp = mini(maxi(0, current_hp) + 5, _player_max_hp)
	_player_attack = maxi(0, attack) + 1
	if _has_save:
		_config.set_value("player", "hp", _player_hp)
		_config.set_value("player", "max_hp", _player_max_hp)
		_config.set_value("player", "attack", _player_attack)
		var result := _config.save(SAVE_PATH)
		if result != OK:
			push_error("SaveManager: could not save victory reward (error %d)." % result)
	return Vector3i(_player_hp, _player_max_hp, _player_attack)


func claim_strength_crystal(scene_path: String, player_position: Vector2, player_speed: float) -> bool:
	if bool(_config.get_value("upgrades", "strength_crystal_claimed", false)):
		return false

	_player_max_hp += 10
	_player_hp = mini(_player_hp + 10, _player_max_hp)
	_player_attack += 3
	_config.set_value("upgrades", "strength_crystal_claimed", true)
	return save_player_state(scene_path, player_position, player_speed)


func has_claimed_strength_crystal() -> bool:
	return bool(_config.get_value("upgrades", "strength_crystal_claimed", false))


func save_player_state(scene_path: String, player_position: Vector2, player_speed: float = 380.0) -> bool:
	if scene_path.is_empty():
		return false

	_config.set_value("progress", "scene_path", scene_path)
	_config.set_value("progress", "player_position", player_position)
	_config.set_value("progress", "player_speed", player_speed)
	_config.set_value("player", "hp", _player_hp)
	_config.set_value("player", "max_hp", _player_max_hp)
	_config.set_value("player", "attack", _player_attack)
	_config.set_value("player", "hero_name", _hero_name)
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
	_player_hp = 40
	_player_max_hp = 40
	_player_attack = 12
	_hero_name = "Hero"
	return true
