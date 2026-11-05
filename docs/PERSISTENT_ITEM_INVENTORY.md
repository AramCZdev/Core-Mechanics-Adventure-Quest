# Persistent Inventory, Items, Currency, and Shops

The project autoloads `SaveManager` and `ShopManager`. Item definitions live in `scripts/item_database.gd`. All persistent data uses the existing `user://savegame.cfg` file.

## Available items

| ID | Item | Effect | Base price |
| --- | --- | --- | ---: |
| `ice_cream` | Ice Cream | Restores 15 HP | 15 |
| `health_potion` | Health Potion | Restores 20 HP | 25 |
| `greater_health_potion` | Greater Health Potion | Restores 50 HP | 60 |
| `strength_potion` | Strength Potion | +5 attack for 3 turns | 45 |
| `defense_potion` | Defense Potion | +5 defense for 3 turns | 45 |

The catalog stores item descriptions and effect metadata. Choosing the Item action
in battle opens a picker of every owned consumable with a supported effect (heal,
temporary attack boost, or temporary defense boost). The chosen item is removed
from the inventory immediately in memory; both the removal and any gold changes
are written when the player uses a Save Point.

A new game starts with **100 gold** and **2 Health Potions**. Winning a battle
awards **25 gold** in addition to the stat increases.

## Inventory API

```gdscript
SaveManager.add_item("health_potion", 3)

if SaveManager.has_item("health_potion"):
	print(SaveManager.get_item_count("health_potion"))

SaveManager.remove_item("health_potion")
var inventory: Dictionary = SaveManager.get_inventory()
```

- IDs are normalized to lowercase and may contain lowercase letters, numbers, underscores, hyphens, and periods.
- IDs are limited to 64 characters.
- Quantities must be positive integers.
- Removing more than the player owns fails without changing inventory.
- `inventory_changed` emits a copy of the inventory after a successful change.
- `get_inventory()` returns a copy, not the live dictionary.

## Currency API

```gdscript
SaveManager.add_gold(100)
print(SaveManager.get_gold())

if SaveManager.spend_gold(25):
	print("Purchase paid")
```

Gold persists in the save file and cannot be spent below zero.

## Shop API

Three example shops are included: `general_store`, `traveling_merchant`, and `ice_cream_shop`. The ice cream shop sells only `ice_cream`. Each shop has its own offer list and prices.

```gdscript
var offers: Array[Dictionary] = ShopManager.get_shop_inventory("general_store")
for offer in offers:
	print(offer["name"], " - ", offer["price"], " gold")

if ShopManager.buy_item("general_store", "health_potion", 2):
	print("Bought two potions")
```

Purchases check the shop's offers, validate the item and quantity, deduct gold, and add the purchased items. If adding the item fails, the gold deduction is refunded.

The reusable shop screen is `scenes/shop.tscn`, driven by `scripts/shop_ui.gd`. Instance it and set `shop_id` to `general_store`, `traveling_merchant`, or `ice_cream_shop`; call `open_shop(shop_id)` to show a different shop. The scene builds its offer list, displays the player's gold, handles purchases, and reports success or failure.

`scenes/Gameplay/Objects/shop_npc.tscn` is a ready-made shopkeeper. It shows a
prompt when the player is in range, emits `shop_requested(shop_id)` on interact,
and is already placed in `scenes/Gameplay/game_test_scene.tscn` alongside the
shop window. The test scene opens the shop when the signal fires. The Beach also
has an `IceCreamMachine` using the `ice_cream_shop` definition and its
`IceCreamMachine.png` artwork.


### Creating your own shop

Call `ShopManager.create_shop()` with a unique ID, display name, an item-to-price dictionary, and an optional description:

```gdscript
func _ready() -> void:
	var created := ShopManager.create_shop(
		"blacksmith",
		"The Blacksmith",
		{
			"health_potion": 12,
			"strength_potion": 90,
			"defense_potion": 65
		},
        "Special supplies, at blacksmith prices."
	)
	if created:
		$Shop.open_shop("blacksmith")
```

The item IDs must exist in `ItemDatabase`. Prices are whole numbers and can be zero (free), but cannot be negative. Creating a shop with an ID that already exists replaces that custom definition; a custom shop can also override a built-in shop ID. Custom shop definitions are held in memory, not saved, so register them again when the game starts.

You can change an existing custom offer with `ShopManager.set_shop_price("blacksmith", "health_potion", 20)`, add or change an offer with `ShopManager.add_shop_offer("blacksmith", "greater_health_potion", 100)`, or remove one with `ShopManager.remove_shop_offer("blacksmith", "health_potion")`. These methods return `false` if the shop or item is invalid or the operation cannot be performed.

After creating a shop, use the same reusable scene: `$Shop.open_shop("blacksmith")`. The shop UI automatically displays the custom name, description, offers, and prices, and purchases use those prices.

## Save behavior

Gold and inventory changes stay in memory until the player uses a Save Point.
Purchases made without saving are discarded when the game is reloaded. A save
point writes the current gold, inventory, player stats, and location together.

Recording the last visited location does not count as a gameplay progress save,
so it will not make the main menu show Continue before a Save Point records a
scene.

Deleting the save through `SaveManager.delete_save()` clears the inventory, currency, player progress, and upgrades.
