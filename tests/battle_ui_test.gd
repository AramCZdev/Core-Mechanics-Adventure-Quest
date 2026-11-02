extends SceneTree
## Headless integration test for BattleUI wiring.
##
## Run with:
##   godot --headless --path . --script res://tests/battle_ui_test.gd

var _ui: BattleUI
var _manager: BattleManager
var _failures: Array[String] = []


func _initialize() -> void:
	_ui = load("res://scenes/battle/battle_ui.tscn").instantiate() as BattleUI
	_manager = _ui.get_node("BattleManager") as BattleManager
	# Keep the test isolated from the player's real save file.
	_manager.use_persistent_progress = false
	_manager.use_persistent_items = false
	_manager.transition_delay = 0.0
	_manager.enemy_windup_delay = 0.0
	_manager.result_delay = 0.0
	root.add_child(_ui)
	await process_frame

	_test_initial_state()
	_test_attack_flow()
	_test_block_flow()
	_test_item_picker()
	_test_victory()
	await _test_victory_auto_exit()

	if _failures.is_empty():
		print("Battle UI test: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("Battle UI test: " + failure)
		quit(1)


func _test_initial_state() -> void:
	_check(InputMap.has_action("attack"), "attack input action exists")
	_check(InputMap.has_action("block"), "block input action exists")
	var attack_event := InputMap.action_get_events("attack")[0] as InputEventKey
	_check(attack_event != null and attack_event.keycode == KEY_Z, "attack uses layout-aware Z")
	_check(attack_event != null and attack_event.physical_keycode == 0, "attack is not position-bound")
	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "UI auto-starts player turn")
	_check(paused, "battle pauses the scene tree")
	_check(not _item_button().visible, "item button hidden until items are enabled")
	_check(not _attack_button().disabled, "attack button enabled on player turn")
	_check(_enemy_name().text == "Mossling", "enemy name rendered")
	_check(_enemy_hp().text.contains("60"), "enemy HP rendered")
	_check(_player_hp().text.contains("40"), "player HP rendered")
	_check(not _timing_area().visible, "timing area hidden on player turn")


func _test_attack_flow() -> void:
	_attack_button().pressed.emit()
	_check(_manager.phase == BattleManager.Phase.ATTACK_TIMING, "attack button starts timing")
	_check(_timing_area().visible, "timing area shown")
	_check(_attack_timing().visible, "attack bar shown")
	_check(_attack_button().disabled, "actions disabled during timing")

	_attack_timing().marker_position = 0.5
	_attack_timing().submit_now()

	_check(_manager.enemy_hp == 42, "UI forwards perfect attack damage")
	_check(_manager.phase == BattleManager.Phase.RESOLVE_PLAYER, "attack result phase reached")
	_check(not _timing_area().visible, "timing area hidden after submit")
	_check(_message_label().text.contains("Perfect"), "attack result shown in message")


func _test_block_flow() -> void:
	_manager.advance_time(1.0)
	_check(_manager.phase == BattleManager.Phase.ENEMY_WINDUP, "UI advances to windup")
	_manager.advance_time(1.0)
	_check(_manager.phase == BattleManager.Phase.BLOCK_TIMING, "UI advances to block timing")
	_check(_timing_area().visible, "block timing area shown")
	_check(_block_timing().visible, "block bar shown")
	_check(_timing_prompt().text.contains("X"), "block prompt mentions X")

	_block_timing().marker_position = 0.5
	_block_timing().submit_now()

	_check(_manager.player_hp == 40, "perfect block prevents damage")
	_check(_manager.phase == BattleManager.Phase.RESOLVE_ENEMY, "block result phase reached")

	_manager.advance_time(1.0)
	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "UI returns to player turn")
	_check(not _attack_button().disabled, "actions re-enabled on player turn")


func _test_item_picker() -> void:
	_ui.items_enabled = true
	_ui._refresh_actions()
	_check(_item_button().visible, "item button visible once items are enabled")

	_manager.player_hp = 20
	_manager.player_stats_changed.emit(20, _manager.player_max_hp, _manager.items)
	_item_button().pressed.emit()

	_check(_ui._item_menu_open, "item button opens the picker")
	_check(_ui._item_buttons.size() == 2, "picker lists owned item plus cancel")
	_check(_ui._item_panel.get_parent().visible, "picker panel is visible")
	_check(not _attack_button().is_visible_in_tree(), "actions hidden while picker is open")

	_ui._on_item_chosen("health_potion")
	_check(_manager.player_hp == 35, "picker heals with the chosen item")
	_check(_manager.items == 1, "picker consumes exactly one item")
	_check(not _ui._item_menu_open, "picker closes after choosing")

	# Finish the enemy turn so the next test starts on the player's turn.
	_manager.advance_time(0.01)
	_manager.advance_time(0.01)
	_block_timing().marker_position = 0.5
	_block_timing().submit_now()
	_manager.advance_time(0.01)
	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "item turn ends back on player turn")


func _test_victory() -> void:
	_manager.enemy_hp = 1
	_manager.enemy_stats_changed.emit(1, _manager.enemy.max_hp)
	_attack_button().pressed.emit()
	_attack_timing().marker_position = 0.5
	_attack_timing().submit_now()

	_check(_manager.phase == BattleManager.Phase.VICTORY, "UI reaches victory")
	_check(not paused, "battle restores pause state on victory")
	_check(_battle_over_panel().visible, "battle over panel shown")
	_check(_battle_over_label().text == "VICTORY!", "victory label shown")
	_check(_attack_button().disabled, "actions disabled after victory")
	_check(_ui.get_node_or_null("%RestartButton") == null, "restart button removed")


func _test_victory_auto_exit() -> void:
	_ui.victory_exit_delay = 0.05
	_check(_manager.restart_battle(), "manager restart prepares auto-exit test")
	_manager.enemy_hp = 1
	_manager.enemy_stats_changed.emit(1, _manager.enemy.max_hp)
	_attack_button().pressed.emit()
	_attack_timing().marker_position = 0.5
	_attack_timing().submit_now()

	_check(_ui.visible, "battle stays visible immediately after victory")
	await create_timer(0.15).timeout
	_check(not _ui.visible, "battle hides after the victory exit delay")


func _attack_button() -> Button:
	return _ui.get_node("%AttackButton") as Button


func _item_button() -> Button:
	return _ui.get_node("%ItemButton") as Button


func _timing_area() -> VBoxContainer:
	return _ui.get_node("%TimingArea") as VBoxContainer


func _timing_prompt() -> Label:
	return _ui.get_node("%TimingPrompt") as Label


func _attack_timing() -> AttackTiming:
	return _ui.get_node("%AttackTiming") as AttackTiming


func _block_timing() -> BlockTiming:
	return _ui.get_node("%BlockTiming") as BlockTiming


func _enemy_name() -> Label:
	return _ui.get_node("%EnemyNameLabel") as Label


func _enemy_hp() -> Label:
	return _ui.get_node("%EnemyHPLabel") as Label


func _player_hp() -> Label:
	return _ui.get_node("%PlayerHPLabel") as Label


func _message_label() -> Label:
	return _ui.get_node("%MessageLabel") as Label


func _battle_over_panel() -> HBoxContainer:
	return _ui.get_node("%BattleOverPanel") as HBoxContainer


func _battle_over_label() -> Label:
	return _ui.get_node("%BattleOverLabel") as Label


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
