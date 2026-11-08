extends BattleUI
## Battle UI for the Broken TV fight.
##
## Keeps all fourth-wall-breaking behavior isolated from the shared BattleUI so
## other fights (Mossling, Dummy, etc.) are completely unaffected:
##   * Talk is renamed to Cry and always replies "You tried to cry but you have no eyes."
##   * Player HP is locked to 20 for the duration of the fight.
##   * CRT-style glitching (backdrop flash, message flicker, enemy artwork jitter).
##   * Triangle-marked squares on the attack bar multiply damage by 1.5x.

var _glitch_active: bool = false
var _glitch_timer: float = 0.0
var _glitch_interval: float = 0.05
var _glitch_backdrop_color: Color = Color.WHITE
var _glitch_message_modulate: Color = Color.WHITE
var _enemy_texture_base_position: Vector2 = Vector2.ZERO

@onready var _backdrop: ColorRect = %Backdrop


## Renames the Talk button to "Cry", locks player HP to 20, and starts glitching.
func _on_battle_started(started_enemy: BattleEnemy) -> void:
	super._on_battle_started(started_enemy)

	var talk_label: String = started_enemy.talk_action_label
	_talk_button.text = talk_label if not talk_label.is_empty() else "Talk"

	if started_enemy.is_glitching:
		_activate_glitch()

	# BattleManager emits player_stats_changed right after battle_started, which
	# would overwrite any override we apply here. Defer so we win the race.
	if started_enemy.player_hp_override > 0:
		call_deferred("_apply_hp_override", started_enemy.player_hp_override)


## Applies the enemy's player_hp_override after the manager's own stat emission.
func _apply_hp_override(hp_override: int) -> void:
	if _manager == null:
		return
	_manager.player_max_hp = hp_override
	_manager.player_hp = hp_override
	_manager.player_stats_changed.emit(_manager.player_hp, _manager.player_max_hp, _manager.items)


## Enables triangle-damage squares on the attack bar for the Broken TV fight.
func _on_attack_timing_started() -> void:
	if _manager.enemy != null and _manager.enemy.triangle_squares_enabled:
		_attack_timing.triangle_squares_enabled = true
		_attack_timing.triangle_multiplier = _manager.enemy.triangle_multiplier

	super._on_attack_timing_started()


func _on_block_timing_started() -> void:
	if _manager.enemy != null and _manager.enemy.triangle_squares_enabled:
		_block_timing.triangle_squares_enabled = true
		_block_timing.triangle_multiplier = 1.2

	super._on_block_timing_started()

func _on_attack_timing_finished(zone: String, multiplier: float) -> void:
	_hide_timing_bars()
	_manager.submit_attack(zone, multiplier)


## Stops glitching when the battle ends so other fights are unaffected.
func _on_battle_ended(victory: bool) -> void:
	$AudioStreamPlayer2D.play()
	super._on_battle_ended(victory)
	if _glitch_active:
		_deactivate_glitch()


## Turns on CRT-style static jitter for the battle UI while the enemy is glitching.
func _activate_glitch() -> void:
	_glitch_active = true
	_glitch_timer = 0.0
	if _backdrop != null:
		_glitch_backdrop_color = _backdrop.color
	if _message_label != null:
		_glitch_message_modulate = _message_label.self_modulate
	if _enemy_texture != null:
		_enemy_texture_base_position = _enemy_texture.position
	set_process(true)


## Stops the glitch jitter and restores the UI to its resting state.
func _deactivate_glitch() -> void:
	_glitch_active = false
	set_process(false)
	if _backdrop != null:
		_backdrop.color = _glitch_backdrop_color
	if _message_label != null:
		_message_label.self_modulate = _glitch_message_modulate
	if _enemy_texture != null:
		_enemy_texture.position = _enemy_texture_base_position


func _process(delta: float) -> void:
	if not _glitch_active:
		return
	_glitch_timer += delta
	if _glitch_timer < _glitch_interval:
		return
	_glitch_timer = 0.0

	# Flash the full-screen backdrop like signal static.
	if _backdrop != null:
		_backdrop.color = Color(1, 1, 1, 1) if randf() < 0.45 else _glitch_backdrop_color

	# Flicker the message text between a bad-signal tint and its normal color.
	if _message_label != null:
		_message_label.self_modulate = Color(1, 0.15, 0.15, 1) if randf() < 0.4 else _glitch_message_modulate

	# Jitter the enemy artwork within its free-positioned stage.
	if _enemy_texture != null:
		_enemy_texture.position = _enemy_texture_base_position + Vector2(
			randi_range(-10, 10),
			randi_range(-8, 8),
		)
