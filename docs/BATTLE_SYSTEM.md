# Timing Battle System

A modular, turn-based battle system inspired by AdventureQuest-style combat and
Undertale timing bars. It is built from GDScript and custom-drawn `Control`
nodes, so all functional UI works without sprites, textures, music, or sound
assets. Enemy artwork is supported through an optional texture field.

New here? Start with [BATTLE_QUICKSTART.md](BATTLE_QUICKSTART.md).

The existing player movement and dialogue systems are untouched.

## Components

| File | Responsibility |
| --- | --- |
| `scripts/battle/battle_enemy.gd` | `BattleEnemy` resource: name, HP, attack damage, variance, talk lines, talk-victory settings, per-turn text, description, optional artwork texture. |
| `battle/enemies/mossling/mossling_enemy.gd` | Example enemy: a `BattleEnemy` subclass that sets its own defaults. |
| `battle/enemies/mossling/mossling.tres` | Example enemy resource pointing at `mossling_enemy.gd`. |
| `battle/enemies/mossling/mossling_battle.tscn` | Ready-to-run Mossling battle scene. |
| `scripts/battle/battle_manager.gd` | `BattleManager`: owns HP, items, turn state machine, damage math, and all battle signals. |
| `scripts/battle/timing_bar.gd` | `TimingBar`: shared marker movement, zone hit detection, input, and drawing. |
| `scripts/battle/attack_timing.gd` | `AttackTiming`: Perfect / Good / Miss zones and damage multipliers. |
| `scripts/battle/block_timing.gd` | `BlockTiming`: Perfect / Good / Partial / Miss zones and damage reduction. |
| `scripts/battle/battle_ui.gd` | `BattleUI`: action buttons, HP display, timing-bar host, enemy artwork, and adapter between input and `BattleManager`. |
| `scenes/battle/attack_timing.tscn` | Functional attack timing widget. |
| `scenes/battle/block_timing.tscn` | Functional block timing widget. |
| `scenes/battle/battle_ui.tscn` | Shared battle screen: enemy stage above a compact bottom panel with a child `BattleManager`. |

### Per-enemy folders

Each enemy is self-contained and copyable:

```text
battle/enemies/mossling/
├── mossling_enemy.gd    # extends BattleEnemy, sets stats in _init()
├── mossling.tres        # Resource with the script attached
└── mossling_battle.tscn # instance of scenes/battle/battle_ui.tscn with enemy set
```

To create another enemy, duplicate the folder, rename the three files, edit the
stats and optional `texture`, then fix the `ext_resource` paths in the `.tres`
and `.tscn`. Nothing in the shared scenes or scripts needs to change.

If you prefer not to copy files, make a fresh resource in the editor: right-click
the enemy folder in the FileSystem dock → **Create New → Resource…**, choose
`BattleEnemy`, save the `.tres`, fill its fields, and assign it to
`BattleUI.enemy`. A per-enemy `*_enemy.gd` script is optional; the base
`BattleEnemy` works on its own. You can also choose **New BattleEnemy** directly
on the `Enemy` property to keep the resource inline in the scene.

The dependencies point one way: `BattleUI` -> `BattleManager` -> `BattleEnemy`.
Timing widgets emit results to `BattleUI`; `BattleUI` forwards them to
`BattleManager`. `BattleManager` knows nothing about nodes or input.

## Battle flow

1. `BattleManager.start_battle()` initializes stats and enters `PLAYER_TURN`.
2. The player presses an action button (or focuses it and presses Enter/Space).
3. Attack:
   - `BattleManager` enters `ATTACK_TIMING`.
   - `BattleUI` shows `AttackTiming` and calls `start()`.
   - Z, X, or Enter stops the marker. The bar emits `timing_finished(zone, multiplier)`.
   - `BattleManager.submit_attack()` applies damage and shows the result.
4. Defend / Item / Talk:
   - Resolve immediately with a short result delay.
   - Defend reduces the next incoming hit by 25%.
   - Item heals 15 HP and consumes one potion. Item logic is intact, but the
	 button is hidden in the UI for now (`items_enabled = false`).
   - Talk displays a line from the enemy's `talk_lines`. If the enemy has
     `can_win_by_talking` enabled, enough Talk actions end the battle in victory.
5. `RESOLVE_PLAYER` -> `ENEMY_WINDUP` -> `BLOCK_TIMING`.
6. `BattleUI` shows `BlockTiming`; X, Z, or Enter stops the marker.
7. `BattleManager.submit_block()` applies reduction, then defend reduction.
8. `RESOLVE_ENEMY` -> `PLAYER_TURN`, or `VICTORY` / `DEFEAT` at zero HP.

The player action buttons are disabled outside `PLAYER_TURN`. Both
`BattleManager` and the timing bars guard against repeated presses: a second
submit in the same phase returns `false` / an empty dictionary and emits nothing.

## Default values

Player (`BattleManager` exports):

- Max HP: 40
- Attack: 12
- Potions: 2, healing 15 each
- Defend reduction: 25%
- Result delay: 0.7 s, enemy wind-up: 0.55 s

Attack timing (`AttackTiming` exports):

| Zone | Range | Multiplier |
| --- | --- | --- |
| Perfect | 0.45 - 0.55 | 1.5x |
| Good | 0.30 - 0.70 | 1.0x |
| Miss | everywhere else | 0.5x |

Block timing (`BlockTiming` exports):

| Zone | Range | Damage reduction |
| --- | --- | --- |
| Perfect | 0.45 - 0.55 | 100% |
| Good | 0.30 - 0.70 | 75% |
| Partial | 0.15 - 0.85 | 50% |
| Miss | everywhere else | 0% |

Marker speed defaults to 0.85 bars/second for attack and 1.15 for block. Bars
bounce off both edges. If the player does nothing for `input_timeout` seconds
(8 s by default), the bar times out as a full miss: 0 attack damage or 0% block.
The timeout is silent; no countdown or timer is shown.

Enemy (`battle/enemies/mossling/mossling.tres`, driven by
`mossling_enemy.gd`):

- Name: Mossling
- HP: 60
- Attack: 12, variance +/-2
- Three talk lines
- `can_win_by_talking = true`, `talks_to_win = 3`
- Four custom player-turn lines
- No texture yet, so the UI shows the large name placeholder

### Enemy artwork

`BattleEnemy.texture` is optional. When set, `BattleUI` displays it in the
`EnemyStage` above the battle panel using `TextureRect` with
`EXPAND_IGNORE_SIZE` and `STRETCH_KEEP_ASPECT_CENTERED`. When it is empty, a
large dim label with the enemy's name fills the stage instead. No artwork ships
with the project.

## Talk victory and per-turn text

Both are configured per enemy on the `BattleEnemy` resource, so different battles
can behave differently without changing the manager or UI.

### Winning by talking

By default `can_win_by_talking` is `false`, so Talk is only flavour and the enemy
must be defeated by damage. Enable it on enemies that can be reasoned with:

```text
can_win_by_talking = true
talks_to_win       = 3
talk_victory_text  = "The Mossling decides you are friendly and lets you pass."
```

Each Talk action increments an internal counter. Until the counter reaches
`talks_to_win`, the message shows the talk line exactly as written, with no
progress indicator. On the final talk the battle ends with `battle_ended(true)`,
using `talk_victory_text` (or a default line when it is empty). The counter
resets when the battle restarts.

Enemies with `can_win_by_talking = false` can never be won by talking, even if
`talks_to_win` is set.

### Talk text

`talk_lines` is the dialogue shown by the Talk action. Lines are used in order,
one per talk, and cycle if the battle runs longer:

```text
talk_lines = [
	"The Mossling tilts its head.",
	"You compliment the Mossling's moss.",
	"The Mossling rustles its leaves.",
]
```

When `talk_lines` is empty, `no_talk_lines_text` is shown instead (default:
`"It does not respond."`). Talk lines always appear exactly as written.

### Custom text each turn

`turn_lines` controls the message shown at the start of every player turn:

```text
turn_lines = [
	"The Mossling eyes you warily.",
	"The Mossling's leaves rustle.",
	"The Mossling seems to be listening.",
]
```

- Lines are used in order; the list cycles if the battle runs longer.
- An empty line falls back to the default turn message.
- `intro_text` replaces the first-turn message, but only when `turn_lines` is
  empty.
- The UI also shows the current turn number in the turn label.
- `BattleManager.turn_number` and the `turn_started(turn)` signal expose the
  counter if you want to drive other systems from it.

## Input map

`project.godot` adds two actions:

- `attack` = Z (logical `keycode`, not a physical position)
- `block` = X (logical `keycode`, not a physical position)

Logical keycodes mean the keys follow the OS keyboard layout, so QWERTZ users
get Z and X where those letters are printed rather than Y and X.

Both timing bars accept a shared set of stop keys:

- `AttackTiming.input_action` = `attack`, plus `extra_input_actions` = `block`, `ui_accept`.
- `BlockTiming.input_action` = `block`, plus `extra_input_actions` = `attack`, `ui_accept`.

So either bar stops on Z, X, or Enter. `ui_accept` also includes Space. Menu
navigation uses the existing `move_up`, `move_down`, `move_left`, `move_right`
actions, plus Arrow keys / Enter / Space through Godot's normal UI focus, or the
mouse. If you use different keys, change the actions in
**Project Settings > Input Map** and the prompts in `BattleUI` / `BattleManager`.

## Integration

### Standalone

Open `battle/enemies/mossling/mossling_battle.tscn` and run it. `BattleUI.auto_start`
is enabled, so it starts a battle with the Mossling immediately. This is the
fastest way to test the system.

You can also run the shared `scenes/battle/battle_ui.tscn`, which defaults to the
same Mossling resource.

### From a map scene

1. Instance `scenes/battle/battle_ui.tscn` as a child of your map scene (or use
   an enemy's `*_battle.tscn` and set its `enemy`).
2. Set `BattleUI.auto_start = false`.
3. Keep the instance hidden (`visible = false`) until an encounter starts.
4. Call `begin_battle()` from a trigger. On victory, BattleUI closes itself after
   a short delay; use `battle_finished` for rewards and `battle_exited` to resume
   map movement.

```gdscript
extends Node2D

@onready var battle_ui: BattleUI = $BattleUI

func _ready() -> void:
	battle_ui.battle_finished.connect(_on_battle_finished)
	battle_ui.battle_exited.connect(_on_battle_exited)

func _on_enemy_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not battle_ui.visible:
		var enemy: BattleEnemy = load("res://battle/enemies/mossling/mossling.tres")
		battle_ui.begin_battle(enemy)

func _on_battle_finished(victory: bool) -> void:
	# Combat is over. Do not hide the UI here if auto-exit is enabled.
	if victory:
		queue_free() # or open a reward / dialogue node

func _on_battle_exited(_victory: bool) -> void:
	# The battle screen is closed. Resume map movement here.
	pass
```

### Pausing gameplay

`BattleUI` runs in `PROCESS_MODE_ALWAYS` and freezes the rest of the scene tree
during combat by default (`pause_gameplay = true`). This keeps map movement and
other gameplay input from leaking through while buttons or timing bars are used.
It restores the previous pause state when the battle ends.

Disable `pause_gameplay` if your game manages pause state itself. In that case
pause the tree before calling `begin_battle()` and unpause it after
`battle_finished`; BattleUI will continue to work because of its always-process
mode.

### Ending the battle

`BattleUI` exposes two settings on its root node:

```text
auto_exit_on_victory = true
victory_exit_delay   = 2.0
```

When enabled, the victory text stays on screen for `victory_exit_delay` seconds,
then BattleUI hides itself and emits `battle_exited(true)`. The delay uses a timer
that runs while the tree is paused, so it works even if your game keeps the tree
paused after combat.

`battle_finished(victory)` still fires immediately when combat ends. Use it for
rewards or defeat handling. Use `battle_exited` when you need to know the screen
has actually closed. To close the screen yourself, set `auto_exit_on_victory` to
false and call `battle_ui.exit_battle()`. Defeat does not auto-exit by default,
so your game can show a game-over flow.

### Custom enemy

The recommended way is to copy the Mossling folder:

```text
battle/enemies/mossling/  ->  battle/enemies/lantern_warden/
```

Rename the files, then edit the new `*_enemy.gd`:

```gdscript
extends BattleEnemy

func _init() -> void:
	display_name = "Lantern Warden"
	max_hp = 120
	attack_damage = 18
	damage_variance = 4
	talk_lines = PackedStringArray(["The flame flickers.", "It does not answer."])
	description = "A towering figure of brass and fire."
	texture = preload("res://art/enemies/lantern_warden.png") # optional
```

Update the `ext_resource` paths in the new `.tres` and `.tscn`, and confirm the
scene's `enemy` property points at the new `.tres`.

Alternatively, create a bare `Resource`, assign `res://scripts/battle/battle_enemy.gd`
as its script, and fill in the exported fields. You can also pass an enemy
directly:

```gdscript
var boss := BattleEnemy.new()
boss.display_name = "Lantern Warden"
boss.max_hp = 120
boss.attack_damage = 18
boss.damage_variance = 4
boss.talk_lines = PackedStringArray(["The flame flickers.", "It does not answer."])
battle_ui.begin_battle(boss)
```

For a different player loadout, select the `BattleManager` child of
`BattleUI` and edit its exported player stats and pacing delays.

### Tuning timing

Select the `AttackTiming` or `BlockTiming` child inside
`BattleUI/Margin/Layout/BattlePanel/PanelMargin/Content/TimingArea/TimingHolder`:

- `marker_speed` changes bar speed.
- `input_timeout` changes when the silent timeout triggers (0 disables it). A
  timeout deals 0 damage / gives 0% block.
- Zone start/end exports change hit windows; narrower Perfect zones make the
  mechanic harder.
- Multiplier / reduction exports change the reward for accuracy.
- `input_action` changes the primary stop key; `extra_input_actions` lists the
  alternate keys that also stop the bar.

`BattleUI` reads these values at runtime, so changes take effect without editing
code. The custom `_draw()` code renders the track, zones, and marker with
`draw_rect`, so no image assets are required.

## UI layout

The battle scene is built as a single `Control` with a dim backdrop:

- `EnemyStage` — flexible area above the panel. Shows `EnemyTexture` when the
  enemy has art, otherwise `EnemyPlaceholder` (large, dim enemy name).
- `BattlePanel` — compact bottom panel containing, from top to bottom:
  - enemy name, HP bar, and `HP x / y` label;
  - one-line message;
  - turn indicator;
  - timing area with prompt and the active timing bar (hidden outside timing);
  - player HP bar and potion count (potion count hidden while items are off);
  - horizontal action row: Attack, Defend, Talk, and the hidden Item button;
  - victory/defeat row with the result label. After a win the whole screen
    closes itself; there is no restart button.

`BattleUI` hides the Item button and potion count when `items_enabled = false`
(the default). Item healing, counts, and signals remain in `BattleManager` and
are still covered by tests; set `items_enabled = true` on the `BattleUI` root to
show them again. Horizontal focus movement skips the Item button while hidden.

## Signals

`BattleManager`:

```gdscript
signal battle_started(enemy: BattleEnemy)
signal battle_ended(victory: bool)
signal phase_changed(new_phase: int)
signal input_locked_changed(locked: bool)
signal message_changed(text: String)
signal player_stats_changed(hp: int, max_hp: int, items: int)
signal enemy_stats_changed(hp: int, max_hp: int)
signal action_selected(action: String)
signal turn_started(turn: int)
signal attack_timing_started
signal attack_resolved(zone: String, multiplier: float, damage: int)
signal enemy_attack_started
signal block_timing_started
signal block_resolved(zone: String, reduction: float, damage: int)
signal defend_started(reduction: float)
signal talk_started(line: String)
signal enemy_damaged(amount: int, hp: int)
signal player_damaged(amount: int, hp: int)
signal player_healed(amount: int, hp: int, items_left: int)
signal battle_error(text: String)
```

`BattleUI` re-emits `battle_finished(victory)` when combat ends and
`battle_exited(victory)` when the battle screen hides itself. The manager's phases are
available as `BattleManager.Phase.PLAYER_TURN`, `ATTACK_TIMING`,
`RESOLVE_PLAYER`, `ENEMY_WINDUP`, `BLOCK_TIMING`, `RESOLVE_ENEMY`, `VICTORY`,
and `DEFEAT`.

`TimingBar` (used by both timing widgets) emits:

```gdscript
signal timing_finished(zone: String, value: float)
signal timing_timeout
```

## Testing

Run the headless tests from the project root:

```bash
GODOT=/path/to/godot

"$GODOT" --headless --path . --script res://tests/battle_manager_test.gd
"$GODOT" --headless --path . --script res://tests/battle_timing_test.gd
"$GODOT" --headless --path . --script res://tests/battle_ui_test.gd

# Existing dialogue tests should still pass:
"$GODOT" --headless --path . --script res://tests/dialogue_smoke_test.gd
```

The battle tests cover:

- Full player -> attack -> enemy -> block -> player round.
- Attack and block zone evaluation, including configurable ranges.
- Damage multipliers and stacked defend + block reduction.
- Item, Talk, victory, and defeat.
- Talk victory enabled/disabled and custom victory text.
- Custom talk lines and fallback talk text.
- Custom intro text and per-turn `turn_lines`.
- Repeated input / out-of-phase input rejection.
- Markers, bouncing, timeouts, signal payloads, and UI wiring.
- Logical QWERTZ-safe `attack` / `block` bindings.
- Shared stop keys: both bars accept Z, X, and Enter.
- Hidden Item button while `items_enabled` is false.
- Enemy artwork / placeholder wiring and the compact panel layout.
- Victory auto-exit: result stays visible briefly, then the UI hides.

Manual checklist:

1. Run `battle/enemies/mossling/mossling_battle.tscn`.
2. Use Arrow keys or WASD to focus an action; Enter/Space or mouse clicks it.
3. Choose Attack and press Z inside the Perfect zone (gold). Repeat and confirm X
   and Enter also stop the attack bar.
4. Confirm the enemy loses more HP on Perfect and less on Miss.
5. Wait for the attack bar to time out and confirm the message says no damage
   was dealt and the enemy HP does not change.
6. During the enemy turn, press X inside the gold block zone. Repeat and confirm
   Z and Enter also stop the block bar.
7. Wait for the block bar to time out and confirm you take full damage.
8. Confirm a Perfect block takes no damage; a Miss takes full damage.
9. Use Defend, then block the next hit to see the extra 25% reduction.
10. Confirm the Item button is hidden and no potion count is shown.
11. Use Talk three times and confirm the Mossling lets you pass without reaching
	zero HP. Set `can_win_by_talking = false` on another enemy and confirm Talk
	never wins.
12. Watch the message at the start of each player turn and confirm it uses the
	enemy's `turn_lines`.
13. Reduce the enemy to zero HP, confirm the victory text appears, then wait
    about 2 seconds and confirm the battle screen hides itself. There should be
    no Fight Again button.
