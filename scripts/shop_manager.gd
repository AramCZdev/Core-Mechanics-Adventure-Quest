extends Node
## Data-driven shop API. UI scenes can read offers and call buy_item().

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


func get_shop(shop_id: String) -> Dictionary:
	var normalized_id := shop_id.strip_edges().to_lower()
	if not SHOPS.has(normalized_id):
		return {}
	return SHOPS[normalized_id].duplicate(true)


## Returns item details and this shop's price for every available offer.
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
## Returns false for unknown shops/items, unavailable offers, invalid quantities,
## insufficient gold, or a save failure.
func buy_item(shop_id: String, item_id: String, quantity: int = 1) -> bool:
	var normalized_shop_id := shop_id.strip_edges().to_lower()
	var normalized_item_id := item_id.strip_edges().to_lower()
	if quantity <= 0 or not SHOPS.has(normalized_shop_id):
		return false

	var offers: Dictionary = SHOPS[normalized_shop_id].get("offers", {})
	if not offers.has(normalized_item_id) or not ItemDatabase.has_item(normalized_item_id):
		return false

	var total_price := int(offers[normalized_item_id]) * quantity
	if total_price <= 0 or not SaveManager.spend_gold(total_price):
		return false

	if not SaveManager.add_item(normalized_item_id, quantity):
		SaveManager.add_gold(total_price)
		return false
	return true
