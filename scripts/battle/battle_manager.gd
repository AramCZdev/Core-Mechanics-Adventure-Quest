extends Node
class_name BattleManager
## Turn-based battle state machine.
##
## Owns HP, item counts, turn order, and damage math. It knows nothing about
## nodes or input: BattleUI forwards player choices and timing results through
## select_action(), submit_attack(), and submit_block(). All outcomes are
## announced through signals.
##
## Flow:
##   PLAYER_TURN -> ATTACK_TIMING -> RESOLVE_PLAYER -> ENEMY_WINDUP
##   -> BLOCK_TIMING -> RESOLVE_ENEMY -> PLAYER_TURN
## Defend / Item / Talk skip straight from RESOLVE_PLAYER to ENEMY_WINDUP.

signal battle_started(enemy: BattleEnemy)
signal battle_ended(victory: bool)
## No-argument version for systems that only need to know the battle finished.
signal on_battle_ended
signal phase_changed(new_phase: int)
signal input_locked_changed(locked: bool)
signal message_changed(text: String)
signal player_stats_changed(hp: int, max_hp: int, items: int)
signal enemy_stats_changed(hp: int, max_hp: int)
signal action_selected(action: String)

signal turn_started(turn: int)
signal attack_timing_started
signal attack_resolved(zone: String, multiplier: float, damage: int)
signal enemy_attack_started
signal block_timing_started
signal block_resolved(zone: String, reduction: float, damage: int)
signal defend_started(reduction: float)
signal talk_started(line: String)

signal enemy_damaged(amount: int, hp: int)
signal player_damaged(amount: int, hp: int)
signal player_healed(amount: int, hp: int, items_left: int)
signal battle_error(text: String)

enum Phase {
	IDLE,
	PLAYER_TURN,
	ATTACK_TIMING,
	RESOLVE_PLAYER,
	ENEMY_WINDUP,
	BLOCK_TIMING,
	RESOLVE_ENEMY,
	VICTORY,
	DEFEAT,
}

const ACTION_ATTACK := "attack"
const ACTION_DEFEND := "defend"
const ACTION_ITEM := "item"
const ACTION_TALK := "talk"

@export var enemy: BattleEnemy

@export_group("Player")
@export_range(1, 9999, 1) var player_max_hp: int = 40
@export_range(0, 999, 1) var player_attack: int = 12
@export_range(0, 99, 1) var starting_items: int = 2
@export_range(0, 999, 1) var item_heal_amount: int = 15
@export_range(0.0, 1.0, 0.05) var defend_damage_reduction: float = 0.25

@export_group("Pacing")
## Delay after Defend / Item / Talk before the enemy acts.
@export_range(0.0, 5.0, 0.05, "suffix:s") var transition_delay: float = 0.7
## Wind-up before the block bar appears.
@export_range(0.0, 5.0, 0.05, "suffix:s") var enemy_windup_delay: float = 0.55
## How long a damage result stays on screen before the next phase.
@export_range(0.0, 5.0, 0.05, "suffix:s") var result_delay: float = 0.7

## 0 = randomize on battle start. Set non-zero for deterministic tests.
@export var random_seed: int = 0

var phase: int = Phase.IDLE
var player_hp: int = 0
var enemy_hp: int = 0
var items: int = 0
var turn_number: int = 0

var _battle_active: bool = false
var _defending: bool = false
var _phase_time_left: float = 0.0
var _talk_index: int = 0
var _talks_used: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func start_battle(enemy_override: BattleEnemy = null) -> bool:
	if enemy_override != null:
		enemy = enemy_override

	if enemy == null:
		battle_error.emit("BattleManager: no enemy configured.")
		return false

	var saved_health := SaveManager.get_player_health(player_max_hp, player_max_hp)
	player_max_hp = saved_health.y
	player_hp = maxi(1, saved_health.x)
	player_attack = SaveManager.get_player_attack(player_attack)
	SaveManager.set_player_health(player_hp, player_max_hp)
	enemy_hp = maxi(1, enemy.max_hp)
	items = maxi(0, starting_items)
	_defending = false
	_talk_index = 0
	_talks_used = 0
	turn_number = 0
	_battle_active = true
	_phase_time_left = 0.0

	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()

	battle_started.emit(enemy)
	player_stats_changed.emit(player_hp, player_max_hp, items)
	enemy_stats_changed.emit(enemy_hp, enemy.max_hp)
	_begin_player_turn()
	return true


func restart_battle() -> bool:
	return start_battle(enemy)


func select_action(action: String) -> bool:
	if not _battle_active or phase != Phase.PLAYER_TURN:
		return false

	match action:
		ACTION_ATTACK:
			action_selected.emit(ACTION_ATTACK)
			message_changed.emit("Press Z, X, or Enter when the marker is in the glowing zone!")
			_set_phase(Phase.ATTACK_TIMING)
			attack_timing_started.emit()
			return true

		ACTION_DEFEND:
			action_selected.emit(ACTION_DEFEND)
			_defending = true
			var percent := roundi(defend_damage_reduction * 100.0)
			defend_started.emit(defend_damage_reduction)
			message_changed.emit("You raise your guard. Incoming damage -%d%%." % percent)
			_begin_timed_phase(Phase.RESOLVE_PLAYER, transition_delay)
			return true

		ACTION_ITEM:
			action_selected.emit(ACTION_ITEM)
			_use_item()
			return true

		ACTION_TALK:
			action_selected.emit(ACTION_TALK)
			_talk_to_enemy()
			return true

		_:
			battle_error.emit("BattleManager: unknown action '%s'." % action)
			return false


## Called by BattleUI when the attack marker stops.
func submit_attack(zone: String, multiplier: float) -> bool:
	if not _battle_active or phase != Phase.ATTACK_TIMING:
		return false

	var safe_multiplier := clampf(multiplier, 0.0, 10.0)
	var damage := maxi(0, roundi(float(player_attack) * safe_multiplier))
	enemy_hp = maxi(0, enemy_hp - damage)

	enemy_stats_changed.emit(enemy_hp, enemy.max_hp)
	enemy_damaged.emit(damage, enemy_hp)
	attack_resolved.emit(zone, safe_multiplier, damage)
	if damage <= 0:
		message_changed.emit("%s! No damage dealt." % zone)
	else:
		message_changed.emit("%s! You deal %d damage." % [zone, damage])

	if enemy_hp <= 0:
		_end_battle(true)
		return true

	_begin_timed_phase(Phase.RESOLVE_PLAYER, result_delay)
	return true


## Called by BattleUI when the block marker stops.
func submit_block(zone: String, reduction: float) -> bool:
	if not _battle_active or phase != Phase.BLOCK_TIMING or enemy == null:
		return false

	var safe_reduction := clampf(reduction, 0.0, 1.0)
	var raw_damage := maxi(
		1,
		enemy.attack_damage + _rng.randi_range(-enemy.damage_variance, enemy.damage_variance)
	)

	var damage_float := float(raw_damage) * (1.0 - safe_reduction)
	if _defending:
		damage_float *= 1.0 - clampf(defend_damage_reduction, 0.0, 1.0)
	var damage := maxi(0, floori(damage_float))
	player_hp = maxi(0, player_hp - damage)

	player_stats_changed.emit(player_hp, player_max_hp, items)
	SaveManager.set_player_health(player_hp, player_max_hp)
	player_damaged.emit(damage, player_hp)
	block_resolved.emit(zone, safe_reduction, damage)

	if damage <= 0:
		message_changed.emit("%s block! No damage taken." % zone)
	elif safe_reduction >= 1.0:
		message_changed.emit("Perfect block! No damage taken.")
	else:
		message_changed.emit("%s block! You take %d damage." % [zone, damage])

	if player_hp <= 0:
		_end_battle(false)
		return true

	_begin_timed_phase(Phase.RESOLVE_ENEMY, result_delay)
	return true


func is_input_locked() -> bool:
	return not _battle_active or phase != Phase.PLAYER_TURN


func is_battle_active() -> bool:
	return _battle_active


func get_phase_name() -> String:
	match phase:
		Phase.PLAYER_TURN:
			return "PLAYER_TURN"
		Phase.ATTACK_TIMING:
			return "ATTACK_TIMING"
		Phase.RESOLVE_PLAYER:
			return "RESOLVE_PLAYER"
		Phase.ENEMY_WINDUP:
			return "ENEMY_WINDUP"
		Phase.BLOCK_TIMING:
			return "BLOCK_TIMING"
		Phase.RESOLVE_ENEMY:
			return "RESOLVE_ENEMY"
		Phase.VICTORY:
			return "VICTORY"
		Phase.DEFEAT:
			return "DEFEAT"
		_:
			return "IDLE"


## Test hook: advance timed transitions without waiting for real frames.
func advance_time(delta: float) -> void:
	if _phase_time_left <= 0.0:
		return
	_phase_time_left -= delta
	if _phase_time_left <= 0.0:
		_phase_time_left = 0.0
		_on_phase_timeout()


func _process(delta: float) -> void:
	advance_time(delta)


func _use_item() -> void:
	if items <= 0:
		message_changed.emit("You have no items left!")
		return

	items -= 1
	var healed := mini(item_heal_amount, player_max_hp - player_hp)
	player_hp += healed

	player_stats_changed.emit(player_hp, player_max_hp, items)
	SaveManager.set_player_health(player_hp, player_max_hp)
	player_healed.emit(healed, player_hp, items)
	if healed > 0:
		message_changed.emit("You drink a potion and recover %d HP." % healed)
	else:
		message_changed.emit("You drink a potion, but you are already at full HP.")

	_begin_timed_phase(Phase.RESOLVE_PLAYER, transition_delay)


func _talk_to_enemy() -> void:
	var line := "It does not respond."
	if enemy != null:
		line = enemy.no_talk_lines_text if not enemy.no_talk_lines_text.is_empty() else line
		if not enemy.talk_lines.is_empty():
			line = enemy.talk_lines[_talk_index % enemy.talk_lines.size()]
			_talk_index += 1

	_talks_used += 1
	talk_started.emit(line)

	if enemy != null and enemy.can_win_by_talking:
		var required := maxi(1, enemy.talks_to_win)
		if _talks_used >= required:
			var win_text := enemy.talk_victory_text.strip_edges()
			if win_text.is_empty():
				win_text = "You talked the %s down. Victory!" % enemy.display_name
			_end_battle(true, win_text)
			return

	message_changed.emit(line)
	_begin_timed_phase(Phase.RESOLVE_PLAYER, transition_delay)


func _begin_enemy_windup() -> void:
	if not _battle_active or enemy == null:
		return
	message_changed.emit("The %s winds up an attack..." % enemy.display_name)
	enemy_attack_started.emit()
	_begin_timed_phase(Phase.ENEMY_WINDUP, enemy_windup_delay)


func _begin_block_timing() -> void:
	if not _battle_active:
		return
	message_changed.emit("Block! Press X, Z, or Enter when the marker is in the glowing zone!")
	_set_phase(Phase.BLOCK_TIMING)
	block_timing_started.emit()


func _begin_player_turn() -> void:
	if not _battle_active:
		return
	_defending = false
	turn_number += 1
	_set_phase(Phase.PLAYER_TURN)
	message_changed.emit(_player_turn_message())
	turn_started.emit(turn_number)


func _player_turn_message() -> String:
	if enemy == null:
		return "Your turn. Choose an action."

	if not enemy.turn_lines.is_empty():
		var line := enemy.turn_lines[(turn_number - 1) % enemy.turn_lines.size()]
		if not line.strip_edges().is_empty():
			return line

	if turn_number == 1:
		if not enemy.intro_text.strip_edges().is_empty():
			return enemy.intro_text
		return "A %s blocks your path!" % enemy.display_name

	return "Your turn. Choose an action."


func _end_battle(victory: bool, custom_message: String = "") -> void:
	_battle_active = false
	_defending = false
	_phase_time_left = 0.0
	set_process(false)

	phase = Phase.VICTORY if victory else Phase.DEFEAT
	if victory:
		var upgraded_stats := SaveManager.reward_battle_victory(
			player_hp,
			player_max_hp,
			player_attack
		)
		player_hp = upgraded_stats.x
		player_max_hp = upgraded_stats.y
		player_attack = upgraded_stats.z
		player_stats_changed.emit(player_hp, player_max_hp, items)

	if not custom_message.is_empty():
		var reward_message := "%s\n+5 Max HP, +1 Attack." % custom_message if victory else custom_message
		message_changed.emit(reward_message)
	elif victory:
		message_changed.emit("Victory! +5 Max HP, +1 Attack.")
	else:
		message_changed.emit("Defeat... You fall in battle.")

	phase_changed.emit(phase)
	input_locked_changed.emit(true)
	battle_ended.emit(victory)
	on_battle_ended.emit()


func _begin_timed_phase(new_phase: int, duration: float) -> void:
	_set_phase(new_phase)
	_phase_time_left = maxf(duration, 0.0001)
	set_process(true)


func _set_phase(new_phase: int) -> void:
	phase = new_phase
	_phase_time_left = 0.0
	if new_phase in [Phase.PLAYER_TURN, Phase.ATTACK_TIMING, Phase.BLOCK_TIMING]:
		set_process(false)
	phase_changed.emit(phase)
	input_locked_changed.emit(is_input_locked())


func _on_phase_timeout() -> void:
	match phase:
		Phase.RESOLVE_PLAYER:
			_begin_enemy_windup()
		Phase.ENEMY_WINDUP:
			_begin_block_timing()
		Phase.RESOLVE_ENEMY:
			_begin_player_turn()
		_:
			set_process(false)
