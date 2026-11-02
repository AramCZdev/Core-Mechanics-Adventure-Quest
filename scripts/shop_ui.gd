extends Control
## Reusable shop window. Set shop_id before showing this scene.

signal closed

@export var shop_id: String = "general_store"

var _title_label: Label
var _gold_label: Label
var _message_label: Label
var _offers_container: VBoxContainer


func _ready() -> void:
	_build_interface()
	_refresh()


func open_shop(new_shop_id: String) -> void:
	shop_id = new_shop_id
	visible = true
	if is_node_ready():
		_refresh()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 24)
	header.add_child(_title_label)

	_gold_label = Label.new()
	header.add_child(_gold_label)

	_offers_container = VBoxContainer.new()
	column.add_child(_offers_container)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message_label)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_pressed)
	column.add_child(close_button)


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
		var row := HBoxContainer.new()
		_offers_container.add_child(row)

		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)

		var item_name := Label.new()
		item_name.text = str(offer.get("name", offer.get("id", "Item")))
		details.add_child(item_name)

		var description := Label.new()
		description.text = str(offer.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(description)

		var item_id := str(offer.get("id", ""))
		var price := int(offer.get("price", 0))
		var buy_button := Button.new()
		buy_button.text = "Buy (%d gold)" % price
		buy_button.pressed.connect(_on_buy_pressed.bind(item_id))
		row.add_child(buy_button)


func _on_buy_pressed(item_id: String) -> void:
	if ShopManager.buy_item(shop_id, item_id):
		_message_label.text = "Purchase successful."
	else:
		_message_label.text = "Not enough gold or item unavailable."
	_refresh()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
