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
## Emitted once the battle is completely over. On victory this waits for the
## victory presentation (the win cutscene) to finish before firing.
signal battle_finished(victory: bool)
## Emitted after BattleUI hides itself following an automatic exit.
signal battle_exited(victory: bool)

@export var enemy: BattleEnemy
@export var auto_start: bool = true
## Freeze the rest of the scene tree while a battle is running so map movement
## and other gameplay input cannot leak through. BattleUI itself uses
## PROCESS_MODE_ALWAYS, so it keeps running while paused.
@export var pause_gameplay: bool = true
## Show the Item action. Item counts come from BattleManager (normally the
## persistent potion inventory).
@export var items_enabled: bool = false
@export var battle_manager_path: NodePath = ^"BattleManager"

@export_group("End of battle")
## Hide the battle screen automatically after a victory.
@export var auto_exit_on_victory: bool = true
## Seconds the victory presentation (win cutscene) stays on screen before the
## battle ends, resumes gameplay, and emits battle_finished.
@export_range(0.0, 10.0, 0.1, "suffix:s") var victory_exit_delay: float = 3.0
## Hide the battle screen automatically after a defeat so the player's death
## animation is visible in the world.
@export var auto_exit_on_defeat: bool = true
## Seconds the defeat result stays on screen before closing the battle and
## playing the player's death animation.
@export_range(0.0, 10.0, 0.1, "suffix:s") var defeat_exit_delay: float = 1.5

@onready var _manager: BattleManager = get_node_or_null(battle_manager_path) as BattleManager
@onready var _enemy_texture: TextureRect = %EnemyTexture
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
var _battle_finished_emitted: bool = false
var _exit_timer: Timer
var _item_panel: VBoxContainer
var _item_menu_open: bool = false
var _item_buttons: Array[Button] = []


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

	_build_item_panel()
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
	if _item_menu_open:
		if event.is_action_pressed("ui_cancel"):
			_hide_item_menu()
			_item_button.grab_focus()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("move_up"):
			_move_focus(Vector2i.UP)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("move_down"):
			_move_focus(Vector2i.DOWN)
			get_viewport().set_input_as_handled()
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
	_battle_finished_emitted = false
	show()

	if pause_gameplay and not get_tree().paused:
		get_tree().paused = true
		_paused_by_battle = true

	_enemy_name_label.text = started_enemy.display_name
	_enemy_texture.texture = started_enemy.texture
	_enemy_texture.visible = started_enemy.texture != null
	_enemy_hp_bar.max_value = started_enemy.max_hp
	_enemy_hp_bar.value = started_enemy.max_hp
	_battle_over_panel.hide()
	_hide_item_menu()
	_actions.show()
	_hide_timing_bars()
	_refresh_actions()
	_focus_first_allowed_action()
	battle_started.emit(started_enemy)


func _on_battle_ended(victory: bool) -> void:
	_hide_timing_bars()
	_hide_item_menu()
	_battle_over_label.text = "VICTORY!" if victory else "DEFEAT..."
	_battle_over_label.modulate = Color(0.98, 0.85, 0.35) if victory else Color(0.95, 0.45, 0.45)
	_battle_over_panel.show()
	_actions.hide()
	_refresh_actions()

	if victory and auto_exit_on_victory:
		# Keep everything frozen while the victory presentation plays. The
		# battle only finishes once the win cutscene timer runs out.
		_exit_timer.start(victory_exit_delay)
	elif not victory and auto_exit_on_defeat:
		# Show the defeat result briefly, then reveal the world so the player
		# can play the death animation.
		_exit_timer.start(defeat_exit_delay)
	else:
		_finish_battle(victory)


## Closes the battle screen immediately. Use this if you disabled automatic exit.
func exit_battle() -> void:
	if _manager == null or _manager.is_battle_active():
		return
	_exit_timer.stop()
	var victory: bool = _manager.phase == BattleManager.Phase.VICTORY
	_resume_gameplay()
	hide()
	if not victory:
		_play_player_death()
	_finish_battle(victory)
	battle_exited.emit(victory)


func _finish_battle(victory: bool) -> void:
	_resume_gameplay()
	if _battle_finished_emitted:
		return
	_battle_finished_emitted = true
	battle_finished.emit(victory)


func _resume_gameplay() -> void:
	if _paused_by_battle:
		get_tree().paused = false
		_paused_by_battle = false


func _on_exit_timer_timeout() -> void:
	if _manager == null:
		return
	if _manager.phase != BattleManager.Phase.VICTORY and _manager.phase != BattleManager.Phase.DEFEAT:
		return
	exit_battle()


## Finds the world player after a lost battle and lets it play its death
## animation. Players expose play_death() and join the "player" group.
func _play_player_death() -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if player.has_method("play_death"):
			player.call("play_death")
			return


func _on_phase_changed(new_phase: int) -> void:
	_turn_label.text = _phase_text(new_phase)
	if new_phase != BattleManager.Phase.PLAYER_TURN and _item_menu_open:
		_hide_item_menu()
	_refresh_actions()
	if new_phase == BattleManager.Phase.PLAYER_TURN and not _battle_over_panel.visible:
		_focus_first_allowed_action()


func _on_input_locked_changed(_locked: bool) -> void:
	_refresh_actions()


func _on_message_changed(text: String) -> void:
	_message_label.text = text


func _on_player_stats_changed(hp: int, max_hp: int, items: int) -> void:
	_player_hp_bar.max_value = max_hp
	_player_hp_bar.value = hp
	_player_hp_label.text = "HP  %d / %d" % [hp, max_hp]
	_items_label.text = "Items  %d" % items
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
	if _manager == null or not _manager.is_battle_active():
		return
	if _manager.phase != BattleManager.Phase.PLAYER_TURN:
		return
	if _manager.get_usable_items().is_empty():
		_on_message_changed("You have no items left!")
		return
	_show_item_menu()


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
	var allowed: PackedStringArray = _manager.get_allowed_actions()
	var restricted: bool = not allowed.is_empty()
	_attack_button.disabled = locked or (restricted and not allowed.has(BattleManager.ACTION_ATTACK))
	_defend_button.disabled = locked or (restricted and not allowed.has(BattleManager.ACTION_DEFEND))
	_talk_button.disabled = locked or (restricted and not allowed.has(BattleManager.ACTION_TALK))
	_item_button.visible = items_enabled
	_items_label.visible = items_enabled
	_item_button.disabled = locked or not items_enabled or _manager.items <= 0 or (
		restricted and not allowed.has(BattleManager.ACTION_ITEM)
	)
	_item_button.text = "Item (%d)" % _manager.items


func _build_item_panel() -> void:
	if _item_panel != null:
		return

	var wrapper := PanelContainer.new()
	wrapper.name = "ItemMenu"
	wrapper.visible = false
	wrapper.add_theme_stylebox_override("panel", _item_panel_style())

	var parent := _actions.get_parent()
	parent.add_child(wrapper)
	parent.move_child(wrapper, _actions.get_index())

	_item_panel = VBoxContainer.new()
	_item_panel.add_theme_constant_override("separation", 6)
	wrapper.add_child(_item_panel)


func _show_item_menu() -> void:
	if _item_panel == null:
		_build_item_panel()

	var usable := _manager.get_usable_items()
	if usable.is_empty():
		_on_message_changed("You have no items left!")
		return

	for child in _item_panel.get_children():
		_item_panel.remove_child(child)
		child.queue_free()
	_item_buttons.clear()

	var title := Label.new()
	title.text = "Use which item?"
	title.add_theme_color_override("font_color", Color(0.23, 0.12, 0.06, 1))
	title.add_theme_font_size_override("font_size", 18)
	_item_panel.add_child(title)

	for entry in usable:
		var button := Button.new()
		button.text = "%s  x%d\n%s" % [
			str(entry.get("name", "Item")),
			int(entry.get("count", 1)),
			str(entry.get("description", "")),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 48)
		_copy_action_button_style(button)
		button.pressed.connect(_on_item_chosen.bind(str(entry.get("id", ""))))
		_item_panel.add_child(button)
		_item_buttons.append(button)

	var cancel := Button.new()
	cancel.text = "Cancel  (Esc)"
	cancel.custom_minimum_size = Vector2(0, 40)
	_copy_action_button_style(cancel)
	cancel.pressed.connect(_hide_item_menu)
	_item_panel.add_child(cancel)
	_item_buttons.append(cancel)

	_item_menu_open = true
	_item_panel.get_parent().show()
	_actions.hide()
	if not _item_buttons.is_empty():
		_item_buttons[0].call_deferred("grab_focus")


func _hide_item_menu() -> void:
	if _item_panel == null:
		return
	_item_menu_open = false
	_item_panel.get_parent().hide()
	if _manager != null and _manager.is_battle_active():
		_actions.show()


func _on_item_chosen(item_id: String) -> void:
	_hide_item_menu()
	if not _manager.use_item(item_id):
		if _manager.phase == BattleManager.Phase.PLAYER_TURN:
			_item_button.grab_focus()
	_refresh_actions()


func _copy_action_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color(1, 0.91, 0.69, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 0.91, 0.69, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 0.91, 0.69, 1))
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed"]:
		var style := _attack_button.get_theme_stylebox(state)
		if style != null:
			button.add_theme_stylebox_override(state, style)


func _item_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.83, 0.74, 0.56, 1)
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.border_color = Color(0.29, 0.17, 0.08, 1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	return style


func _move_focus(direction: Vector2i) -> void:
	if _item_menu_open:
		if _item_buttons.is_empty():
			return
		var current := get_viewport().gui_get_focus_owner()
		var item_index := _item_buttons.find(current)
		if item_index < 0:
			item_index = 0
		if direction.y != 0:
			item_index = clampi(item_index + direction.y, 0, _item_buttons.size() - 1)
		_item_buttons[item_index].grab_focus()
		return

	var buttons := _action_buttons()
	if buttons.is_empty():
		return

	var focus_owner := get_viewport().gui_get_focus_owner()
	var index := buttons.find(focus_owner)
	if index < 0:
		index = 0

	if direction.x != 0:
		index = clampi(index + direction.x, 0, buttons.size() - 1)

	buttons[index].grab_focus()


func _action_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for button in [_attack_button, _defend_button, _item_button, _talk_button]:
		if button.visible and not button.disabled:
			buttons.append(button)
	return buttons


func _focus_first_allowed_action() -> void:
	var buttons := _action_buttons()
	if not buttons.is_empty():
		buttons[0].call_deferred("grab_focus")


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
