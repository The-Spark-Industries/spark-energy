extends Control

@onready var titleoptionsmenu = $optionsMenu
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	titleoptionsmenu.visible =false 


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Master Scenes/level1.tscn")


func _on_options_pressed() -> void:
	titleoptionsmenu.visible =true 


func _on_back_button_pressed() -> void:
		titleoptionsmenu.visible =false 
