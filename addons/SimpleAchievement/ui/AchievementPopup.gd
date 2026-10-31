extends Control

@onready var panel: PanelContainer = $PanelContainer
@onready var icon: TextureRect = $PanelContainer/MarginContainer/HBox/Icon
@onready var title: Label = $PanelContainer/MarginContainer/HBox/VBox/Title
@onready var desc: Label = $PanelContainer/MarginContainer/HBox/VBox/Desc

const POPUP_TIME := 3.0
const ANIM_TIME := 0.25
const MARGIN := 16

var done_callback: Callable

func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = PROCESS_MODE_ALWAYS

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	visibility_changed.connect(_on_resize)
	get_viewport().size_changed.connect(_on_resize)

	hide()

func show_achievement(data: Dictionary, callback: Callable) -> void:
	done_callback = callback

	title.text = data.get("name", "Achievement")
	desc.text = data.get("description", "")

	var icon_path := data.get("icon", "")

	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		icon.texture = null

	await get_tree().process_frame

	var popup_size := panel.size

	if popup_size.x < 100:
		popup_size = Vector2(300,72)

	var target := _get_target_pos(popup_size)

	panel.position = Vector2(
		-popup_size.x - 20,
		target.y
	)

	show()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		panel,
		"position",
		target,
		ANIM_TIME
	)

	await get_tree().create_timer(POPUP_TIME).timeout

	tween = create_tween()

	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)

	tween.tween_property(
		panel,
		"position",
		Vector2(
			-popup_size.x - 20,
			target.y
		),
		ANIM_TIME
	)

	await tween.finished

	hide()

	if done_callback.is_valid():
		done_callback.call()

func _get_target_pos(size: Vector2) -> Vector2:
	var viewport := get_viewport_rect().size

	return Vector2(
		clamp(
			MARGIN,
			0,
			viewport.x - size.x
		),
		clamp(
			viewport.y - size.y - MARGIN,
			0,
			viewport.y - size.y
		)
	)

func _on_resize():
	if visible:
		panel.position = _get_target_pos(panel.size)
