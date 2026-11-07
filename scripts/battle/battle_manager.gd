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
## Item opens a choice of owned consumables through get_usable_items().
## Enemies with survive_turns_to_win > 0 end the battle in victory after the
## enemy's action on that turn if the player is still alive.

signal battle_started(enemy: BattleEnemy)
signal battle_ended(victory: bool)
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
## Read potion counts from the persistent inventory and consume them on use.
## Disable this to use the local `starting_items` count instead.
@export var use_persistent_items: bool = true
## Load/write HP, attack, and victory rewards through SaveManager.
## Disable this for isolated tests.
@export var use_persistent_progress: bool = true

@export_group("Pacing")
## Delay after Defend / Item / Talk before the enemy acts.
@export_range(0.0, 5.0, 0.05, "suffix:s") var transition_delay: float = 1.2
## Wind-up before the block bar appears.
@export_range(0.0, 5.0, 0.05, "suffix:s") var enemy_windup_delay: float = 1.0
## How long a damage result stays on screen before the next phase.
@export_range(0.0, 5.0, 0.05, "suffix:s") var result_delay: float = 1.2

## 0 = randomize on battle start. Set non-zero for deterministic tests.
@export var random_seed: int = 0

var phase: int = Phase.IDLE
var player_hp: int = 0
var enemy_hp: int = 0
var items: int = 0
var turn_number: int = 0

## Optional SaveManager override. Defaults to the /root/SaveManager autoload.
var save_manager: Node

var _battle_active: bool = false
var _defending: bool = false
var _phase_time_left: float = 0.0
var _talk_index: int = 0
var _talks_used: int = 0
var _attack_buff: int = 0
var _attack_buff_turns: int = 0
var _defense_buff: int = 0
var _defense_buff_turns: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_resolve_save_manager()


func _resolve_save_manager() -> Node:
	if save_manager != null and is_instance_valid(save_manager):
		return save_manager
	if not is_inside_tree():
		return null
	save_manager = get_tree().root.get_node_or_null("SaveManager")
	return save_manager


func start_battle(enemy_override: BattleEnemy = null) -> bool:
	if enemy_override != null:
		enemy = enemy_override

	if enemy == null:
		battle_error.emit("BattleManager: no enemy configured.")
		return false

	var save := _resolve_save_manager() if use_persistent_progress else null
	if save != null:
		var saved_health: Vector2i = save.call("get_player_health", player_max_hp, player_max_hp)
		player_max_hp = saved_health.y
		player_hp = maxi(1, saved_health.x)
		player_attack = int(save.call("get_player_attack", player_attack))
		save.call("set_player_health", player_hp, player_max_hp)
	else:
		player_hp = player_max_hp

	enemy_hp = maxi(1, enemy.max_hp)
	_refresh_items()
	_defending = false
	_talk_index = 0
	_talks_used = 0
	_attack_buff = 0
	_attack_buff_turns = 0
	_defense_buff = 0
	_defense_buff_turns = 0
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

	if not is_action_allowed(action):
		message_changed.emit(_action_restriction_message())
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
			var usable := get_usable_items()
			if usable.is_empty():
				message_changed.emit("You have no items left!")
				return true
			return use_item(str(usable[0].get("id", "")))

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
	var effective_attack := player_attack
	if _attack_buff_turns > 0:
		effective_attack += _attack_buff
	var damage := maxi(0, roundi(float(effective_attack) * safe_multiplier))
	enemy_hp = maxi(0, enemy_hp - damage)
	_consume_attack_buff()

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
	if _defense_buff_turns > 0:
		damage = maxi(0, damage - _defense_buff)
	player_hp = maxi(0, player_hp - damage)
	_consume_defense_buff()

	player_stats_changed.emit(player_hp, player_max_hp, items)
	var save := _resolve_save_manager() if use_persistent_progress else null
	if save != null:
		save.call("set_player_health", player_hp, player_max_hp)
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


## Returns the actions allowed on the current player turn. An empty result
## means every action is allowed.
func get_allowed_actions() -> PackedStringArray:
	if enemy == null or enemy.turn_action_restrictions.is_empty() or turn_number <= 0:
		return PackedStringArray()

	var index := mini(turn_number - 1, enemy.turn_action_restrictions.size() - 1)
	var action := enemy.turn_action_restrictions[index].strip_edges().to_lower()
	if action.is_empty():
		return PackedStringArray()
	return PackedStringArray([action])


func is_action_allowed(action: String) -> bool:
	var allowed := get_allowed_actions()
	if allowed.is_empty():
		return true
	return action.to_lower() in allowed


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


## Returns every owned consumable the battle can use, with its count and effect.
func get_usable_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var save := _resolve_save_manager()

	if use_persistent_items and save != null:
		var inventory: Dictionary = save.call("get_inventory")
		for item_id in ItemDatabase.ITEMS:
			var count := int(inventory.get(item_id, 0))
			if count <= 0:
				continue
			var item := ItemDatabase.get_item(item_id)
			var effect: Dictionary = item.get("effect", {})
			if not _is_supported_effect(effect):
				continue
			result.append({
				"id": item_id,
				"name": str(item.get("name", item_id)),
				"description": str(item.get("description", "")),
				"count": count,
				"effect": effect,
			})
		return result

	if items > 0:
		result.append({
			"id": "health_potion",
			"name": "Potion",
			"description": "Restores %d HP." % item_heal_amount,
			"count": items,
			"effect": {"kind": "heal", "amount": item_heal_amount},
		})
	return result


## Uses one specific item. Returns false if it is missing or unusable.
func use_item(item_id: String) -> bool:
	if not _battle_active or phase != Phase.PLAYER_TURN:
		return false

	var normalized_id := item_id.strip_edges().to_lower()
	var save := _resolve_save_manager()
	var effect: Dictionary

	if use_persistent_items and save != null:
		if not ItemDatabase.has_item(normalized_id):
			message_changed.emit("You cannot use that item in battle.")
			return false
		if int(save.call("get_item_count", normalized_id)) <= 0:
			message_changed.emit("You do not have that item.")
			return false
		var item := ItemDatabase.get_item(normalized_id)
		effect = item.get("effect", {})
		if not _is_supported_effect(effect):
			message_changed.emit("You cannot use that item in battle.")
			return false
		if not bool(save.call("remove_item", normalized_id, 1)):
			message_changed.emit("You cannot use that item right now.")
			return false
		action_selected.emit(ACTION_ITEM)
		_refresh_items()
	else:
		if items <= 0:
			message_changed.emit("You have no items left!")
			return false
		items -= 1
		effect = {"kind": "heal", "amount": item_heal_amount}
		action_selected.emit(ACTION_ITEM)

	_apply_item_effect(effect)
	player_stats_changed.emit(player_hp, player_max_hp, items)
	if save != null and use_persistent_progress:
		save.call("set_player_health", player_hp, player_max_hp)
	_begin_timed_phase(Phase.RESOLVE_PLAYER, transition_delay)
	return true


func _refresh_items() -> void:
	var save := _resolve_save_manager()

	if use_persistent_items and save != null:
		var inventory: Dictionary = save.call("get_inventory")
		items = 0
		for item_id in ItemDatabase.ITEMS:
			var count := int(inventory.get(item_id, 0))
			if count <= 0:
				continue
			var item := ItemDatabase.get_item(item_id)
			if not _is_supported_effect(item.get("effect", {})):
				continue
			items += count
		return

	items = maxi(0, starting_items)


func _is_supported_effect(effect: Dictionary) -> bool:
	return str(effect.get("kind", "")) in [
		"heal",
		"temporary_attack_boost",
		"temporary_defense_boost",
	]


func _apply_item_effect(effect: Dictionary) -> void:
	var kind := str(effect.get("kind", ""))
	match kind:
		"heal":
			var heal_amount := int(effect.get("amount", item_heal_amount))
			var healed := mini(heal_amount, player_max_hp - player_hp)
			player_hp += healed
			player_healed.emit(healed, player_hp, items)
			if healed > 0:
				message_changed.emit("You drink a potion and recover %d HP." % healed)
			else:
				message_changed.emit("You drink a potion, but you are already at full HP.")
		"temporary_attack_boost":
			_attack_buff = int(effect.get("amount", 0))
			_attack_buff_turns = maxi(1, int(effect.get("duration", 1)))
			message_changed.emit("Attack +%d for %d turns." % [_attack_buff, _attack_buff_turns])
		"temporary_defense_boost":
			_defense_buff = int(effect.get("amount", 0))
			_defense_buff_turns = maxi(1, int(effect.get("duration", 1)))
			message_changed.emit("Defense +%d for %d turns." % [_defense_buff, _defense_buff_turns])


func _consume_attack_buff() -> void:
	if _attack_buff_turns <= 0:
		return
	_attack_buff_turns -= 1
	if _attack_buff_turns == 0:
		_attack_buff = 0


func _consume_defense_buff() -> void:
	if _defense_buff_turns <= 0:
		return
	_defense_buff_turns -= 1
	if _defense_buff_turns == 0:
		_defense_buff = 0


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
			_end_battle(true, win_text, true)
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

	if enemy != null and enemy.survive_turns_to_win > 0 and turn_number >= enemy.survive_turns_to_win:
		var victory_text := enemy.survival_victory_text.strip_edges()
		if victory_text.is_empty():
			victory_text = "You survived %d turns. Victory!" % enemy.survive_turns_to_win
		_end_battle(true, victory_text)
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


func _action_restriction_message() -> String:
	var allowed := get_allowed_actions()
	if allowed.is_empty():
		return "You cannot do that right now."
	match allowed[0]:
		ACTION_ATTACK:
			return "You can only Attack this turn."
		ACTION_DEFEND:
			return "You can only Defend this turn."
		ACTION_ITEM:
			return "You can only use an Item this turn."
		ACTION_TALK:
			return "You can only Talk this turn."
		_:
			return "You cannot do that right now."


func _end_battle(victory: bool, custom_message: String = "", peaceful: bool = false) -> void:
	_battle_active = false
	_defending = false
	_phase_time_left = 0.0
	set_process(false)

	phase = Phase.VICTORY if victory else Phase.DEFEAT
	var save := _resolve_save_manager() if use_persistent_progress else null
	var victory_gold := 0
	if victory and save != null:
		if peaceful:
			# Talking the enemy down only rewards gold; it never increases stats.
			victory_gold = int(save.call("get_battle_victory_gold"))
			save.call("add_gold", victory_gold)
		else:
			var upgraded_stats: Vector3i = save.call(
				"reward_battle_victory",
				player_hp,
				player_max_hp,
				player_attack
			)
			player_hp = upgraded_stats.x
			player_max_hp = upgraded_stats.y
			player_attack = upgraded_stats.z
			victory_gold = int(save.call("get_battle_victory_gold"))
		player_stats_changed.emit(player_hp, player_max_hp, items)

	if not custom_message.is_empty():
		if peaceful and victory_gold > 0:
			custom_message += "  +%d gold." % victory_gold
		message_changed.emit(custom_message)
	elif victory and save != null:
		message_changed.emit("Victory! +5 Max HP, +1 Attack, +%d gold." % victory_gold)
	elif victory:
		message_changed.emit("Victory!")
	else:
		message_changed.emit("Defeat... You fall in battle.")

	phase_changed.emit(phase)
	input_locked_changed.emit(true)
	battle_ended.emit(victory)


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
