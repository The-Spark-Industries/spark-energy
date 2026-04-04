extends Control

@onready var titleoptionsmenu = $optionsMenu
# Called when the node enters the scene tree for the first time.
@onready var title_sound= AudioServer.get_bus_index("SFX")
@onready var title_music=AudioServer.get_bus_index("Music")

func _ready() -> void:
	titleoptionsmenu.visible =false 
	self.theme=load("res://Assets/Visual/lingualight.tres")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Master Scenes/level1.tscn")


func _on_options_pressed() -> void:
	titleoptionsmenu.visible =true 


func _on_back_button_pressed() -> void:
		titleoptionsmenu.visible =false 


func _on_check_button_pressed() -> void:
	if (Global.turboMode ==false):
		Global.turboMode = true
		print (Global.turboMode)
	elif (Global.turboMode ==true):
		Global.turboMode = false
		print (Global.turboMode)


func _on_master_slider_value_changed(value: float) -> void:
		AudioServer.set_bus_volume_db(title_sound, linear_to_db(value))
		AudioServer.set_bus_volume_db(title_music, linear_to_db(value))


func _on_music_slider_value_changed(value: float) -> void:
		AudioServer.set_bus_volume_db(title_music, linear_to_db(value))


func _on_sound_slider_value_changed(value: float) -> void:
		AudioServer.set_bus_volume_db(title_sound, linear_to_db(value))
