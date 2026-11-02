# Persistent Item Inventory

The project autoloads `SaveManager` from `scripts/save_manager.gd`. Its inventory is stored in the existing `user://savegame.cfg` file, under the `[inventory]` section.

Inventory changes are written to disk immediately, so they do not require the player to visit a Save Point. They are also preserved when the player saves progress at a Save Point.

## API

```gdscript
# Give the player three potions.
SaveManager.add_item("potion", 3)

# Check ownership and quantity.
if SaveManager.has_item("potion"):
    print("Potions: ", SaveManager.get_item_count("potion"))

# Consume one potion. Returns false if the player has none.
if SaveManager.remove_item("potion"):
    print("Potion consumed")

# Get a snapshot of the inventory.
var inventory: Dictionary = SaveManager.get_inventory()
```

- Item IDs are normalized to lowercase and may contain lowercase letters, numbers, underscores, hyphens, and periods.
- IDs are limited to 64 characters.
- Quantities must be positive integers.
- Removing more items than the player owns fails without changing the inventory.
- `inventory_changed` is emitted after a successful inventory change. Its argument is a copy of the current inventory.
- `get_inventory()` returns a copy; change inventory through `add_item()` and `remove_item()`, not by editing the returned dictionary.

## Save behavior

The inventory is saved immediately after every successful add or remove operation. Inventory-only data does not count as a gameplay progress save, so it will not make the main menu show Continue before a Save Point has recorded a scene.

Deleting the save through `SaveManager.delete_save()` clears the inventory along with player progress and upgrades.
