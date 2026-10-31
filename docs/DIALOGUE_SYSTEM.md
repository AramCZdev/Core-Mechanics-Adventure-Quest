# Dialogue System

An Undertale-inspired dialogue system for this Godot 4 project. It provides a bottom-screen dialogue box, speaker names, portraits, typewriter text, branching choices, dialogue events, and multiple JSON conversations.

It does not use external plugins or bundled Undertale assets. All example text is original, and `res://assets/icon.svg` is only a placeholder portrait.

## Files

| File | Purpose |
| --- | --- |
| `scripts/dialogue/dialogue_manager.gd` | Autoload singleton. Loads JSON, validates nodes, tracks state, emits signals. |
| `scripts/dialogue/dialogue_box.gd` | Dialogue UI controller. Typewriter, portrait, input, choice navigation. |
| `scripts/dialogue/dialogue_choice.gd` | A single selectable choice button. |
| `scenes/dialogue/dialogue_box.tscn` | Reusable dialogue UI scene. |
| `scenes/dialogue/dialogue_choice.tscn` | Choice button scene. Restyle this to change choice visuals. |
| `scripts/dialogue/dialogue_trigger.gd` | Optional `Area2D` helper that starts dialogue on `interact`. |
| `scenes/dialogue/dialogue_demo.tscn` | Standalone demo scene. |
| `dialogue/example_conversation.json` | Branching example with events. |
| `dialogue/merchant.json` | Second example file. |
| `tests/dialogue_smoke_test.gd` | Headless manager test. |
| `tests/dialogue_box_test.tscn` | Headless UI/input test. |

The project already has these entries:

- Autoload: `DialogueManager` -> `res://scripts/dialogue/dialogue_manager.gd`
- Input action: `interact` -> E, Enter, Space, Z

If you copy the system into another project, add both entries in **Project > Project Settings**.

## Quick demo

Open `scenes/dialogue/dialogue_demo.tscn` and press **F6**.

- Press **E / Enter / Space / Z** to start.
- While text is typing, the same key finishes the line.
- Press it again to advance.
- When choices appear, use **Up/Down** or **W/S**, then press interact.
- Events appear in the yellow line at the top of the demo.

## Integration

### 1. Add the UI to your gameplay scene

Instance `scenes/dialogue/dialogue_box.tscn` under a `CanvasLayer` in your gameplay scene. Put the canvas layer above the world (for example `layer = 10`).

Only add one `DialogueBox` instance. Multiple boxes would all listen to the same manager.

The box is full-screen, hidden by default, and only blocks the mouse while visible. The actual panel is anchored to the bottom edge.

### 2. Start a conversation

From an NPC or interaction script:

```gdscript
func talk() -> void:
	if DialogueManager.is_active:
		return
	DialogueManager.start_dialogue("res://dialogue/example_conversation.json")
```

The manager refuses a second session while one is active, so the guard is optional but useful for avoiding error logs.

Full paths and shorthand paths both work:

```gdscript
DialogueManager.start_dialogue("res://dialogue/merchant.json")
DialogueManager.start_dialogue("merchant.json")
DialogueManager.start_dialogue("merchant")
```

The last two resolve to `res://dialogue/merchant.json`.

You can override the starting node:

```gdscript
DialogueManager.start_dialogue("merchant", "tobin_maps")
```

### 3. Optional Area2D trigger

Attach `scripts/dialogue/dialogue_trigger.gd` to an `Area2D` that covers your NPC, assign the dialogue file, and set its collision mask to detect the player.

The helper assumes your player is a `CharacterBody2D`. If your player uses a different body type, use your own interaction code instead (call `DialogueManager.start_dialogue(...)`).

`one_shot` stops the trigger from being used again.

### 4. React to game events

Connect to `event_triggered` once, usually in a quest/autoload script or the gameplay scene:

```gdscript
func _ready() -> void:
	DialogueManager.event_triggered.connect(_on_dialogue_event)


func _on_dialogue_event(event_name: String, payload: Variant) -> void:
	match event_name:
		"quest_started":
			QuestLog.start_quest(payload["quest_id"])
		"met_mira":
			QuestLog.mark_met("mira")
		"shop_opened":
			ShopUI.open(payload["shop_id"])
```

Events can be attached to a node or to a choice. Node events fire when the node is entered; choice events fire when that choice is selected.

All manager signals:

| Signal | Arguments |
| --- | --- |
| `dialogue_started` | `file_path`, `start_node` |
| `node_changed` | `node_id`, `node` dictionary, `portrait` texture |
| `choices_presented` | `choices` array |
| `choice_made` | `choice_index`, `choice` dictionary |
| `event_triggered` | `event_name`, `payload` |
| `dialogue_finished` | `file_path`, `last_node_id` |
| `dialogue_error` | `message` |

### 5. Pause behavior

By default, `pause_gameplay` is enabled on the `DialogueBox`. It pauses the scene tree during dialogue and restores the previous pause state afterward. The box itself keeps processing while paused.

If your game must keep processing, disable `pause_gameplay` in the inspector. In that case, stop player movement yourself:

```gdscript
func _physics_process(_delta: float) -> void:
	if DialogueManager.is_active:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Existing movement code...
```

The existing player script was intentionally left untouched.

## JSON format

Example (`dialogue/example_conversation.json`):

```json
{
  "start_node": "narrator_intro",
  "nodes": {
	"narrator_intro": {
	  "speaker": "Narrator",
	  "portrait": "",
	  "text": "The fog parts around a crooked stone lantern.",
	  "next": "mira_greeting",
	  "typing_speed": 24
	},
	"mira_greeting": {
	  "speaker": "Mira",
	  "portrait": "res://assets/icon.svg",
	  "text": "You made it through the fog.",
	  "next": "mira_offer",
	  "event": "met_mira"
	},
	"mira_offer": {
	  "speaker": "Mira",
	  "portrait": "res://assets/icon.svg",
	  "text": "Will you help?",
	  "choices": [
		{
		  "text": "I will help.",
		  "next": "mira_accept",
		  "event": {
			"name": "quest_started",
			"data": {
			  "quest_id": "relight_the_lantern"
			}
		  }
		},
		{
		  "text": "Not right now.",
		  "next": "mira_decline"
		}
	  ]
	},
	"mira_accept": {
	  "speaker": "Mira",
	  "portrait": "res://assets/icon.svg",
	  "text": "Take this spark.",
	  "next": "mira_farewell"
	},
	"mira_farewell": {
	  "speaker": "Mira",
	  "portrait": "res://assets/icon.svg",
	  "text": "Keep the spark close."
	},
	"mira_decline": {
	  "speaker": "Mira",
	  "portrait": "res://assets/icon.svg",
	  "text": "I will be here if you change your mind.",
	  "next": ""
	}
  }
}
```

### Root fields

| Field | Required | Meaning |
| --- | --- | --- |
| `nodes` | Yes | Object of named dialogue nodes. |
| `start_node` | No | Node to enter first. Falls back to the first node in the file. |

### Node fields

| Field | Required | Meaning |
| --- | --- | --- |
| `speaker` | No | Name shown above the text. Empty hides the label. |
| `portrait` | No | `res://` path to a `Texture2D`. Empty hides the portrait. |
| `text` | No | Dialogue text. Supports BBCode. Empty text shows choices immediately. |
| `next` | No | Next node ID. Missing or empty ends the conversation. |
| `choices` | No | Array of choice objects. When present, the text must finish before choices appear. |
| `typing_speed` | No | Characters per second for this node. `0` shows text instantly. |
| `event` | No | String event name, or `{ "name": "...", "data": ... }`. |

### Choice fields

| Field | Required | Meaning |
| --- | --- | --- |
| `text` | Yes | Visible choice label. |
| `next` | No | Node to enter. Missing or empty ends the conversation. |
| `event` | No | Same format as node events. Fires when the choice is selected. |

Extra custom fields are preserved in the choice/node dictionaries, so they can be used later for quests, conditions, or inventory checks.

## Portrait and typing configuration

- **Portrait per node:** set `"portrait": "res://assets/portraits/character.png"`.
- **Fallback portrait:** assign `default_portrait` on the `DialogueBox` instance.
- **Missing portrait:** the portrait frame is hidden and a warning is logged. Dialogue still runs.
- **Default typing speed:** set `typing_speed` on the `DialogueBox` (characters per second).
- **Per-node typing speed:** add `"typing_speed": 50` to a node.
- **Instant text:** set a node's `typing_speed` to `0`.

Artwork is intentionally not included. Replace the placeholder portrait paths in the example JSON and restyle `StyleBoxFlat` resources in `dialogue_box.tscn` / `dialogue_choice.tscn` to match your game.

## Error handling

- Invalid JSON, missing files, non-object roots, empty `nodes`, and missing start nodes are refused; `start_dialogue()` returns `false`.
- A missing `next` node ends the active conversation cleanly.
- Malformed choice arrays or choices without `text` end the conversation cleanly.
- Every error is logged with `push_warning()` and emitted through `dialogue_error`.
- `start_dialogue()` refuses to run while `is_active` is true.

The error path is always "emit signal, log, stop safely", never a crash.

## Adding more conversations

1. Create a new `.json` file under `dialogue/`.
2. Give it a unique `start_node` and named nodes.
3. Call `DialogueManager.start_dialogue("res://dialogue/your_file.json")`.

No manager changes are needed. Files are loaded on demand, so adding conversations does not require touching the autoload or UI.

## Testing

### Automated tests

Manager logic:

```bash
godot --headless --path . --script res://tests/dialogue_smoke_test.gd
```

Expected output: `Dialogue smoke test: PASS`. The test intentionally triggers error cases, so warning logs are normal.

UI, typewriter, input, and choice navigation:

```bash
godot --headless --path . res://tests/dialogue_box_test.tscn
```

Expected output: `Dialogue box test: PASS`.

### Manual demo test

1. Run `scenes/dialogue/dialogue_demo.tscn` with F6.
2. Start dialogue. Confirm the box appears at the bottom and the text reveals gradually.
3. Press interact while it is still typing. The full line should appear immediately.
4. Press interact again. The next node should appear.
5. Continue until the three choices appear. Confirm interact while typing does not skip the choices.
6. Use Up/Down and W/S. Focus should wrap around the list.
7. Select "What is in it for me?" and confirm it loops back to the offer.
8. Select the accepting option and confirm `quest_started` appears in the demo event line.
9. Finish the conversation and confirm the box disappears.
10. Press interact again to confirm a new session can start.

### Error-path tests

- Temporarily rename a portrait path in a JSON file. Dialogue should continue with no portrait and log a warning.
- Temporarily set a node's `next` to a missing ID. Dialogue should emit an error and close safely.
- Temporarily put invalid JSON in a file. `start_dialogue()` should return `false` and log the parse line.
- Start the same dialogue twice without finishing. The second call should be refused and the active session should continue.

### Integration checklist

- `DialogueBox` is present once in the gameplay scene.
- `interact` is mapped in the Input Map.
- The player is frozen during dialogue, either through `pause_gameplay` or a manual guard.
- Quest/gameplay scripts are connected to `event_triggered` if they need dialogue events.
- Portrait paths point to imported `Texture2D` resources in your project.

## Public manager API

```gdscript
DialogueManager.start_dialogue(path: String, start_node: String = "") -> bool
DialogueManager.advance() -> bool
DialogueManager.select_choice(index: int) -> bool
DialogueManager.end_dialogue() -> void
DialogueManager.has_choices() -> bool
DialogueManager.is_active -> bool
```

Typical gameplay code only needs `start_dialogue()`, `is_active`, and `event_triggered`.
