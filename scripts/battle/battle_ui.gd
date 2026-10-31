extends Control
class_name BattleUI
## Presentation layer and input adapter for the battle system.
##
## BattleUI owns the action buttons and the two timing bars, forwards player
## decisions to BattleManager, and renders whatever the manager reports. It
## never calculates damage itself.

const DEFAULT_ENEMY: BattleEnemy = preload("res://battle/enemies/mossling/mossling.tres")

## Re-emitted when a battle starts or ends so gameplay code can listen to
## BattleUI without reaching into its child BattleManager.
signal battle_started(enemy: BattleEnemy)
signal battle_finished(victory: bool)
## Emitted after BattleUI hides itself following an automatic exit.
signal battle_exited(victory: bool)

@export var enemy: BattleEnemy
@export var auto_start: bool = true
## Freeze the rest of the scene tree while a battle is running so map movement
## and other gameplay input cannot leak through. BattleUI itself uses
## PROCESS_MODE_ALWAYS, so it keeps running while paused.
@export var pause_gameplay: bool = true
## Item support stays in BattleManager, but is hidden in the UI for now.
@export var items_enabled: bool = false
@export var battle_manager_path: NodePath = ^"BattleManager"

@export_group("End of battle")
## Hide the battle screen automatically after a victory.
@export var auto_exit_on_victory: bool = true
## Seconds the victory text stays visible before the battle screen closes.
@export_range(0.0, 10.0, 0.1, "suffix:s") var victory_exit_delay: float = 2.0

@onready var _manager: BattleManager = get_node_or_null(battle_manager_path) as BattleManager
@onready var _enemy_texture: TextureRect = %EnemyTexture
@onready var _enemy_placeholder: Label = %EnemyPlaceholder
@onready var _enemy_name_label: Label = %EnemyNameLabel
@onready var _enemy_hp_bar: ProgressBar = %EnemyHPBar
@onready var _enemy_hp_label: Label = %EnemyHPLabel
@onready var _message_label: Label = %MessageLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _timing_area: VBoxContainer = %TimingArea
@onready var _timing_prompt: Label = %TimingPrompt
@onready var _timing_holder: Control = %TimingHolder
@onready var _attack_timing: AttackTiming = %AttackTiming
@onready var _block_timing: BlockTiming = %BlockTiming
@onready var _player_hp_bar: ProgressBar = %PlayerHPBar
@onready var _player_hp_label: Label = %PlayerHPLabel
@onready var _items_label: Label = %ItemsLabel
@onready var _attack_button: Button = %AttackButton
@onready var _defend_button: Button = %DefendButton
@onready var _item_button: Button = %ItemButton
@onready var _talk_button: Button = %TalkButton
@onready var _actions: HBoxContainer = %Actions
@onready var _battle_over_panel: HBoxContainer = %BattleOverPanel
@onready var _battle_over_label: Label = %BattleOverLabel

var _paused_by_battle: bool = false
var _exit_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_exit_timer = Timer.new()
	_exit_timer.one_shot = true
	_exit_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_exit_timer.timeout.connect(_on_exit_timer_timeout)
	add_child(_exit_timer)

	if _manager == null:
		push_error("BattleUI: BattleManager not found at '%s'." % battle_manager_path)
		set_process_input(false)
		return

	if enemy == null:
		enemy = _manager.enemy
	if enemy == null:
		enemy = DEFAULT_ENEMY
	_manager.enemy = enemy

	_manager.battle_started.connect(_on_battle_started)
	_manager.battle_ended.connect(_on_battle_ended)
	_manager.phase_changed.connect(_on_phase_changed)
	_manager.input_locked_changed.connect(_on_input_locked_changed)
	_manager.message_changed.connect(_on_message_changed)
	_manager.player_stats_changed.connect(_on_player_stats_changed)
	_manager.enemy_stats_changed.connect(_on_enemy_stats_changed)
	_manager.attack_timing_started.connect(_on_attack_timing_started)
	_manager.block_timing_started.connect(_on_block_timing_started)
	_manager.battle_error.connect(_on_battle_error)

	_attack_button.pressed.connect(_on_attack_pressed)
	_defend_button.pressed.connect(_on_defend_pressed)
	_item_button.pressed.connect(_on_item_pressed)
	_talk_button.pressed.connect(_on_talk_pressed)

	_attack_timing.timing_finished.connect(_on_attack_timing_finished)
	_block_timing.timing_finished.connect(_on_block_timing_finished)

	_hide_timing_bars()
	_battle_over_panel.hide()

	if auto_start:
		_manager.start_battle(enemy)


## Starts (or restarts) a battle. Use this when auto_start is disabled, for
## example when BattleUI is instanced hidden and opened by a map trigger.
func begin_battle(new_enemy: BattleEnemy = null) -> bool:
	if _manager == null:
		return false
	if new_enemy != null:
		enemy = new_enemy
		_manager.enemy = new_enemy
	show()
	return _manager.start_battle(enemy)


func _unhandled_input(event: InputEvent) -> void:
	if _manager == null or not _manager.is_battle_active():
		return
	if _manager.phase != BattleManager.Phase.PLAYER_TURN:
		return

	if event.is_action_pressed("move_left"):
		_move_focus(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_move_focus(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_move_focus(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_move_focus(Vector2i.DOWN)
		get_viewport().set_input_as_handled()


func _on_battle_started(started_enemy: BattleEnemy) -> void:
	_exit_timer.stop()
	show()

	if pause_gameplay and not get_tree().paused:
		get_tree().paused = true
		_paused_by_battle = true

	_enemy_name_label.text = started_enemy.display_name
	_enemy_texture.texture = started_enemy.texture
	_enemy_texture.visible = started_enemy.texture != null
	_enemy_placeholder.text = started_enemy.display_name.to_upper()
	_enemy_placeholder.visible = started_enemy.texture == null
	_enemy_hp_bar.max_value = started_enemy.max_hp
	_enemy_hp_bar.value = started_enemy.max_hp
	_battle_over_panel.hide()
	_actions.show()
	_hide_timing_bars()
	_refresh_actions()
	_attack_button.call_deferred("grab_focus")
	battle_started.emit(started_enemy)


func _on_battle_ended(victory: bool) -> void:
	if _paused_by_battle:
		get_tree().paused = false
		_paused_by_battle = false

	_hide_timing_bars()
	_battle_over_label.text = "VICTORY!" if victory else "DEFEAT..."
	_battle_over_label.modulate = Color(0.98, 0.85, 0.35) if victory else Color(0.95, 0.45, 0.45)
	_battle_over_panel.show()
	_actions.hide()
	_refresh_actions()
	battle_finished.emit(victory)

	if victory and auto_exit_on_victory:
		_exit_timer.start(victory_exit_delay)


## Closes the battle screen immediately. Use this if you disabled automatic exit.
func exit_battle() -> void:
	if _manager == null or _manager.is_battle_active():
		return
	_exit_timer.stop()
	var victory: bool = _manager.phase == BattleManager.Phase.VICTORY
	hide()
	battle_exited.emit(victory)


func _on_exit_timer_timeout() -> void:
	if _manager == null or _manager.phase != BattleManager.Phase.VICTORY:
		return
	exit_battle()


func _on_phase_changed(new_phase: int) -> void:
	_turn_label.text = _phase_text(new_phase)
	_refresh_actions()
	if new_phase == BattleManager.Phase.PLAYER_TURN and not _battle_over_panel.visible:
		_attack_button.call_deferred("grab_focus")


func _on_input_locked_changed(_locked: bool) -> void:
	_refresh_actions()


func _on_message_changed(text: String) -> void:
	_message_label.text = text


func _on_player_stats_changed(hp: int, max_hp: int, items: int) -> void:
	_player_hp_bar.max_value = max_hp
	_player_hp_bar.value = hp
	_player_hp_label.text = "HP  %d / %d" % [hp, max_hp]
	_items_label.text = "Potions  %d" % items
	_refresh_actions()


func _on_enemy_stats_changed(hp: int, max_hp: int) -> void:
	_enemy_hp_bar.max_value = max_hp
	_enemy_hp_bar.value = hp
	_enemy_hp_label.text = "HP  %d / %d" % [hp, max_hp]


func _on_attack_timing_started() -> void:
	_show_timing_bar(
		_attack_timing,
		"Press Z, X, or Enter when the marker is in the zone!",
		_attack_timing.get_legend()
	)


func _on_block_timing_started() -> void:
	_show_timing_bar(
		_block_timing,
		"Press X, Z, or Enter when the marker is in the zone!",
		_block_timing.get_legend()
	)


func _on_attack_timing_finished(zone: String, multiplier: float) -> void:
	_hide_timing_bars()
	_manager.submit_attack(zone, multiplier)


func _on_block_timing_finished(zone: String, reduction: float) -> void:
	_hide_timing_bars()
	_manager.submit_block(zone, reduction)


func _on_attack_pressed() -> void:
	_request_action(BattleManager.ACTION_ATTACK)


func _on_defend_pressed() -> void:
	_request_action(BattleManager.ACTION_DEFEND)


func _on_item_pressed() -> void:
	_request_action(BattleManager.ACTION_ITEM)


func _on_talk_pressed() -> void:
	_request_action(BattleManager.ACTION_TALK)


func _on_battle_error(text: String) -> void:
	push_warning("BattleUI: %s" % text)


func _request_action(action: String) -> void:
	if _manager.select_action(action):
		_refresh_actions()


func _show_timing_bar(bar: TimingBar, prompt: String, legend: String) -> void:
	_attack_timing.stop()
	_block_timing.stop()
	_attack_timing.hide()
	_block_timing.hide()

	_timing_prompt.text = "%s\n%s" % [prompt, legend]
	_timing_area.show()
	_timing_holder.show()
	bar.show()
	bar.start()
	_refresh_actions()


func _hide_timing_bars() -> void:
	if _attack_timing != null:
		_attack_timing.stop()
		_attack_timing.hide()
	if _block_timing != null:
		_block_timing.stop()
		_block_timing.hide()
	if _timing_area != null:
		_timing_area.hide()


func _refresh_actions() -> void:
	if _manager == null:
		return

	var locked: bool = _manager.is_input_locked()
	_attack_button.disabled = locked
	_defend_button.disabled = locked
	_talk_button.disabled = locked
	_item_button.visible = items_enabled
	_items_label.visible = items_enabled
	_item_button.disabled = locked or not items_enabled or _manager.items <= 0
	_item_button.text = "Item (%d)" % _manager.items


func _move_focus(direction: Vector2i) -> void:
	var buttons: Array[Button] = [_attack_button, _defend_button]
	if items_enabled:
		buttons.append(_item_button)
	buttons.append(_talk_button)

	var focus_owner := get_viewport().gui_get_focus_owner()
	var index := buttons.find(focus_owner)
	if index < 0:
		index = 0

	if direction.x != 0:
		index = clampi(index + direction.x, 0, buttons.size() - 1)

	buttons[index].grab_focus()


func _phase_text(current_phase: int) -> String:
	match current_phase:
		BattleManager.Phase.PLAYER_TURN:
			if _manager != null and _manager.turn_number > 0:
				return "YOUR TURN  %d" % _manager.turn_number
			return "YOUR TURN"
		BattleManager.Phase.ATTACK_TIMING:
			return "ATTACK!"
		BattleManager.Phase.RESOLVE_PLAYER:
			return "PLAYER ACTION"
		BattleManager.Phase.ENEMY_WINDUP:
			return "ENEMY TURN"
		BattleManager.Phase.BLOCK_TIMING:
			return "BLOCK!"
		BattleManager.Phase.RESOLVE_ENEMY:
			return "ENEMY ACTION"
		BattleManager.Phase.VICTORY:
			return "VICTORY"
		BattleManager.Phase.DEFEAT:
			return "DEFEAT"
		_:
			return ""
