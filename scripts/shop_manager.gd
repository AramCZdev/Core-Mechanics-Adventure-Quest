extends Node
## Data-driven shop API. Shops can be built in code at runtime or defined below.

const SHOPS := {
	"general_store": {
		"name": "General Store",
		"description": "Useful supplies for the road.",
		"offers": {
			"health_potion": 25,
			"greater_health_potion": 60,
			"strength_potion": 45,
			"defense_potion": 45
		}
	},
	"traveling_merchant": {
		"name": "Traveling Merchant",
		"description": "A wandering trader with stronger supplies.",
		"offers": {
			"greater_health_potion": 55,
			"strength_potion": 40,
			"defense_potion": 40
		}
	}
}

## Runtime-created shops are kept separately from the built-in examples.
var _custom_shops: Dictionary = {}


## Creates or replaces a custom shop.
## offers maps item IDs to prices, for example:
## {"health_potion": 10, "strength_potion": 75}
## Prices may be zero for free items, but cannot be negative.
func create_shop(
	shop_id: String,
	shop_name: String,
	offers: Dictionary,
	description: String = ""
) -> bool:
	var normalized_id := _normalize_shop_id(shop_id)
	var normalized_name := shop_name.strip_edges()
	if normalized_id.is_empty() or normalized_name.is_empty() or offers.is_empty():
		return false

	var validated_offers: Dictionary = {}
	for raw_item_id in offers:
		var item_id := str(raw_item_id).strip_edges().to_lower()
		var price_value = offers[raw_item_id]
		if not ItemDatabase.has_item(item_id):
			return false
		if typeof(price_value) != TYPE_INT or int(price_value) < 0:
			return false
		validated_offers[item_id] = int(price_value)

	_custom_shops[normalized_id] = {
		"name": normalized_name,
		"description": description.strip_edges(),
		"offers": validated_offers
	}
	return true


## Changes the price of an item already sold by a custom shop.
func set_shop_price(shop_id: String, item_id: String, price: int) -> bool:
	var normalized_shop_id := _normalize_shop_id(shop_id)
	var normalized_item_id := item_id.strip_edges().to_lower()
	if price < 0 or not _custom_shops.has(normalized_shop_id):
		return false

	var offers: Dictionary = _custom_shops[normalized_shop_id]["offers"]
	if not offers.has(normalized_item_id):
		return false
	offers[normalized_item_id] = price
	return true


## Adds an item to a custom shop or updates its price.
func add_shop_offer(shop_id: String, item_id: String, price: int) -> bool:
	var normalized_shop_id := _normalize_shop_id(shop_id)
	var normalized_item_id := item_id.strip_edges().to_lower()
	if price < 0 or not ItemDatabase.has_item(normalized_item_id):
		return false
	if not _custom_shops.has(normalized_shop_id):
		return false

	var offers: Dictionary = _custom_shops[normalized_shop_id]["offers"]
	offers[normalized_item_id] = price
	return true


## Removes an offer from a custom shop.
func remove_shop_offer(shop_id: String, item_id: String) -> bool:
	var normalized_shop_id := _normalize_shop_id(shop_id)
	var normalized_item_id := item_id.strip_edges().to_lower()
	if not _custom_shops.has(normalized_shop_id):
		return false

	var offers: Dictionary = _custom_shops[normalized_shop_id]["offers"]
	if not offers.has(normalized_item_id):
		return false
	offers.erase(normalized_item_id)
	return true


## Returns a copy of a shop definition, whether built-in or custom.
func get_shop(shop_id: String) -> Dictionary:
	var normalized_id := _normalize_shop_id(shop_id)
	if _custom_shops.has(normalized_id):
		return _custom_shops[normalized_id].duplicate(true)
	if SHOPS.has(normalized_id):
		return SHOPS[normalized_id].duplicate(true)
	return {}


## Returns item details and this shop's custom price for every offer.
func get_shop_inventory(shop_id: String) -> Array[Dictionary]:
	var shop := get_shop(shop_id)
	if shop.is_empty():
		return []

	var inventory: Array[Dictionary] = []
	var offers: Dictionary = shop.get("offers", {})
	for item_id in offers:
		var item := ItemDatabase.get_item(str(item_id))
		if item.is_empty():
			continue
		item["id"] = item_id
		item["price"] = int(offers[item_id])
		inventory.append(item)
	return inventory


## Buys an item and persists both the gold deduction and item quantity.
func buy_item(shop_id: String, item_id: String, quantity: int = 1) -> bool:
	var normalized_shop_id := _normalize_shop_id(shop_id)
	var normalized_item_id := item_id.strip_edges().to_lower()
	if quantity <= 0:
		return false

	var shop := get_shop(normalized_shop_id)
	if shop.is_empty():
		return false
	var offers: Dictionary = shop.get("offers", {})
	if not offers.has(normalized_item_id) or not ItemDatabase.has_item(normalized_item_id):
		return false

	var unit_price := int(offers[normalized_item_id])
	var total_price := unit_price * quantity
	if total_price > 0 and not SaveManager.spend_gold(total_price):
		return false

	if not SaveManager.add_item(normalized_item_id, quantity):
		if total_price > 0:
			SaveManager.add_gold(total_price)
		return false
	return true


func _normalize_shop_id(shop_id: String) -> String:
	var normalized_id := shop_id.strip_edges().to_lower()
	if normalized_id.is_empty() or normalized_id.length() > 64:
		return ""
	for index in range(normalized_id.length()):
		var character := normalized_id.substr(index, 1)
		if not (
			(character >= "a" and character <= "z")
			or (character >= "0" and character <= "9")
			or character == "_"
			or character == "-"
			or character == "."
		):
			return ""
	return normalized_id
