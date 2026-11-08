extends Node
## Single-slot save system for player progress, currency, and persistent inventory.

const DEFAULT_SAVE_PATH := "user://savegame.cfg"
const STARTING_GOLD := 100
const BATTLE_VICTORY_GOLD := 25
const STARTING_ITEMS := {"health_potion": 2}

const DEFAULT_PLAYER_HP := 40
const DEFAULT_PLAYER_ATTACK := 12

# Location IDs. 0 means the run has not started or the room is unknown.
const LOCATION_NONE := 0
const LOCATION_BEACH := 1
const LOCATION_FOREST := 2
const LOCATION_CASTLE := 3
const LOCATION_END := 4

const LOCATION_NAMES := {
	LOCATION_NONE: "Not Started",
	LOCATION_BEACH: "The Beach",
	LOCATION_FOREST: "Forest",
	LOCATION_CASTLE: "Castle",
	LOCATION_END: "The End",
}

# Scene filenames are normalized by removing digits, spaces, underscores, and
# hyphens before lookup. So TheBeach, The_Beach, and TheBeach2 all match here.
const LOCATION_SCENE_ALIASES := {
	"beach": LOCATION_BEACH,
	"thebeach": LOCATION_BEACH,
	"forest": LOCATION_FOREST,
	"theforest": LOCATION_FOREST,
	"castle": LOCATION_CASTLE,
	"thecastle": LOCATION_CASTLE,
	"end": LOCATION_END,
	"theend": LOCATION_END,
}

signal inventory_changed(inventory: Dictionary)
signal gold_changed(gold: int)

## Override this before the node enters the tree to use another slot (tests).
var save_path: String = DEFAULT_SAVE_PATH

var _config := ConfigFile.new()
var _has_save := false
var _player_hp: int = DEFAULT_PLAYER_HP
var _player_max_hp: int = DEFAULT_PLAYER_HP
var _player_attack: int = DEFAULT_PLAYER_ATTACK
var _hero_name := "Hero"
var _inventory: Dictionary = {}
var _gold: int = STARTING_GOLD
var _last_tracked_scene_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return

	var current_scene := get_tree().current_scene
	if current_scene == null or current_scene.scene_file_path.is_empty():
		return
	if current_scene.scene_file_path == _last_tracked_scene_path:
		return

	_last_tracked_scene_path = current_scene.scene_file_path
	set_location_from_scene(_last_tracked_scene_path)


## Switches to a different save file and reloads it immediately.
func set_save_path(path: String) -> void:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty():
		return
	save_path = normalized_path
	_load()


func _load() -> void:
	_config = ConfigFile.new()
	_has_save = false
	_player_hp = DEFAULT_PLAYER_HP
	_player_max_hp = DEFAULT_PLAYER_HP
	_player_attack = DEFAULT_PLAYER_ATTACK
	_hero_name = "Hero"
	_inventory.clear()
	_gold = STARTING_GOLD

	if _config.load(save_path) != OK:
		return

	# An inventory-only save must not make the main menu offer Continue.
	_has_save = not str(_config.get_value("progress", "scene_path", "")).is_empty()
	_player_max_hp = maxi(1, int(_config.get_value("player", "max_hp", _player_max_hp)))
	_player_hp = clampi(int(_config.get_value("player", "hp", _player_max_hp)), 0, _player_max_hp)
	_player_attack = maxi(0, int(_config.get_value("player", "attack", _player_attack)))
	_hero_name = str(_config.get_value("player", "hero_name", _hero_name))
	_gold = maxi(0, int(_config.get_value("player", "gold", STARTING_GOLD)))

	if _config.has_section("inventory"):
		for item_id in _config.get_section_keys("inventory"):
			var quantity := int(_config.get_value("inventory", item_id, 0))
			if _is_valid_item_id(item_id) and quantity > 0:
				_inventory[item_id] = quantity


## Starts a fresh run, clearing any previous progress and inventory.
func begin_new_game(hero_name: String) -> void:
	_remove_save_file()
	_reset_state()
	_hero_name = _sanitize_hero_name(hero_name)
	_gold = STARTING_GOLD
	_inventory = STARTING_ITEMS.duplicate()
	_config.set_value("player", "hero_name", _hero_name)
	_config.set_value("player", "gold", _gold)
	for item_id in _inventory:
		_config.set_value("inventory", item_id, _inventory[item_id])
	_save_config()
	inventory_changed.emit(get_inventory())
	gold_changed.emit(_gold)


func has_save() -> bool:
	return _has_save


func set_hero_name(hero_name: String) -> void:
	_hero_name = _sanitize_hero_name(hero_name)
	_config.set_value("player", "hero_name", _hero_name)
	_save_config()


func get_hero_name() -> String:
	return _hero_name


func get_saved_scene_path() -> String:
	if not _has_save:
		return ""
	return str(_config.get_value("progress", "scene_path", ""))


## Returns the location ID for a scene path/name. Digits are ignored, so
## "TheBeach2.tscn" and "1_TheBeach.tscn" still resolve to The Beach (1).
func location_id_from_scene(scene_path: String) -> int:
	var key := _scene_name_key(scene_path)
	return int(LOCATION_SCENE_ALIASES.get(key, LOCATION_NONE))


## Converts a scene filename into a readable location name.
## "TheBeach.tscn" -> "The Beach", "TheBeach2.tscn" -> "The Beach".
func location_name_from_scene(scene_path: String) -> String:
	var location_id := location_id_from_scene(scene_path)
	if location_id != LOCATION_NONE and LOCATION_NAMES.has(location_id):
		return str(LOCATION_NAMES[location_id])
	if scene_path.strip_edges().is_empty():
		return location_name_for_id(LOCATION_NONE)
	return _scene_display_name(scene_path)


func location_name_for_id(location_id: int) -> String:
	return str(LOCATION_NAMES.get(location_id, "Unknown"))


## Records the last visited location immediately so it survives quitting.
## Unknown scenes (menus, test rooms) are ignored so they cannot overwrite the
## last real location. This does not change the location stored by a save point.
func set_location_from_scene(scene_path: String) -> void:
	var location_id := location_id_from_scene(scene_path)
	if location_id == LOCATION_NONE:
		return

	_config.set_value("progress", "last_location_id", location_id)
	_config.set_value("progress", "last_location_name", location_name_from_scene(scene_path))
	_save_config()


## Location of the currently loaded scene. Returns 0 before gameplay starts or
## when the scene is not one of the known locations.
func get_current_location_id() -> int:
	if not is_inside_tree() or get_tree().current_scene == null:
		return LOCATION_NONE
	return location_id_from_scene(get_tree().current_scene.scene_file_path)


func get_current_location_name() -> String:
	if not is_inside_tree() or get_tree().current_scene == null:
		return location_name_for_id(LOCATION_NONE)
	return location_name_from_scene(get_tree().current_scene.scene_file_path)


## Location stored by the last save point. If no save exists yet, falls back to
## the last visited location so the main menu still remembers where you were.
func get_saved_location_id() -> int:
	if _has_save:
		if _config.has_section_key("progress", "saved_location_id"):
			return int(_config.get_value("progress", "saved_location_id", LOCATION_NONE))
		# Backward compatibility: older saves only stored the scene path.
		return location_id_from_scene(get_saved_scene_path())
	return get_last_location_id()


func get_saved_location_name() -> String:
	if _has_save:
		if _config.has_section_key("progress", "saved_location_name"):
			return str(_config.get_value("progress", "saved_location_name", ""))
		return location_name_from_scene(get_saved_scene_path())
	return get_last_location_name()


## Last location the player visited, even if they have not saved there.
func get_last_location_id() -> int:
	if _config.has_section_key("progress", "last_location_id"):
		return int(_config.get_value("progress", "last_location_id", LOCATION_NONE))
	# Backward compatibility with the previous auto-tracking field.
	return int(_config.get_value("progress", "location_id", LOCATION_NONE))


func get_last_location_name() -> String:
	if _config.has_section_key("progress", "last_location_name"):
		return str(_config.get_value("progress", "last_location_name", ""))
	var location_id := get_last_location_id()
	if location_id != LOCATION_NONE:
		return location_name_for_id(location_id)
	# Backward compatibility with the previous auto-tracking field.
	var stored_name := str(_config.get_value("progress", "location_name", ""))
	if not stored_name.is_empty():
		return stored_name
	return location_name_for_id(LOCATION_NONE)


func get_saved_player_position() -> Vector2:
	if not _has_save:
		return Vector2.ZERO
	return _config.get_value("progress", "player_position", Vector2.ZERO)


func get_saved_player_speed(default_speed: float = 380.0) -> float:
	if not _has_save:
		return default_speed
	return float(_config.get_value("progress", "player_speed", default_speed))


func get_saved_player_rotation(default_rotation: float = 0.0) -> float:
	if not _has_save:
		return default_rotation
	return float(_config.get_value("progress", "player_rotation", default_rotation))


func get_saved_sprite_rotation(default_rotation: float = 0.0) -> float:
	if not _has_save:
		return default_rotation
	return float(_config.get_value("progress", "sprite_rotation", default_rotation))


func get_player_health(default_hp: int, default_max_hp: int) -> Vector2i:
	if not _has_save and _player_max_hp == DEFAULT_PLAYER_HP and _player_hp == DEFAULT_PLAYER_HP:
		return Vector2i(default_hp, default_max_hp)
	var max_hp := maxi(1, _player_max_hp)
	return Vector2i(clampi(_player_hp, 0, max_hp), max_hp)


func set_player_health(current_hp: int, max_hp: int) -> void:
	_player_max_hp = maxi(1, max_hp)
	_player_hp = clampi(current_hp, 0, _player_max_hp)
	if not _has_save:
		return

	_config.set_value("player", "hp", _player_hp)
	_config.set_value("player", "max_hp", _player_max_hp)
	_save_config()


func get_player_attack(default_attack: int) -> int:
	if not _has_save and _player_attack == DEFAULT_PLAYER_ATTACK:
		return default_attack
	return _player_attack


func reward_battle_victory(current_hp: int, max_hp: int, attack: int) -> Vector3i:
	_player_max_hp = maxi(1, max_hp) + 5
	_player_hp = mini(maxi(0, current_hp) + 5, _player_max_hp)
	_player_attack = maxi(0, attack) + 1
	_gold += BATTLE_VICTORY_GOLD

	# Only non-economy progress is written here. Gold and inventory stay in
	# memory until the player uses a save point.
	if _has_save:
		_config.set_value("player", "hp", _player_hp)
		_config.set_value("player", "max_hp", _player_max_hp)
		_config.set_value("player", "attack", _player_attack)
		_save_config()
	gold_changed.emit(_gold)
	return Vector3i(_player_hp, _player_max_hp, _player_attack)


func get_battle_victory_gold() -> int:
	return BATTLE_VICTORY_GOLD


## Adds quantity copies of an item. Changes are kept in memory until the player
## uses a save point. Returns false for invalid IDs or non-positive quantities.
func add_item(item_id: String, quantity: int = 1) -> bool:
	var normalized_id := item_id.strip_edges().to_lower()
	if not _is_valid_item_id(normalized_id) or quantity <= 0:
		return false

	_inventory[normalized_id] = get_item_count(normalized_id) + quantity
	inventory_changed.emit(get_inventory())
	return true


## Removes quantity copies of an item. Does not change inventory if insufficient.
## Changes are kept in memory until the player uses a save point.
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


## Replaces the in-memory inventory with a previous snapshot. Used to refund
## items consumed during a battle the player lost. Changes stay in memory until
## the player uses a save point.
func restore_inventory(inventory: Dictionary) -> void:
	_inventory.clear()
	for item_id in inventory:
		var normalized_id := str(item_id).strip_edges().to_lower()
		var quantity := int(inventory[item_id])
		if _is_valid_item_id(normalized_id) and quantity > 0:
			_inventory[normalized_id] = quantity
	inventory_changed.emit(get_inventory())


## Currency stays in memory until the player uses a save point.
func get_gold() -> int:
	return _gold


func add_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	_gold += amount
	gold_changed.emit(_gold)
	return true


func spend_gold(amount: int) -> bool:
	if amount <= 0 or _gold < amount:
		return false
	_gold -= amount
	gold_changed.emit(_gold)
	return true


func _write_inventory_to_config() -> void:
	if _config.has_section("inventory"):
		_config.erase_section("inventory")
	for item_id in _inventory:
		var quantity := int(_inventory[item_id])
		if quantity > 0:
			_config.set_value("inventory", item_id, quantity)


func _save_config() -> bool:
	var result := _config.save(save_path)
	if result != OK:
		push_error("SaveManager: could not write save file (error %d)." % result)
		return false
	return true


func _reset_state() -> void:
	_config.clear()
	_has_save = false
	_player_hp = DEFAULT_PLAYER_HP
	_player_max_hp = DEFAULT_PLAYER_HP
	_player_attack = DEFAULT_PLAYER_ATTACK
	_hero_name = "Hero"
	_inventory.clear()
	_gold = STARTING_GOLD


func _scene_name_key(scene_path: String) -> String:
	var base := _strip_digits(scene_path.get_file().get_basename())
	return base.to_lower().replace("_", "").replace("-", "").replace(" ", "")


func _scene_display_name(scene_path: String) -> String:
	var base := _strip_digits(scene_path.get_file().get_basename())
	return base.replace("-", " ").capitalize()


func _strip_digits(value: String) -> String:
	var result := ""
	for character in value:
		var code := character.unicode_at(0)
		if code < 48 or code > 57:
			result += character
	return result


func _sanitize_hero_name(hero_name: String) -> String:
	var sanitized := hero_name.strip_edges().left(20)
	return sanitized if not sanitized.is_empty() else "Hero"


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


func claim_strength_crystal(_scene_path: String = "", _player_position: Vector2 = Vector2.ZERO, _player_speed: float = 380.0) -> bool:
	if bool(_config.get_value("upgrades", "strength_crystal_claimed", false)):
		return false

	_player_max_hp += 10
	_player_hp = mini(_player_hp + 10, _player_max_hp)
	_player_attack += 3
	_config.set_value("upgrades", "strength_crystal_claimed", true)
	return true


func has_claimed_strength_crystal() -> bool:
	return bool(_config.get_value("upgrades", "strength_crystal_claimed", false))


## Marks the beach tutorial dummy as defeated and writes it immediately so the
## result survives continuing from a save or reloading the room.
func mark_dummy_boss_defeated() -> void:
	_config.set_value("progress", "dummy_boss_defeated", true)
	_save_config()


func has_defeated_dummy_boss() -> bool:
	return bool(_config.get_value("progress", "dummy_boss_defeated", false))


func save_player_state(
	scene_path: String,
	player_position: Vector2,
	player_speed: float = 380.0,
	player_rotation: float = 0.0,
	sprite_rotation: float = 0.0
) -> bool:
	if scene_path.is_empty():
		return false

	var saved_location_id := location_id_from_scene(scene_path)
	var saved_location_name := location_name_from_scene(scene_path)
	_config.set_value("progress", "scene_path", scene_path)
	_config.set_value("progress", "saved_location_id", saved_location_id)
	_config.set_value("progress", "saved_location_name", saved_location_name)
	# Saving here also makes this the last visited location.
	_config.set_value("progress", "last_location_id", saved_location_id)
	_config.set_value("progress", "last_location_name", saved_location_name)
	_config.set_value("progress", "player_position", player_position)
	_config.set_value("progress", "player_speed", player_speed)
	_config.set_value("progress", "player_rotation", player_rotation)
	_config.set_value("progress", "sprite_rotation", sprite_rotation)
	# Using a save point restores the player to full health.
	_player_hp = _player_max_hp
	_config.set_value("player", "hp", _player_hp)
	_config.set_value("player", "max_hp", _player_max_hp)
	_config.set_value("player", "attack", _player_attack)
	_config.set_value("player", "hero_name", _hero_name)
	_config.set_value("player", "gold", _gold)
	_write_inventory_to_config()
	var saved := _save_config()
	_has_save = saved
	return saved


func delete_save() -> bool:
	if not _remove_save_file():
		return false
	_reset_state()
	inventory_changed.emit(get_inventory())
	gold_changed.emit(_gold)
	return true


func _remove_save_file() -> bool:
	if not FileAccess.file_exists(save_path):
		return true
	var absolute_path := ProjectSettings.globalize_path(save_path)
	var result := DirAccess.remove_absolute(absolute_path)
	if result != OK:
		push_error("SaveManager: could not delete save file (error %d)." % result)
		return false
	return true
