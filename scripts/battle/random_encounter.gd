extends Node
class_name RandomEncounter
## Undertale-style random encounters triggered by walking.
##
## Add this node to a room (with a BattleUI in the same scene) to let enemies
## ambush the player after they have walked a certain distance. Scenes without
## this node never trigger random encounters, and `enabled` can be unchecked to
## turn them off in a scene that has one.
##
## Only the enemies assigned to `enemies` can appear. When the array is left
## empty, the default forest pool (Mossling) is used.

const DEFAULT_FOREST_ENEMY := "res://battle/enemies/mossling/mossling.tres"

@export var enabled: bool = true

@export_group("Enemy pool")
## Enemies that can appear in this room. Leave empty to use the default forest
## enemy (Mossling only). Add other forest-themed BattleEnemy resources here.
@export var enemies: Array[BattleEnemy] = []

@export_group("Frequency")
## Minimum distance the player must walk before an encounter can trigger.
@export_range(0.0, 50000.0, 10.0, "suffix:px") var min_distance: float = 2000.0
## Maximum distance the player must walk before an encounter can trigger.
## A random value between min_distance and max_distance is rolled each time.
@export_range(0.0, 50000.0, 10.0, "suffix:px") var max_distance: float = 4000.0
## Chance an encounter actually starts once the distance threshold is reached.
## Lower this to make encounters rarer. 0 disables them entirely.
@export_range(0.0, 1.0, 0.01) var encounter_chance: float = 0.35
## Extra distance added after a battle so the player gets a short breather.
@export_range(0.0, 50000.0, 10.0, "suffix:px") var post_battle_distance: float = 800.0

@export_group("Warning")
## Optional node shown above the player right before a battle starts.
@export var huh_path: NodePath = ^"../Player/Huh"
## Seconds the warning node stays visible before the battle begins.
@export_range(0.0, 5.0, 0.05, "suffix:s") var huh_display_time: float = 0.5

@export_group("References")
## The player whose movement is measured.
@export var player_path: NodePath = ^"../Player"
## The BattleUI used to start encounters.
@export var battle_ui_path: NodePath = ^"../CanvasLayer/BattleUI"

var _player: Node2D
var _battle_ui: BattleUI
var _huh: CanvasItem
var _dialogue_manager: Node
var _last_position: Vector2
var _distance_since_check: float = 0.0
var _next_check_distance: float = 0.0
var _battle_in_progress: bool = false
var _fallback_enemies: Array[BattleEnemy] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_dialogue_manager = get_node_or_null("/root/DialogueManager")

	_player = get_node_or_null(player_path) as Node2D
	if _player == null:
		push_warning("RandomEncounter: player not found at '%s'." % player_path)
		set_physics_process(false)
		return

	_battle_ui = get_node_or_null(battle_ui_path) as BattleUI
	if _battle_ui == null:
		push_warning("RandomEncounter: BattleUI not found at '%s'." % battle_ui_path)
		set_physics_process(false)
		return

	_huh = get_node_or_null(huh_path) as CanvasItem
	_battle_ui.battle_finished.connect(_on_battle_finished)
	if _player.has_signal("respawned"):
		_player.connect("respawned", _on_player_respawned)
	_last_position = _player.global_position
	_roll_next_check()


func _physics_process(_delta: float) -> void:
	if not enabled or _battle_in_progress:
		return
	if get_tree().paused or _battle_ui.visible:
		return
	if _dialogue_manager != null and bool(_dialogue_manager.get("is_active")):
		return

	var current_position := _player.global_position
	var distance_walked := current_position.distance_to(_last_position)
	_last_position = current_position
	if distance_walked <= 0.0:
		return

	_distance_since_check += distance_walked
	if _distance_since_check < _next_check_distance:
		return

	_distance_since_check = 0.0
	if _rng.randf() >= encounter_chance:
		_roll_next_check()
		return

	_start_encounter()


func _start_encounter() -> void:
	var pool := _get_enemy_pool()
	if pool.is_empty():
		push_warning("RandomEncounter: no enemies configured.")
		return

	var chosen_enemy: BattleEnemy = pool[_rng.randi_range(0, pool.size() - 1)]
	var player_audio := get_parent().get_node_or_null("Player/AudioStreamPlayer2D") as AudioStreamPlayer2D
	if player_audio != null:
		player_audio.stop()
	await _play_encounter_warning()
	if not is_inside_tree():
		return
	if not _battle_ui.begin_battle(chosen_enemy):
		_battle_in_progress = false
	else:
		var player := _battle_ui.get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
		if player != null:
			player.play()


func _play_encounter_warning() -> void:
	if _huh == null:
		return
	_huh.show()
	if huh_display_time > 0.0:
		await get_tree().create_timer(huh_display_time).timeout
	if is_instance_valid(_huh):
		_huh.hide()


func _get_enemy_pool() -> Array[BattleEnemy]:
	if not enemies.is_empty():
		var configured: Array[BattleEnemy] = []
		for enemy in enemies:
			if enemy != null:
				configured.append(enemy)
		return configured

	if _fallback_enemies.is_empty():
		var default_enemy := load(DEFAULT_FOREST_ENEMY) as BattleEnemy
		if default_enemy != null:
			_fallback_enemies.append(default_enemy)
	return _fallback_enemies


func _roll_next_check(extra_distance: float = 0.0) -> void:
	var lowest := maxf(min_distance, 1.0)
	var highest := maxf(max_distance, lowest)
	_next_check_distance = _rng.randf_range(lowest, highest) + maxf(extra_distance, 0.0)
	_distance_since_check = 0.0


func _on_battle_finished(_victory: bool) -> void:
	_battle_in_progress = false
	_last_position = _player.global_position
	_roll_next_check(post_battle_distance)
	var player_audio := get_parent().get_node_or_null("Player/AudioStreamPlayer2D") as AudioStreamPlayer2D
	if player_audio != null:
		player_audio.play()


## Respawn can teleport the player a long way from where the battle ended.
## Treat that jump as a fresh start instead of walked distance.
func _on_player_respawned() -> void:
	_battle_in_progress = false
	_last_position = _player.global_position
	_roll_next_check(post_battle_distance)
