extends Node
## Single-slot save system for player progress and persistent inventory.

const SAVE_PATH := "user://savegame.cfg"

signal inventory_changed(inventory: Dictionary)

var _config := ConfigFile.new()
var _has_save := false
var _player_hp: int = 40
var _player_max_hp: int = 40
var _player_attack: int = 12
var _hero_name := "Hero"
var _inventory: Dictionary = {}


func _ready() -> void:
	if _config.load(SAVE_PATH) != OK:
		return

	# An inventory-only save must not make the main menu offer Continue.
	_has_save = not str(_config.get_value("progress", "scene_path", "")).is_empty()
	_player_max_hp = maxi(1, int(_config.get_value("player", "max_hp", _player_max_hp)))
	_player_hp = clampi(int(_config.get_value("player", "hp", _player_max_hp)), 0, _player_max_hp)
	_player_attack = maxi(0, int(_config.get_value("player", "attack", _player_attack)))
	_hero_name = str(_config.get_value("player", "hero_name", _hero_name))

	for item_id in _config.get_section_keys("inventory"):
		var quantity := int(_config.get_value("inventory", item_id, 0))
		if _is_valid_item_id(item_id) and quantity > 0:
			_inventory[item_id] = quantity


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


## Adds quantity copies of an item and saves the inventory immediately.
## Returns false for invalid IDs, non-positive quantities, or save failures.
func add_item(item_id: String, quantity: int = 1) -> bool:
	var normalized_id := item_id.strip_edges().to_lower()
	if not _is_valid_item_id(normalized_id) or quantity <= 0:
		return false

	var previous_quantity := get_item_count(normalized_id)
	_inventory[normalized_id] = previous_quantity + quantity
	if not _save_inventory():
		if previous_quantity == 0:
			_inventory.erase(normalized_id)
		else:
			_inventory[normalized_id] = previous_quantity
		return false

	inventory_changed.emit(get_inventory())
	return true


## Removes quantity copies of an item. Does not change inventory if insufficient.
func remove_item(item_id: String, quantity: int = 1) -> bool:
	var normalized_id := item_id.strip_edges().to_lower()
	if not _is_valid_item_id(normalized_id) or quantity <= 0:
		return false

	var previous_quantity := get_item_count(normalized_id)
	if previous_quantity < quantity:
		return false

	var remaining := previous_quantity - quantity
	if remaining == 0:
		_inventory.erase(normalized_id)
	else:
		_inventory[normalized_id] = remaining

	if not _save_inventory():
		_inventory[normalized_id] = previous_quantity
		return false

	inventory_changed.emit(get_inventory())
	return true


func has_item(item_id: String) -> bool:
	return get_item_count(item_id) > 0


func get_item_count(item_id: String) -> int:
	var normalized_id := item_id.strip_edges().to_lower()
	return int(_inventory.get(normalized_id, 0))


## Returns a copy so callers cannot mutate saved inventory without using this API.
func get_inventory() -> Dictionary:
	return _inventory.duplicate()


func _save_inventory() -> bool:
	_config.erase_section("inventory")
	for item_id in _inventory:
		var quantity := int(_inventory[item_id])
		if quantity > 0:
			_config.set_value("inventory", item_id, quantity)

	var result := _config.save(SAVE_PATH)
	if result != OK:
		push_error("SaveManager: could not save inventory (error %d)." % result)
		return false
	return true


func _is_valid_item_id(item_id: String) -> bool:
	if item_id.is_empty() or item_id.length() > 64:
		return false
	for character in item_id:
		var code := character.unicode_at(0)
		var is_lowercase := code >= 97 and code <= 122
		var is_number := code >= 48 and code <= 57
		if not is_lowercase and not is_number and character not in ["_", "-", "."]:
			return false
	return true


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
	_inventory.clear()
	_has_save = false
	_player_hp = 40
	_player_max_hp = 40
	_player_attack = 12
	_hero_name = "Hero"
	inventory_changed.emit(get_inventory())
	return true
