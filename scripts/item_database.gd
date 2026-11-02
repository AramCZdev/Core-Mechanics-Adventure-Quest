class_name ItemDatabase
extends RefCounted
## Shared item definitions used by inventories and shops.

const ITEMS := {
	"health_potion": {
		"name": "Health Potion",
		"description": "Restores 20 HP.",
		"type": "consumable",
		"effect": {"kind": "heal", "amount": 20},
		"price": 25
	},
	"greater_health_potion": {
		"name": "Greater Health Potion",
		"description": "Restores 50 HP.",
		"type": "consumable",
		"effect": {"kind": "heal", "amount": 50},
		"price": 60
	},
	"strength_potion": {
		"name": "Strength Potion",
		"description": "Increases attack power for a limited time.",
		"type": "consumable",
		"effect": {"kind": "temporary_attack_boost", "amount": 5, "duration": 3},
		"price": 45
	},
	"defense_potion": {
		"name": "Defense Potion",
		"description": "Reduces incoming damage for a limited time.",
		"type": "consumable",
		"effect": {"kind": "temporary_defense_boost", "amount": 5, "duration": 3},
		"price": 45
	}
}


static func has_item(item_id: String) -> bool:
	return ITEMS.has(item_id.strip_edges().to_lower())


static func get_item(item_id: String) -> Dictionary:
	var normalized_id := item_id.strip_edges().to_lower()
	if not ITEMS.has(normalized_id):
		return {}
	return ITEMS[normalized_id].duplicate(true)


static func get_all_items() -> Dictionary:
	return ITEMS.duplicate(true)
