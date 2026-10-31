# Dialogue Quick Start

## 1. Add the dialogue box

Open your gameplay scene. Add a `CanvasLayer`, then instance this scene inside it:

```text
res://scenes/dialogue/dialogue_box.tscn
```

Done. The box stays hidden until dialogue starts.

## 2. Start a conversation

Call this from your NPC or interaction code:

```gdscript
DialogueManager.start_dialogue("res://dialogue/example_conversation.json")
```

That is the only code needed to show dialogue.

## 3. Make a dialogue file

Create a JSON file in the `dialogue/` folder:

```json
{
  "start_node": "hello",
  "nodes": {
	"hello": {
	  "speaker": "Mira",
	  "portrait": "res://assets/icon.svg",
	  "text": "Hello, traveler.",
	  "next": "question"
	},
	"question": {
	  "speaker": "Mira",
	  "portrait": "res://assets/icon.svg",
	  "text": "Will you help me?",
	  "choices": [
		{
		  "text": "Yes.",
		  "next": "yes"
		},
		{
		  "text": "No.",
		  "next": "no"
		}
	  ]
	},
	"yes": {
	  "speaker": "Mira",
	  "text": "Thank you."
	},
	"no": {
	  "speaker": "Mira",
	  "text": "Maybe later, then."
	}
  }
}
```

Rules:

- `start_node` is the first node.
- `next` goes to another node.
- No `next` means the conversation ends.
- `choices` creates selectable options.
- `portrait` can be any `Texture2D` path. Leave it empty for no portrait.
- Add `"typing_speed": 20` to a node to change its text speed.

## 4. Controls

- `E`, `Enter`, `Space`, or `Z`: start / finish text / advance.
- `Up` / `Down` or `W` / `S`: choose an option.

## 5. Trigger game events

Add an `event` to a node or choice:

```json
"event": {
  "name": "quest_started",
  "data": {
	"quest_id": "relight_the_lantern"
  }
}
```

Then listen for it:

```gdscript
func _ready() -> void:
	DialogueManager.event_triggered.connect(_on_event)


func _on_event(event_name: String, payload: Variant) -> void:
	if event_name == "quest_started":
		print("Quest started:", payload["quest_id"])
```

## 6. Test it

Open `res://scenes/dialogue/dialogue_demo.tscn` and press **F6**.

If something is wrong, check the Godot output panel. Bad JSON, missing files, and missing nodes are reported there without crashing the game.

## Common fixes

- **Nothing appears:** make sure `dialogue_box.tscn` is in the scene and `start_dialogue()` was called.
- **Portrait missing:** check the path starts with `res://` and points to an imported image.
- **Choices do not appear:** make sure the node uses `choices`, not `next`, and let the text finish typing.
- **Second conversation will not start:** the first one is still active. Finish it or call `DialogueManager.end_dialogue()`.

For the full reference, see [DIALOGUE_SYSTEM.md](DIALOGUE_SYSTEM.md).
