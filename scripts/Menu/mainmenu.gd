extends Control


func _ready() -> void:
	pass # Replace with function body.



func _on_achievements_pressed() -> void:
	get_tree().change_scene_to_file("res://addons/SimpleAchievement/ui/AchievementViewer.tscn")
