extends Control
## Reusable shop window styled to match the battle UI.
## Set shop_id before showing this scene.

signal closed

@export var shop_id: String = "general_store"
## Pause world gameplay while the shop is open.
@export var pause_gameplay: bool = true

const PANEL_BG := Color(0.83, 0.74, 0.56, 1)
const PANEL_BORDER := Color(0.29, 0.17, 0.08, 1)
const ROW_BG := Color(0.74, 0.65, 0.47, 1)
const TEXT_COLOR := Color(0.28, 0.17, 0.09, 1)
const TEXT_SOFT := Color(0.48, 0.29, 0.12, 1)
const BUTTON_BG := Color(0.31, 0.19, 0.1, 1)
const BUTTON_BORDER := Color(0.91, 0.72, 0.34, 1)
const BUTTON_TEXT := Color(1, 0.91, 0.69, 1)
const BACKDROP := Color(0.02, 0.02, 0.04, 0.82)

var _title_label: Label
var _gold_label: Label
var _message_label: Label
var _offers_container: VBoxContainer
var _paused_by_shop: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_refresh()


func open_shop(new_shop_id: String) -> void:
	shop_id = new_shop_id
	visible = true
	if pause_gameplay and not get_tree().paused:
		get_tree().paused = true
		_paused_by_shop = true
	if is_node_ready():
		_refresh()


func close_shop() -> void:
	if not visible:
		return
	visible = false
	_restore_gameplay()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)

	_title_label = _make_label(26, TEXT_COLOR)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_gold_label = _make_label(18, TEXT_SOFT)
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_gold_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(PANEL_BORDER, 0.55)
	column.add_child(divider)

	_offers_container = VBoxContainer.new()
	_offers_container.add_theme_constant_override("separation", 8)
	column.add_child(_offers_container)

	_message_label = _make_label(14, TEXT_COLOR)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message_label)

	var close_button := Button.new()
	close_button.text = "Close"
	_style_button(close_button)
	close_button.pressed.connect(close_shop)
	column.add_child(close_button)

	var hint := _make_label(12, TEXT_SOFT)
	hint.text = "Press Escape to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func _refresh() -> void:
	if _offers_container == null:
		return

	var shop := ShopManager.get_shop(shop_id)
	if shop.is_empty():
		_title_label.text = "Shop unavailable"
		_message_label.text = "This shop does not exist."
	else:
		_title_label.text = str(shop.get("name", "Shop"))
		_message_label.text = str(shop.get("description", ""))

	_gold_label.text = "Gold: %d" % SaveManager.get_gold()
	for child in _offers_container.get_children():
		_offers_container.remove_child(child)
		child.queue_free()

	if shop.is_empty():
		return

	for offer in ShopManager.get_shop_inventory(shop_id):
		_build_offer_row(offer)


func _build_offer_row(offer: Dictionary) -> void:
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _row_style())
	_offers_container.add_child(row_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row_panel.add_child(row)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)

	var item_id := str(offer.get("id", ""))
	var item_name := _make_label(18, TEXT_COLOR)
	item_name.text = str(offer.get("name", item_id))
	details.add_child(item_name)

	var description := _make_label(13, TEXT_SOFT)
	description.text = str(offer.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(description)

	var owned := _make_label(12, TEXT_SOFT)
	owned.text = "Owned: %d" % SaveManager.get_item_count(item_id)
	details.add_child(owned)

	var price := int(offer.get("price", 0))
	var buy_button := Button.new()
	buy_button.text = "Buy\n%d gold" % price
	buy_button.custom_minimum_size = Vector2(150, 0)
	buy_button.disabled = price > SaveManager.get_gold()
	_style_button(buy_button)
	buy_button.pressed.connect(_on_buy_pressed.bind(item_id))
	row.add_child(buy_button)


func _on_buy_pressed(item_id: String) -> void:
	if ShopManager.buy_item(shop_id, item_id):
		_message_label.text = "Purchase successful."
	else:
		_message_label.text = "Not enough gold or item unavailable."
	_refresh()


func _restore_gameplay() -> void:
	if _paused_by_shop:
		get_tree().paused = false
		_paused_by_shop = false


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.border_color = PANEL_BORDER
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 18
	style.content_margin_top = 14
	style.content_margin_right = 18
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	return style


func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(PANEL_BORDER, 0.55)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", BUTTON_TEXT)
	button.add_theme_color_override("font_hover_color", BUTTON_TEXT)
	button.add_theme_color_override("font_pressed_color", BUTTON_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(BUTTON_TEXT, 0.4))
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _button_style(BUTTON_BG, BUTTON_BORDER))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.49, 0.3, 0.12), Color(1, 0.86, 0.48)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.2, 0.12, 0.07), Color(0.78, 0.56, 0.25)))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.32, 0.26, 0.2), Color(0.45, 0.35, 0.25)))


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 10
	style.content_margin_top = 6
	style.content_margin_right = 10
	style.content_margin_bottom = 6
	return style
