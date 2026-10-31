extends Button
class_name DialogueChoice
## A single selectable dialogue option.
##
## DialogueBox creates these from choice data and handles keyboard focus.

signal choice_chosen(index: int)

var choice_index: int = -1


func _ready() -> void:
    pressed.connect(_on_pressed)


## Assigns the manager-facing index and the visible label.
func setup(index: int, choice_text: String) -> void:
    choice_index = index
    text = choice_text


func _on_pressed() -> void:
    choice_chosen.emit(choice_index)
