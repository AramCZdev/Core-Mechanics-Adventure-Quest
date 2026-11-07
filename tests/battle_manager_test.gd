extends SceneTree
## Headless state-machine tests for BattleManager.
##
## Run with:
##   godot --headless --path . --script res://tests/battle_manager_test.gd

var _manager: BattleManager
var _failures: Array[String] = []
var _last_victory: Variant = null
var _last_talk: String = ""
var _last_message: String = ""
var _last_attack: Array = []
var _last_block: Array = []


func _initialize() -> void:
	_manager = BattleManager.new()
	# Keep the test isolated from the player's real save file.
	_manager.use_persistent_progress = false
	_manager.use_persistent_items = false
	root.add_child(_manager)
	_manager.transition_delay = 0.0
	_manager.enemy_windup_delay = 0.0
	_manager.result_delay = 0.0
	_manager.random_seed = 12345

	_manager.battle_ended.connect(_on_battle_ended)
	_manager.talk_started.connect(_on_talk_started)
	_manager.message_changed.connect(_on_message_changed)
	_manager.attack_resolved.connect(_on_attack_resolved)
	_manager.block_resolved.connect(_on_block_resolved)

	_test_full_round()
	_test_timeout_penalties()
	_test_defend_reduction()
	_test_item_and_no_items()
	_test_talk()
	_test_talk_text_controls()
	_test_talk_victory_disabled()
	_test_talk_victory()
	_test_intro_text()
	_test_turn_lines()
	_test_survival_victory()
	_test_survival_does_not_end_early()
	_test_survival_disabled()
	_test_victory()
	_test_defeat()
	_test_restart()

	if _failures.is_empty():
		print("Battle manager test: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("Battle manager test: " + failure)
		quit(1)


func _test_full_round() -> void:
	_start(_make_enemy(100, 10))

	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "battle starts on player turn")
	_check(not _manager.is_input_locked(), "player turn accepts input")
	_check(_manager.select_action(BattleManager.ACTION_ATTACK), "attack action accepted")
	_check(_manager.phase == BattleManager.Phase.ATTACK_TIMING, "attack opens timing phase")
	_check(not _manager.select_action(BattleManager.ACTION_DEFEND), "actions blocked during timing")

	_check(_manager.submit_attack("Perfect", 1.5), "perfect attack submitted")
	_check(_manager.enemy_hp == 82, "perfect attack deals 18 (12 x 1.5)")
	_check(_last_attack == ["Perfect", 1.5, 18], "attack_resolved payload")
	_check(not _manager.submit_attack("Perfect", 1.5), "repeated attack input ignored")
	_check(_manager.enemy_hp == 82, "repeated attack does not deal damage")
	_check(_manager.phase == BattleManager.Phase.RESOLVE_PLAYER, "damage result phase")

	_advance()
	_check(_manager.phase == BattleManager.Phase.ENEMY_WINDUP, "enemy windup after result")
	_advance()
	_check(_manager.phase == BattleManager.Phase.BLOCK_TIMING, "block timing after windup")

	_check(_manager.submit_block("Perfect", 1.0), "perfect block submitted")
	_check(_manager.player_hp == 40, "perfect block takes no damage")
	_check(_last_block == ["Perfect", 1.0, 0], "block_resolved payload")
	_check(_manager.phase == BattleManager.Phase.RESOLVE_ENEMY, "block result phase")

	_advance()
	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "turn returns to player")


func _test_timeout_penalties() -> void:
	_start(_make_enemy(100, 10))
	_check(_manager.select_action(BattleManager.ACTION_ATTACK), "timeout attack accepted")
	_last_attack = []
	_check(_manager.submit_attack("Miss", 0.0), "zero multiplier attack submitted")
	_check(_manager.enemy_hp == 100, "attack timeout deals 0 damage")
	_check(_last_attack == ["Miss", 0.0, 0], "attack timeout payload has 0 damage")
	_check(_last_message == "Miss! No damage dealt.", "attack timeout message shows no damage")

	_advance()
	_advance()
	_check(_manager.phase == BattleManager.Phase.BLOCK_TIMING, "timeout test reaches block")
	_last_block = []
	_check(_manager.submit_block("Miss", 0.0), "zero reduction block submitted")
	_check(_manager.player_hp == 30, "block timeout takes full damage")
	_check(_last_block == ["Miss", 0.0, 10], "block timeout payload has 0% reduction")


func _test_defend_reduction() -> void:
	_start(_make_enemy(100, 10))
	_check(_manager.select_action(BattleManager.ACTION_DEFEND), "defend accepted")
	_check(_manager.phase == BattleManager.Phase.RESOLVE_PLAYER, "defend shows result phase")
	_advance()
	_advance()
	_check(_manager.phase == BattleManager.Phase.BLOCK_TIMING, "defend reaches block timing")

	# 10 raw x (1 - 0.75 block) x (1 - 0.25 defend) = 1.875 -> 1.
	_check(_manager.submit_block("Good", 0.75), "good block during defend")
	_check(_manager.player_hp == 39, "defend stacks with block reduction")
	_check(_last_block == ["Good", 0.75, 1], "defend block payload")


func _test_item_and_no_items() -> void:
	_start(_make_enemy(100, 10))
	_manager.player_hp = 20
	_manager.player_stats_changed.emit(20, 40, 2)
	_check(_manager.get_usable_items().size() == 1, "usable items are listed")
	_check(_manager.select_action(BattleManager.ACTION_ITEM), "item accepted")
	_check(_manager.player_hp == 35, "item heals 15")
	_check(_manager.items == 1, "item consumed")
	_check(_manager.phase == BattleManager.Phase.RESOLVE_PLAYER, "item shows result phase")
	_advance()
	_check(_manager.phase == BattleManager.Phase.ENEMY_WINDUP, "item ends player turn")

	_start(_make_enemy(100, 10))
	_manager.items = 0
	_check(_manager.select_action(BattleManager.ACTION_ITEM), "empty item action is handled")
	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "empty item does not consume turn")
	_check(_manager.items == 0, "empty item stays empty")


func _test_talk() -> void:
	_start(_make_enemy(100, 10))
	_last_talk = ""
	_check(_manager.select_action(BattleManager.ACTION_TALK), "talk accepted")
	_check(_last_talk == "Hello.", "talk line emitted")
	_check(_manager.phase == BattleManager.Phase.RESOLVE_PLAYER, "talk shows result phase")


func _test_talk_text_controls() -> void:
	var enemy := _make_enemy(100, 10)
	enemy.can_win_by_talking = true
	enemy.talks_to_win = 3
	enemy.talk_lines = PackedStringArray(["Custom talk text."])
	_start(enemy)
	_last_message = ""
	_manager.select_action(BattleManager.ACTION_TALK)
	_check(_last_message == "Custom talk text.", "custom talk text shown exactly as written")

	var silent := _make_enemy(100, 10)
	silent.talk_lines = PackedStringArray()
	silent.no_talk_lines_text = "It silently refuses."
	_start(silent)
	_last_message = ""
	_manager.select_action(BattleManager.ACTION_TALK)
	_check(_last_message == "It silently refuses.", "custom fallback talk text shown")


func _test_talk_victory_disabled() -> void:
	_last_victory = null
	var enemy := _make_enemy(100, 10)
	enemy.can_win_by_talking = false
	enemy.talks_to_win = 1
	_start(enemy)
	_check(_manager.select_action(BattleManager.ACTION_TALK), "talk accepted when talk victory is off")
	_check(_manager.phase == BattleManager.Phase.RESOLVE_PLAYER, "disabled talk victory continues the turn")
	_check(_manager.is_battle_active(), "disabled talk victory keeps battle active")
	_check(_last_victory == null, "no battle_ended when talk victory is off")


func _test_talk_victory() -> void:
	_last_victory = null
	var enemy := _make_enemy(100, 10)
	enemy.can_win_by_talking = true
	enemy.talks_to_win = 2
	enemy.talk_victory_text = "The Testling calms down."
	_start(enemy)

	_check(_manager.select_action(BattleManager.ACTION_TALK), "first talk accepted")
	_check(_manager.phase == BattleManager.Phase.RESOLVE_PLAYER, "first talk does not win yet")
	_check(_last_message == "Hello.", "talk line shown without progress hint")

	_advance()
	_advance()
	_check(_manager.phase == BattleManager.Phase.BLOCK_TIMING, "talk round reaches block timing")
	_check(_manager.submit_block("Perfect", 1.0), "block after talk")
	_advance()
	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "talk round returns to player")

	_check(_manager.select_action(BattleManager.ACTION_TALK), "second talk accepted")
	_check(_manager.phase == BattleManager.Phase.VICTORY, "enough talks wins the battle")
	_check(_last_victory == true, "talk victory emits battle_ended(true)")
	_check(_last_message == "The Testling calms down.", "custom talk victory text shown")


func _test_intro_text() -> void:
	var enemy := _make_enemy(100, 10)
	enemy.intro_text = "A custom intro."
	_start(enemy)
	_check(_last_message == "A custom intro.", "custom intro text shown")


func _test_turn_lines() -> void:
	var enemy := _make_enemy(100, 10)
	enemy.turn_lines = PackedStringArray(["First turn.", "Second turn."])
	_start(enemy)
	_check(_last_message == "First turn.", "first custom turn line shown")

	_manager.select_action(BattleManager.ACTION_ATTACK)
	_manager.submit_attack("Good", 1.0)
	_advance()
	_advance()
	_manager.submit_block("Perfect", 1.0)
	_advance()

	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "turn text test returns to player")
	_check(_manager.turn_number == 2, "turn counter advances")
	_check(_last_message == "Second turn.", "second custom turn line shown")


func _test_survival_victory() -> void:
	_last_victory = null
	var enemy := _make_enemy(100, 0)
	enemy.survive_turns_to_win = 3
	enemy.survival_victory_text = "You outlasted the Testling."
	_start(enemy)

	for i in 3:
		_run_round()

	_check(_manager.phase == BattleManager.Phase.VICTORY, "surviving the turn limit wins")
	_check(_last_victory == true, "survival victory emits battle_ended(true)")
	_check(_manager.turn_number == 3, "survival victory ends on the final turn")
	_check(_last_message == "You outlasted the Testling.", "custom survival victory text shown")
	_check(not _manager.is_battle_active(), "battle inactive after survival victory")
	_check(_manager.restart_battle(), "restart after survival victory accepted")
	_check(_manager.turn_number == 1, "restart resets survival progress")
	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "restart returns to player turn")

	var default_enemy := _make_enemy(100, 0)
	default_enemy.survive_turns_to_win = 2
	_start(default_enemy)
	_run_round()
	_run_round()
	_check(_last_message == "You survived 2 turns. Victory!", "default survival victory text shown")


func _test_survival_does_not_end_early() -> void:
	var enemy := _make_enemy(100, 0)
	enemy.survive_turns_to_win = 3
	_start(enemy)
	_run_round()
	_run_round()
	_check(_manager.is_battle_active(), "battle stays active before the turn limit")
	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "survival limit keeps the turn loop going")
	_check(_manager.turn_number == 3, "two rounds completed before the three-turn limit")


func _test_survival_disabled() -> void:
	var enemy := _make_enemy(100, 0)
	enemy.survive_turns_to_win = 0
	_start(enemy)
	for i in 3:
		_run_round()
	_check(_manager.is_battle_active(), "survival limit of zero never ends the battle")
	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "no survival victory when disabled")
	_check(_manager.turn_number == 4, "turn counter keeps advancing without a limit")


func _test_victory() -> void:
	_last_victory = null
	_start(_make_enemy(10, 10))
	_manager.select_action(BattleManager.ACTION_ATTACK)
	_check(_manager.submit_attack("Perfect", 1.5), "lethal attack submitted")
	_check(_manager.phase == BattleManager.Phase.VICTORY, "zero HP ends in victory")
	_check(_last_victory == true, "battle_ended(true) emitted")
	_check(not _manager.is_battle_active(), "battle inactive after victory")
	_check(not _manager.select_action(BattleManager.ACTION_ATTACK), "no actions after victory")


func _test_defeat() -> void:
	_last_victory = null
	_start(_make_enemy(100, 10))
	_manager.player_hp = 1
	_manager.select_action(BattleManager.ACTION_ATTACK)
	_manager.submit_attack("Good", 1.0)
	_advance()
	_advance()
	_check(_manager.phase == BattleManager.Phase.BLOCK_TIMING, "defeat test reaches block")
	_check(_manager.submit_block("Miss", 0.0), "unblocked hit submitted")
	_check(_manager.player_hp == 0, "lethal damage reaches zero HP")
	_check(_manager.phase == BattleManager.Phase.DEFEAT, "zero player HP ends in defeat")
	_check(_last_victory == false, "battle_ended(false) emitted")


func _test_restart() -> void:
	_start(_make_enemy(10, 10))
	_manager.select_action(BattleManager.ACTION_ATTACK)
	_manager.submit_attack("Perfect", 1.5)
	_check(_manager.phase == BattleManager.Phase.VICTORY, "restart test reaches victory")
	_check(_manager.restart_battle(), "restart accepted")
	_check(_manager.phase == BattleManager.Phase.PLAYER_TURN, "restart returns to player turn")
	_check(_manager.enemy_hp == 10, "restart restores enemy HP")
	_check(_manager.player_hp == 40, "restart restores player HP")


func _start(enemy: BattleEnemy) -> void:
	_check(_manager.start_battle(enemy), "battle starts")


func _advance() -> void:
	_manager.advance_time(1.0)


func _run_round() -> void:
	_manager.select_action(BattleManager.ACTION_ATTACK)
	_manager.submit_attack("Good", 1.0)
	_advance()
	_advance()
	_manager.submit_block("Perfect", 1.0)
	_advance()


func _make_enemy(max_hp: int, damage: int) -> BattleEnemy:
	var enemy := BattleEnemy.new()
	enemy.display_name = "Testling"
	enemy.max_hp = max_hp
	enemy.attack_damage = damage
	enemy.damage_variance = 0
	enemy.talk_lines = PackedStringArray(["Hello."])
	return enemy


func _on_battle_ended(victory: bool) -> void:
	_last_victory = victory


func _on_talk_started(line: String) -> void:
	_last_talk = line


func _on_message_changed(text: String) -> void:
	_last_message = text


func _on_attack_resolved(zone: String, multiplier: float, damage: int) -> void:
	_last_attack = [zone, multiplier, damage]


func _on_block_resolved(zone: String, reduction: float, damage: int) -> void:
	_last_block = [zone, reduction, damage]


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
