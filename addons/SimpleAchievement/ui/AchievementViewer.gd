extends Control

@onready var list: VBoxContainer = $VBoxContainer/ScrollContainer/List

func _ready() -> void:
	_populate()

func _populate() -> void:
	for child in list.get_children():
		child.queue_free()

	var all: Dictionary = AchievementManager.getall()
	var save: Dictionary = AchievementManager.getsavedata()

	for id in all:
		var data: Dictionary = all[id]
		var entry := _make_entry(id, data, save)
		list.add_child(entry)

func _make_entry(id: String, data: Dictionary, save: Dictionary) -> PanelContainer:
	var unlocked: bool = save.get(id, {}).get("unlocked", false)
	var progress: int = save.get(id, {}).get("progress", 0)
	var goal: int = data.get("goal", 1)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = data.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	if not unlocked:
		icon.modulate = Color(0.3, 0.3, 0.3, 1.0)
	hbox.add_child(icon)

	# Text
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.text = data.get("name", id)
	name_label.add_theme_font_size_override("font_size", 13)
	if not unlocked:
		name_label.modulate = Color(0.6, 0.6, 0.6, 1.0)
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.modulate = Color(0.75, 0.75, 0.75, 1.0)
	vbox.add_child(desc_label)

	# Progress bar for tracked achievements
	if goal > 1:
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = goal
		bar.value = progress
		bar.custom_minimum_size = Vector2(0, 14)
		vbox.add_child(bar)
		var bar_label := Label.new()
		bar_label.text = "%d / %d" % [progress, goal]
		bar_label.add_theme_font_size_override("font_size", 9)
		vbox.add_child(bar_label)

	# Status
	var status := Label.new()
	status.text = "✔ Unlocked" if unlocked else "Locked"
	status.add_theme_font_size_override("font_size", 10)
	status.modulate = Color(0.2, 1.0, 0.2, 1.0) if unlocked else Color(0.6, 0.6, 0.6, 1.0)
	status.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(status)

	return panel
