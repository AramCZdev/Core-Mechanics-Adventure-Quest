extends Node2D

const MONKEY_INTRO_DIALOGUE := "res://dialogue/monke.json"
const MONKEY_FIGHT_DIALOGUE := "res://dialogue/monkefight.json"
const MONKEY_AFTERFIGHT_DIALOGUE := "res://dialogue/monkeafterfight.json"
const MONKEY_ENEMY: BattleEnemy = preload("res://battle/enemies/monkey/monkey.tres")

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var battle_ui: BattleUI = $CanvasLayer/BattleUI

var _monkey_fight_started: bool = false
var _monkey_battle_started: bool = false
var _monkey_battle_won: bool = false


func _ready() -> void:
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	battle_ui.battle_finished.connect(_on_battle_finished)


func _on_start_cutscene_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	if DialogueManager.is_active:
		return
	DialogueManager.start_dialogue(MONKEY_INTRO_DIALOGUE)


func _on_dialogue_finished(file_path: String, _last_node_id: String) -> void:
	if file_path == MONKEY_FIGHT_DIALOGUE:
		_start_monkey_battle()
		return

	if file_path != MONKEY_INTRO_DIALOGUE:
		return
	animation_player.play("monkey_jumps")
	var intro_trigger := get_node_or_null("Start Cutscene")
	if intro_trigger != null:
		intro_trigger.queue_free()
	
	if file_path != MONKEY_AFTERFIGHT_DIALOGUE:
		return
	animation_player.play("after_battle")


func _on_start_cutscene_2_body_entered(body: Node2D) -> void:
	if _monkey_fight_started or not (body is CharacterBody2D):
		return
	if DialogueManager.is_active:
		return

	_monkey_fight_started = true
	if not DialogueManager.start_dialogue(MONKEY_FIGHT_DIALOGUE):
		_monkey_fight_started = false


func _start_monkey_battle() -> void:
	_monkey_battle_started = true
	if not battle_ui.begin_battle(MONKEY_ENEMY):
		_monkey_battle_started = false
		_monkey_fight_started = false


func _on_battle_finished(victory: bool) -> void:
	if not _monkey_battle_started:
		return
	_monkey_battle_started = false
	_monkey_fight_started = false

	if victory:
		_monkey_battle_won = true
		var trigger := get_node_or_null("Start Cutscene2")
		if trigger != null:
			trigger.queue_free()
		DialogueManager.start_dialogue(MONKEY_AFTERFIGHT_DIALOGUE)


func _on_button_body_entered(_body: Node2D) -> void:
	$"Wall".queue_free()
	$"Button/ColorRect".color = 850000


func _on_theend_body_entered(_body: Node2D) -> void:
	pass # Replace with function body.
