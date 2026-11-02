# Persistent Inventory, Items, Currency, and Shops

The project autoloads `SaveManager` and `ShopManager`. Item definitions live in `scripts/item_database.gd`. All persistent data uses the existing `user://savegame.cfg` file.

## Available items

| ID | Item | Effect | Base price |
| --- | --- | --- | ---: |
| `health_potion` | Health Potion | Restores 20 HP | 25 |
| `greater_health_potion` | Greater Health Potion | Restores 50 HP | 60 |
| `strength_potion` | Strength Potion | +5 attack for 3 turns | 45 |
| `defense_potion` | Defense Potion | +5 defense for 3 turns | 45 |

The catalog stores item descriptions and effect metadata. The battle system still needs to apply these effects when an item is used.

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

Two example shops are included: `general_store` and `traveling_merchant`. Each shop has its own offer list and prices.

```gdscript
var offers: Array[Dictionary] = ShopManager.get_shop_inventory("general_store")
for offer in offers:
    print(offer["name"], " - ", offer["price"], " gold")

if ShopManager.buy_item("general_store", "health_potion", 2):
    print("Bought two potions")
```

Purchases check the shop's offers, validate the item and quantity, deduct gold, and add the purchased items. If adding the item fails, the gold deduction is refunded.

A UI can display the returned shop data and call `buy_item()` from a Buy button. This PR supplies the reusable shop logic and data, not a finished shop screen or NPC interaction.

## Save behavior

Inventory and currency are written to `user://savegame.cfg` immediately. Inventory-only data does not count as a gameplay progress save, so it will not make the main menu show Continue before a Save Point records a scene.

Deleting the save through `SaveManager.delete_save()` clears the inventory, currency, player progress, and upgrades.
