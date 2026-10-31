# Battle Quick Start

## 1. Try it now

Open and run the example enemy's own battle scene:

```text
res://battle/enemies/mossling/mossling_battle.tscn
```

A battle with the Mossling starts immediately. That scene is a complete battle
screen, so you can test the whole loop without touching your map.

`res://scenes/battle/battle_ui.tscn` is the shared generic battle screen. Each
enemy has its own ready-to-run scene that inherits it, so you never have to edit
the shared scene to test a specific fight.

The UI is deliberately compact: enemy artwork (or a large name placeholder) fills
the space above a bottom battle panel. The panel holds the enemy and player HP,
the message, the timing bar, and the action buttons.

## 2. Add a battle to your game

Instance `res://scenes/battle/battle_ui.tscn` as a child of your gameplay scene.

In the inspector, turn off `Auto Start` and keep the battle hidden. Then start it
from an encounter trigger:

```gdscript
extends Node2D

@onready var battle_ui: BattleUI = $BattleUI


func _ready() -> void:
	battle_ui.battle_finished.connect(_on_battle_finished)
	battle_ui.battle_exited.connect(_on_battle_exited)


func _on_enemy_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not battle_ui.visible:
		battle_ui.show()
		battle_ui.begin_battle(
			load("res://battle/enemies/mossling/mossling.tres")
		)


func _on_battle_finished(victory: bool) -> void:
	# Combat is over. Put rewards / defeat logic here.
	# On victory, BattleUI hides itself after victory_exit_delay (2 s by default),
	# so do not call battle_ui.hide() here.
	if victory:
		print("Enemy defeated!")


func _on_battle_exited(_victory: bool) -> void:
	# The battle screen has closed. Resume map movement or other gameplay here.
	pass
```

Connect `BattleUI.battle_finished` in the editor or from code. BattleUI pauses
the scene tree during combat by default, so player movement stops automatically.
Set `Pause Gameplay` to off if your game manages pause state itself.

On victory, BattleUI shows the result for `victory_exit_delay` seconds (default
**2**), then hides itself and emits `battle_exited`. Set `Auto Exit On Victory`
to off if you want to close the battle screen yourself with `exit_battle()`.

## 3. Make an enemy

Every enemy lives in its own copyable folder under `battle/enemies/`. The
Mossling folder is the template:

```text
battle/enemies/mossling/
├── mossling_enemy.gd    # BattleEnemy subclass with this enemy's stats
├── mossling.tres        # Resource that points at the script
└── mossling_battle.tscn # Ready-to-run battle scene for this enemy
```

### What is a .tres file?

A `.tres` is just Godot's text format for a `Resource`. Here it stores one
enemy's stats (name, HP, damage, talk lines, optional texture). You normally
create it from the editor, not by hand.

### Creating the enemy .tres in the editor

1. In the **FileSystem** dock, right-click the enemy folder (for example
   `battle/enemies/lantern_warden/`) and choose **Create New → Resource…**
2. Search for `BattleEnemy`, select it, and click **Create**.
3. Save it as `lantern_warden.tres` inside that enemy's folder.
4. Double-click the new `.tres` and fill in the Inspector:

   ```text
   display_name       = Lantern Warden
   max_hp             = 120
   attack_damage      = 18
   damage_variance    = 4
   talk_lines         = ["The flame flickers."]
   no_talk_lines_text = "It does not respond."
   can_win_by_talking = false
   talks_to_win       = 3
   turn_lines         = ["The warden watches you."]
   intro_text         = (optional first-turn line)
   texture            = (optional, leave empty for the name placeholder)
   ```

5. Give that enemy a battle scene: duplicate `mossling_battle.tscn`, or create a
   new scene, instance `res://scenes/battle/battle_ui.tscn`, select its root
   `BattleUI`, and drag the `.tres` into the **Enemy** property.

If you want the resource to use a per-enemy script (like Mossling), select the
`.tres`, scroll to **Script** at the bottom of the Inspector, and assign the new
`*_enemy.gd`. This is optional: a plain `BattleEnemy` resource works fine.

### Copying the Mossling folder

1. Duplicate `battle/enemies/mossling/` and rename the folder, for example
   `battle/enemies/lantern_warden/`.
2. Rename the three files to match the new enemy.
3. Open the new `*_enemy.gd` and edit the defaults in `_init()`:

   ```gdscript
   extends BattleEnemy

   func _init() -> void:
       display_name = "Lantern Warden"
       max_hp = 120
       attack_damage = 18
       damage_variance = 4
       talk_lines = PackedStringArray(["The flame flickers."])
       no_talk_lines_text = "It does not respond."
       description = "A towering figure of brass and fire."
       can_win_by_talking = false
       talks_to_win = 3
       turn_lines = PackedStringArray(["The warden watches you."])
       # texture = preload("res://path/to/lantern_warden.png")
   ```

4. Open the copied `.tres`, find **Script** at the bottom of the Inspector, and
   point it at the renamed `*_enemy.gd`.
5. Open the copied `.tscn` and confirm its **Enemy** property uses the new `.tres`.

### Even simpler: no .tres at all

You can skip the separate file. Select the root `BattleUI` node, click the
**Enemy** property, choose **New BattleEnemy**, and fill in the fields directly.
The enemy is then stored inside that `.tscn`. Use this while prototyping, and
switch to a `.tres` when you want to reuse the same enemy in several fights.

### Enemy artwork

`BattleEnemy.texture` is optional. Assign a texture in the `.tres` inspector or
`preload()` it in the enemy script to show artwork above the battle panel. When
it is empty, the UI shows a large, dim enemy-name placeholder instead. No art is
included with the project; bring your own image when you are ready.

```gdscript
texture = preload("res://art/enemies/lantern_warden.png")
```

### Winning by talking

Talk victory is **off by default**, so most enemies can only be defeated by
damage. Turn it on per enemy in the `.tres` Inspector:

```text
can_win_by_talking = true
talks_to_win       = 3
talk_victory_text  = "The Lantern Warden lowers its guard."
```

After three Talk actions the battle ends in victory, and
`talk_victory_text` is shown. Until then the message shows the talk line exactly
as written, with no counter. Leave `can_win_by_talking` off for enemies that
cannot be talked down, even if `talks_to_win` has a value.

The included Mossling has this enabled with `talks_to_win = 3`, so you can test
it immediately.

### Changing the talk text

`talk_lines` is the text shown when you choose Talk. The manager uses them in
order, one per Talk action:

```text
talk_lines = [
    "The Mossling tilts its head.",
	"You compliment the Mossling's moss.",
	"The Mossling rustles its leaves.",
]
```

If `talk_lines` is empty, `no_talk_lines_text` is shown instead. It defaults to
`"It does not respond."`.

Talk lines appear exactly as written; the UI does not show how many talks are
left or required.

### Custom text each turn

`turn_lines` sets the message shown at the start of each player turn:

```text
turn_lines = [
	"The warden watches you.",
	"Its flame burns brighter.",
	"It seems to be waiting.",
]
```

Lines are used in order and repeat if the battle runs longer. Leave the list
empty for the default turn message. `intro_text` can replace the first-turn
message, but only when `turn_lines` is empty.

The UI also displays the current turn number in the turn label, and
`BattleManager.turn_number` plus the `turn_started(turn)` signal expose it to
your own code.

## 4. Tune the fight

Select the `BattleManager` child of BattleUI for player and pacing settings:

```text
player_max_hp               = 40
player_attack               = 12
starting_items              = 2
item_heal_amount            = 15
defend_damage_reduction     = 0.25
transition_delay            = 0.7
enemy_windup_delay          = 0.55
result_delay                = 0.7
```

Select `AttackTiming` or `BlockTiming` inside
`BattleUI/Margin/Layout/BattlePanel/PanelMargin/Content/TimingArea/TimingHolder`
to tune the bars:

- `marker_speed` — how fast the marker moves.
- `perfect_start` / `perfect_end` — better hit windows.
- `good_start` / `good_end` — wider windows.
- `perfect_multiplier` / `good_multiplier` / `miss_multiplier` — attack damage.
- `perfect_reduction` / `good_reduction` / `partial_reduction` — block strength.
- `input_timeout` — after N seconds without input the bar times out as a full
  miss: 0 attack damage or 0% block. Set `0` to disable. No timer is shown.
- `input_action` / `extra_input_actions` — which keys stop the bar.

Defaults:

| Action | Perfect | Good | Partial | Miss |
| --- | --- | --- | --- | --- |
| Attack damage | 1.5x | 1.0x | — | 0.5x |
| Block reduction | 100% | 75% | 50% | 0% |

Select the `BattleUI` root for end-of-battle settings:

```text
auto_exit_on_victory = true
victory_exit_delay   = 2.0
```

On victory, the result text stays on screen for `victory_exit_delay` seconds,
then BattleUI hides itself and emits `battle_exited`. Turn `auto_exit_on_victory`
off if you want to control that yourself with `exit_battle()`.

## 5. Controls

- Arrow keys / WASD: select an action.
- Enter, Space, or mouse: confirm.
- Timing bars: **Z**, **X**, or **Enter** all stop either bar. Space works too
  because it is part of `ui_accept`.

The keys come from the `attack` and `block` actions in
**Project Settings > Input Map**. They use logical keycodes, not physical
positions, so `Z` and `X` stay where they are printed on QWERTZ keyboards
(`Z` and `X`, not swapped with `Y`).

## 6. Items are disabled for now

Item logic still exists in `BattleManager`, but the Item button and potion count
are hidden by default (`BattleUI.items_enabled = false`). Re-enable them later by
setting `items_enabled` to true on the `BattleUI` root; no combat code needs to
change.

## 7. React to battle events

`BattleUI` re-emits three convenient signals:

```gdscript
func _ready() -> void:
	battle_ui.battle_started.connect(_on_battle_started)
	battle_ui.battle_finished.connect(_on_battle_finished)
	battle_ui.battle_exited.connect(_on_battle_exited)


func _on_battle_started(enemy: BattleEnemy) -> void:
	print("Fighting ", enemy.display_name)


func _on_battle_finished(victory: bool) -> void:
	if victory:
		print("Enemy defeated!")


func _on_battle_exited(_victory: bool) -> void:
	print("Battle screen closed.")
```

`battle_finished` fires as soon as combat ends. `battle_exited` fires when
BattleUI hides itself after the victory delay (or when you call `exit_battle()`).

For per-hit events, connect to the `BattleManager` child directly:

```gdscript
@onready var manager: BattleManager = $BattleUI/BattleManager


func _ready() -> void:
	manager.attack_resolved.connect(_on_attack)
	manager.block_resolved.connect(_on_block)
	manager.player_damaged.connect(_on_player_damaged)


func _on_attack(zone: String, multiplier: float, damage: int) -> void:
	print("%s attack: %d damage (%.1fx)" % [zone, damage, multiplier])


func _on_block(zone: String, reduction: float, damage: int) -> void:
	print("%s block: %d damage taken" % [zone, damage])


func _on_player_damaged(amount: int, hp: int) -> void:
	print("Player took %d damage, %d HP left" % [amount, hp])
```

Other useful signals include `battle_ended`, `phase_changed`,
`player_stats_changed`, `enemy_stats_changed`, `action_selected`,
`talk_started`, and `battle_error`.

## 8. Test it

Run the headless tests:

```bash
GODOT=/path/to/godot

"$GODOT" --headless --path . --script res://tests/battle_manager_test.gd
"$GODOT" --headless --path . --script res://tests/battle_timing_test.gd
"$GODOT" --headless --path . --script res://tests/battle_ui_test.gd
```

Manual check: run `battle/enemies/mossling/mossling_battle.tscn`, press Attack,
hit Z (or X / Enter) in the gold zone, then hit X (or Z / Enter) in the gold zone
on the enemy turn. Confirm Perfect deals 18 damage and a Perfect block takes none.
The Item button should not be visible. Press Talk three times and confirm the
Mossling lets you pass without reaching zero HP. Watch the message at the start of
each player turn to see the custom turn lines. After winning, the victory text
stays up for about 2 seconds and then the battle screen closes.

## Common fixes

- **Battle does not start:** `Auto Start` is off and `begin_battle()` was not called.
- **Player still moves during battle:** make sure `Pause Gameplay` is on, or pause
  the tree yourself before `begin_battle()`.
- **Z or X does nothing:** check the `attack` and `block` actions in the Input Map.
- **Timing bar never stops:** press Z, X, or Enter while the bar is visible;
  otherwise it silently times out after `input_timeout` seconds as a full miss
  (0 damage / 0% block).
- **Talk never wins:** set `can_win_by_talking = true` on that enemy's `.tres`.
- **Turn text does not change:** fill in `turn_lines` on the enemy; an empty list
  uses the default message.
- **Enemy art does not show:** assign a texture to `BattleEnemy.texture`. Without
  one, the UI intentionally shows the name placeholder.
- **Battle scene is not fullscreen:** instance `battle_ui.tscn` under a
  `CanvasLayer` or keep it as the last UI child in your map scene.

For architecture, full signal details, and integration notes, see
[BATTLE_SYSTEM.md](BATTLE_SYSTEM.md).
