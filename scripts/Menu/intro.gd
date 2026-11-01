extends Control
## Plays the opening story, then returns to the main menu.

const MAIN_MENU_SCENE := "res://scenes/mainmenu.tscn"
const STORY_DIALOGUE := "res://dialogue/the_story.json"

var _is_leaving: bool = false


func _ready() -> void:
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

	if not DialogueManager.start_dialogue(STORY_DIALOGUE):
		push_error("Intro: could not start the story dialogue. Returning to the main menu.")
		_go_to_main_menu()


func _on_dialogue_finished(_file_path: String, _last_node_id: String) -> void:
	_go_to_main_menu()


func _go_to_main_menu() -> void:
	if _is_leaving:
		return

	_is_leaving = true
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU_SCENE)
