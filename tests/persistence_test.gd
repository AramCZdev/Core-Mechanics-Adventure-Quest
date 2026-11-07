extends SceneTree
## Headless tests for save persistence, gold, shop purchases, and battle items.
##
## Uses the real SaveManager/ShopManager autoloads but points SaveManager at an
## isolated test file so normal saves are not touched.
##
## Run with:
##   godot --headless --path . --script res://tests/persistence_test.gd

const TEST_SAVE_PATH := "user://test_savegame.cfg"
const REAL_SAVE_PATH := "user://savegame.cfg"
const EXPECTED_STARTING_GOLD := 100
const EXPECTED_VICTORY_GOLD := 25

var _failures: Array[String] = []
var _save: Node
var _shop: Node


func _initialize() -> void:
	_save = root.get_node_or_null("SaveManager")
	_shop = root.get_node_or_null("ShopManager")
	if _save == null or _shop == null:
		push_error("Persistence test: SaveManager and ShopManager autoloads are required.")
		quit(1)
		return

	_remove_test_save()
	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame

	_test_starting_economy()
	_test_location_lookup()
	_test_purchase()
	_test_ice_cream_shop()
	await _test_persistence()
	await _test_strength_crystal()
	await _test_saved_location()
	await _test_saved_rotation()
	await _test_dummy_boss_progress()
	await _test_battle_items()
	await _test_talk_victory_reward()
	_test_save_heals()
	_test_delete_resets_economy()
	await _test_location_persists_without_save()

	_remove_test_save()
	_save.call("set_save_path", REAL_SAVE_PATH)

	if _failures.is_empty():
		print("Persistence test: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("Persistence test: " + failure)
		quit(1)


func _test_starting_economy() -> void:
	_check(_save.call("get_gold") == EXPECTED_STARTING_GOLD, "new save starts with gold")
	_check(_save.call("get_inventory").is_empty(), "new save starts with an empty inventory")
	_check(not _save.call("has_save"), "new save does not offer Continue")
	_check(_save.call("get_saved_location_id") == 0, "no saved location before a save")
	_check(_save.call("get_saved_location_name") == "Not Started", "unsaved location name is Not Started")
	_check(is_zero_approx(float(_save.call("get_saved_player_rotation"))), "no player rotation before a save")
	_check(is_zero_approx(float(_save.call("get_saved_sprite_rotation"))), "no sprite rotation before a save")


func _test_location_lookup() -> void:
	_check(_save.call("location_id_from_scene", "res://scenes/Gameplay/Rooms/TheBeach.tscn") == 1, "TheBeach maps to location 1")
	_check(_save.call("location_id_from_scene", "res://scenes/Gameplay/Rooms/TheBeach2.tscn") == 1, "trailing digits are ignored")
	_check(_save.call("location_id_from_scene", "res://scenes/Gameplay/Rooms/1_TheBeach.tscn") == 1, "leading digits are ignored")
	_check(_save.call("location_id_from_scene", "res://scenes/Gameplay/Rooms/Forest.tscn") == 2, "Forest maps to location 2")
	_check(_save.call("location_id_from_scene", "res://scenes/Gameplay/Rooms/Castle.tscn") == 3, "Castle maps to location 3")
	_check(_save.call("location_id_from_scene", "res://scenes/Gameplay/Rooms/TheEnd.tscn") == 4, "TheEnd maps to location 4")
	_check(_save.call("location_name_from_scene", "res://scenes/Gameplay/Rooms/TheBeach.tscn") == "The Beach", "TheBeach becomes The Beach")
	_check(_save.call("location_name_from_scene", "res://scenes/Gameplay/Rooms/TheBeach2.tscn") == "The Beach", "location name ignores digits")
	_check(_save.call("location_name_from_scene", "res://scenes/Gameplay/Rooms/TheEnd.tscn") == "The End", "TheEnd becomes The End")
	_check(_save.call("location_name_from_scene", "res://scenes/Gameplay/Rooms/SecretCave2.tscn") == "Secret Cave", "unknown names are humanized and digits ignored")


func _test_purchase() -> void:
	var starting_gold: int = _save.call("get_gold")
	_check(_shop.call("buy_item", "general_store", "health_potion", 1), "purchase succeeds")
	_check(_save.call("get_gold") == starting_gold - 25, "purchase deducts gold")
	_check(_save.call("get_item_count", "health_potion") == 1, "purchase adds item")
	_check(not _save.call("has_save"), "purchase does not create a save")


func _test_ice_cream_shop() -> void:
	var offers: Array = _shop.call("get_shop_inventory", "ice_cream_shop")
	_check(offers.size() == 1, "ice cream shop only sells one item")
	_check(str(offers[0].get("id", "")) == "ice_cream", "ice cream shop sells ice cream")
	var item := ItemDatabase.get_item("ice_cream")
	_check(str(item.get("name", "")) == "Ice Cream", "ice cream item is registered")
	_check(int(item.get("effect", {}).get("amount", 0)) == 15, "ice cream heals 15 HP")


func _test_persistence() -> void:
	# Purchases made before a save point must be discarded on reload.
	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame

	_check(_save.call("get_gold") == EXPECTED_STARTING_GOLD, "unsaved purchase is discarded on reload")
	_check(_save.call("get_item_count", "health_potion") == 0, "unsaved inventory is discarded on reload")
	_check(not _save.call("has_save"), "unsaved purchase still does not offer Continue")

	# Buy again and persist through a save point.
	_check(_shop.call("buy_item", "general_store", "health_potion", 1), "purchase after reload succeeds")
	_check(_save.call("save_player_state", "res://scenes/Gameplay/game_test_scene.tscn", Vector2(100, 100), 380.0), "save point writes the economy")
	_check(_save.call("has_save"), "save point creates a resumable save")

	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame

	_check(_save.call("get_gold") == 75, "gold persists once saved at a save point")
	_check(_save.call("get_item_count", "health_potion") == 1, "inventory persists once saved at a save point")


func _test_strength_crystal() -> void:
	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame

	_check(not _save.call("has_claimed_strength_crystal"), "strength crystal initially unclaimed")
	var hp_before: Vector2i = _save.call("get_player_health", 40, 40)
	var atk_before: int = _save.call("get_player_attack", 12)
	_check(_save.call("claim_strength_crystal"), "claim strength crystal succeeds")
	_check(_save.call("has_claimed_strength_crystal"), "strength crystal marked as claimed")
	_check(not _save.call("claim_strength_crystal"), "strength crystal cannot be claimed twice")
	var hp_after: Vector2i = _save.call("get_player_health", 40, 40)
	var atk_after: int = _save.call("get_player_attack", 12)
	_check(hp_after.y == hp_before.y + 10, "strength crystal adds 10 max HP")
	_check(atk_after == atk_before + 3, "strength crystal adds 3 attack")

	# The claim is not written to disk until a save point is used.
	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame
	_check(not _save.call("has_claimed_strength_crystal"), "strength crystal is not saved until a save point")

	# Save manually as a SavePoint would:
	_check(_save.call("claim_strength_crystal"), "strength crystal can be claimed again after reload")
	_save.call("save_player_state", "res://scenes/Gameplay/game_test_scene.tscn", Vector2(100, 100), 380.0)

	# Persistence check across reload once saved at a save point
	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame
	_check(_save.call("has_claimed_strength_crystal"), "strength crystal status persists across reload once saved")


func _test_saved_location() -> void:
	_save.call("save_player_state", "res://scenes/Gameplay/Rooms/TheBeach.tscn", Vector2(100, 100), 380.0)
	_check(_save.call("get_saved_location_id") == 1, "save point records The Beach location")
	_check(_save.call("get_saved_location_name") == "The Beach", "save point records The Beach name")

	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame
	_check(_save.call("get_saved_location_id") == 1, "saved location persists across reload")
	_check(_save.call("get_saved_location_name") == "The Beach", "saved location name persists across reload")

	# Walking into another room must not change where the save file points.
	_save.call("set_location_from_scene", "res://scenes/Gameplay/Rooms/Forest.tscn")
	_check(_save.call("get_saved_location_id") == 1, "saved location stays The Beach after visiting Forest")
	_check(_save.call("get_saved_location_name") == "The Beach", "saved location name stays The Beach")
	_check(_save.call("get_last_location_id") == 2, "last visited location is Forest")
	_check(_save.call("get_last_location_name") == "Forest", "last visited location name is Forest")


func _test_saved_rotation() -> void:
	_save.call("save_player_state", "res://scenes/Gameplay/Rooms/Castle.tscn", Vector2(64, 32), 380.0, 0.75, -0.4)
	_check(is_equal_approx(float(_save.call("get_saved_player_rotation")), 0.75), "save point records player rotation")
	_check(is_equal_approx(float(_save.call("get_saved_sprite_rotation")), -0.4), "save point records sprite rotation")

	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame
	_check(is_equal_approx(float(_save.call("get_saved_player_rotation")), 0.75), "player rotation persists across reload")
	_check(is_equal_approx(float(_save.call("get_saved_sprite_rotation")), -0.4), "sprite rotation persists across reload")


func _test_dummy_boss_progress() -> void:
	_check(not _save.call("has_defeated_dummy_boss"), "dummy boss initially undefeated")
	_save.call("mark_dummy_boss_defeated")
	_check(_save.call("has_defeated_dummy_boss"), "dummy boss marked defeated")

	# The flag must survive a reload without needing another manual save.
	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame
	_check(_save.call("has_defeated_dummy_boss"), "dummy boss status persists across reload")


func _test_battle_items() -> void:
	var manager: BattleManager = load("res://scripts/battle/battle_manager.gd").new()
	manager.name = "BattleManager"
	root.add_child(manager)
	await process_frame

	manager.transition_delay = 0.0
	manager.enemy_windup_delay = 0.0
	manager.result_delay = 0.0
	manager.random_seed = 12345

	var enemy := BattleEnemy.new()
	enemy.display_name = "Testling"
	enemy.max_hp = 100
	enemy.attack_damage = 10
	enemy.damage_variance = 0

	_save.call("add_item", "strength_potion", 1)
	_check(manager.start_battle(enemy), "battle starts")
	_check(manager.items == 2, "battle totals every usable owned item")
	var usable: Array = manager.get_usable_items()
	var usable_ids: Array = usable.map(func(entry: Dictionary) -> String: return str(entry.get("id", "")))
	_check(usable_ids.has("health_potion") and usable_ids.has("strength_potion"), "battle lists all owned usable items")
	manager.player_hp = 10
	_check(manager.use_item("health_potion"), "explicit item use accepted")
	_check(manager.player_hp == 30, "health potion heals its database amount")
	_check(manager.items == 1, "battle item count updates")
	_check(_save.call("get_item_count", "health_potion") == 0, "battle consumes chosen persistent item")
	_check(_save.call("get_item_count", "strength_potion") == 1, "unchosen items stay in inventory")

	var gold_before: int = _save.call("get_gold")
	_check(manager.start_battle(enemy), "reward battle starts")
	manager.select_action(BattleManager.ACTION_ATTACK)
	_check(manager.submit_attack("Perfect", 10.0), "lethal attack submitted")
	_check(manager.phase == BattleManager.Phase.VICTORY, "victory reached")
	_check(
		_save.call("get_gold") == gold_before + EXPECTED_VICTORY_GOLD,
		"victory awards gold"
	)

	manager.queue_free()
	await process_frame


func _test_talk_victory_reward() -> void:
	var manager: BattleManager = load("res://scripts/battle/battle_manager.gd").new()
	manager.name = "TalkVictoryManager"
	manager.transition_delay = 0.0
	manager.random_seed = 12345
	root.add_child(manager)
	await process_frame

	var enemy := BattleEnemy.new()
	enemy.display_name = "Talkling"
	enemy.max_hp = 100
	enemy.attack_damage = 0
	enemy.damage_variance = 0
	enemy.can_win_by_talking = true
	enemy.talks_to_win = 1
	enemy.talk_victory_text = "Calmed."

	var hp_before: Vector2i = _save.call("get_player_health", 40, 40)
	var attack_before: int = _save.call("get_player_attack", 12)
	var gold_before: int = _save.call("get_gold")

	_check(manager.start_battle(enemy), "talk reward battle starts")
	_check(manager.select_action(BattleManager.ACTION_TALK), "talk accepted")
	_check(manager.phase == BattleManager.Phase.VICTORY, "talk reaches victory")
	_check(
		_save.call("get_gold") == gold_before + EXPECTED_VICTORY_GOLD,
		"talk victory awards gold"
	)
	var hp_after: Vector2i = _save.call("get_player_health", 40, 40)
	_check(hp_after == hp_before, "talk victory does not change HP or max HP")
	_check(
		_save.call("get_player_attack", 12) == attack_before,
		"talk victory does not increase attack"
	)

	manager.queue_free()
	await process_frame


func _test_save_heals() -> void:
	var max_hp: int = int(_save.call("get_player_health", 40, 40).y)
	_save.call("set_player_health", 1, max_hp)
	_check(
		_save.call("save_player_state", "res://scenes/Gameplay/game_test_scene.tscn", Vector2(100, 100), 380.0),
		"healing save point writes the save"
	)
	var healed: Vector2i = _save.call("get_player_health", 40, 40)
	_check(healed.x == max_hp, "saving heals the player to max HP")


func _test_delete_resets_economy() -> void:
	_check(_save.call("add_gold", 50), "gold can be added before reset")
	_check(_save.call("delete_save"), "save deletes")
	_check(_save.call("get_gold") == EXPECTED_STARTING_GOLD, "delete resets gold")
	_check(_save.call("get_inventory").is_empty(), "delete clears inventory")
	_check(not _save.call("has_claimed_strength_crystal"), "delete resets strength crystal")
	_check(not _save.call("has_defeated_dummy_boss"), "delete resets dummy boss progress")
	_check(_save.call("get_saved_location_id") == 0, "delete resets saved location")
	_check(_save.call("get_last_location_id") == 0, "delete resets last location")
	_check(not _save.call("has_save"), "delete clears Continue state")


func _test_location_persists_without_save() -> void:
	_save.call("set_location_from_scene", "res://scenes/Gameplay/Rooms/TheBeach.tscn")
	_check(_save.call("get_saved_location_id") == 1, "location is recorded immediately")
	_check(_save.call("get_saved_location_name") == "The Beach", "location name is recorded immediately")
	_check(not _save.call("has_save"), "recording location does not create a resumable save")

	# Simulate quitting and launching the game again.
	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame
	_check(_save.call("get_saved_location_id") == 1, "location survives quitting without a save point")
	_check(_save.call("get_saved_location_name") == "The Beach", "location name survives quitting without a save point")
	_check(not _save.call("has_save"), "location-only progress still has no Continue")

	# Menus and unknown rooms must not overwrite the last real location.
	_save.call("set_location_from_scene", "res://scenes/mainmenu.tscn")
	_check(_save.call("get_saved_location_id") == 1, "unknown scenes do not overwrite the location")

	_check(_save.call("delete_save"), "location test cleanup deletes save")


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
