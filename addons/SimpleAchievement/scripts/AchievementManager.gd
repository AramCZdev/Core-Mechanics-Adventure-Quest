extends Node

const SAVE_PATH := "user://achievements.cfg"
const JSON_PATH := "res://addons/SimpleAchievement/achievements.json"
const POPUP_SCENE := "res://addons/SimpleAchievement/ui/AchievementPopup.tscn"

var _achievements: Dictionary = {}
var _save_data: Dictionary = {}

var _popup_queue: Array[String] = []
var _popup_showing: bool = false
var _popup: Control

signal achievement_unlocked(id: String)
signal achievement_progress(id: String, current: int, goal: int)

func _ready() -> void:
	_load_achievements()
	_load_save()

	await get_tree().process_frame

	_create_popup()


func _load_achievements() -> void:

	if !FileAccess.file_exists(JSON_PATH):
		push_warning("Achievements file missing")
		return

	var file := FileAccess.open(
		JSON_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error("Could not open achievement file")
		return

	var json := JSON.new()

	if json.parse(file.get_as_text()) != OK:
		push_error("Invalid achievement JSON")
		return

	if !(json.data is Array):
		push_error("Achievement JSON must be an array")
		return

	for entry in json.data:

		if !(entry is Dictionary):
			continue

		if !entry.has("id"):
			continue

		_achievements[entry["id"]] = entry


func _load_save() -> void:

	if !FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		return

	var data = file.get_var()

	if data is Dictionary:
		_save_data = data


func _save() -> void:

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return

	file.store_var(_save_data)


func unlockachievement(id: String) -> void:

	if !_achievements.has(id):
		return

	if isunlocked(id):
		return

	if !_save_data.has(id):
		_save_data[id] = {}

	var goal: int = int(
		_achievements[id].get(
			"goal",
			1
		)
	)

	_save_data[id]["progress"] = goal
	_save_data[id]["unlocked"] = true

	_save()

	achievement_unlocked.emit(id)

	_queue_popup(id)


func progressachievement(
	id: String,
	amount: int = 1
) -> void:

	if !_achievements.has(id):
		return

	if isunlocked(id):
		return

	if !_save_data.has(id):
		_save_data[id] = {}

	var goal: int = int(
		_achievements[id].get(
			"goal",
			1
		)
	)

	var current: int = getprogress(id)

	current += amount

	current = clamp(
		current,
		0,
		goal
	)

	_save_data[id]["progress"] = current

	achievement_progress.emit(
		id,
		current,
		goal
	)

	if current >= goal:

		_save_data[id]["unlocked"] = true

		_save()

		achievement_unlocked.emit(id)

		_queue_popup(id)

	else:

		_save()


func isunlocked(id: String) -> bool:

	return _save_data.get(
		id,
		{}
	).get(
		"unlocked",
		false
	)


func getprogress(id: String) -> int:

	return int(
		_save_data.get(
			id,
			{}
		).get(
			"progress",
			0
		)
	)


func getall() -> Dictionary:
	return _achievements


func getsavedata() -> Dictionary:
	return _save_data


func reset() -> void:

	_save_data.clear()

	_save()


func _create_popup() -> void:

	if !ResourceLoader.exists(POPUP_SCENE):
		push_error("Popup scene missing")
		return

	_popup = load(
		POPUP_SCENE
	).instantiate()

	_popup.process_mode = PROCESS_MODE_ALWAYS
	_popup.top_level = true

	get_tree().root.add_child(_popup)


func _queue_popup(id: String) -> void:

	_popup_queue.append(id)

	if !_popup_showing:
		_show_next_popup()


func _show_next_popup() -> void:

	if _popup_queue.is_empty():

		_popup_showing = false
		return

	if _popup == null:

		_popup_showing = false
		return

	_popup_showing = true

	var id: String = _popup_queue.pop_front()

	if !_achievements.has(id):

		_show_next_popup()
		return

	_popup.show_achievement(
		_achievements[id],
		_on_popup_done
	)


func _on_popup_done() -> void:

	_popup_showing = false

	call_deferred(
		"_show_next_popup"
	)
