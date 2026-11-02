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
	_test_purchase()
	await _test_persistence()
	await _test_strength_crystal()
	await _test_battle_items()
	_test_delete_resets_economy()

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


func _test_purchase() -> void:
	var starting_gold: int = _save.call("get_gold")
	_check(_shop.call("buy_item", "general_store", "health_potion", 1), "purchase succeeds")
	_check(_save.call("get_gold") == starting_gold - 25, "purchase deducts gold")
	_check(_save.call("get_item_count", "health_potion") == 1, "purchase adds item")


func _test_persistence() -> void:
	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame

	_check(_save.call("get_gold") == 75, "gold persists across reload")
	_check(_save.call("get_item_count", "health_potion") == 1, "inventory persists across reload")


func _test_strength_crystal() -> void:
	_check(not _save.call("has_claimed_strength_crystal"), "strength crystal initially unclaimed")
	var hp_before: Vector2i = _save.call("get_player_health", 40, 40)
	var atk_before: int = _save.call("get_player_attack", 12)
	_check(_save.call("claim_strength_crystal", "res://scenes/Gameplay/game_test_scene.tscn", Vector2(100, 100), 380.0), "claim strength crystal succeeds")
	_check(_save.call("has_claimed_strength_crystal"), "strength crystal marked as claimed")
	_check(not _save.call("claim_strength_crystal", "res://scenes/Gameplay/game_test_scene.tscn", Vector2(100, 100), 380.0), "strength crystal cannot be claimed twice")
	var hp_after: Vector2i = _save.call("get_player_health", 40, 40)
	var atk_after: int = _save.call("get_player_attack", 12)
	_check(hp_after.y == hp_before.y + 10, "strength crystal adds 10 max HP")
	_check(atk_after == atk_before + 3, "strength crystal adds 3 attack")

	# Persistence check across reload
	_save.call("set_save_path", TEST_SAVE_PATH)
	await process_frame
	_check(_save.call("has_claimed_strength_crystal"), "strength crystal status persists across reload")


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


func _test_delete_resets_economy() -> void:
	_check(_save.call("add_gold", 50), "gold can be added before reset")
	_check(_save.call("delete_save"), "save deletes")
	_check(_save.call("get_gold") == EXPECTED_STARTING_GOLD, "delete resets gold")
	_check(_save.call("get_inventory").is_empty(), "delete clears inventory")
	_check(not _save.call("has_claimed_strength_crystal"), "delete resets strength crystal")
	_check(not _save.call("has_save"), "delete clears Continue state")


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
