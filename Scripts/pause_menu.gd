extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _input(event: InputEvent) -> void:
	if Input.is_action_pressed("pause"):
		if (get_tree().paused==false ):
			get_tree().paused= true
			visible=true
		elif (get_tree().paused ==true):
			get_tree().paused= false
			visible=false

func _on_resume_pressed() -> void:
	get_tree().paused = false
	visible = false
	#Switch scenes


func _on_options_pressed() -> void:
	pass # Replace with function body.


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Master Scenes/titleScreen.tscn")
