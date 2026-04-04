extends Control

@onready var oM =$optionsMenu

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.theme=load("res://Assets/Visual/lingualight.tres")
	
	visible = false
	_bring_to_front()

#func _process(delta: float) -> void:
	#if (Global.fontChoice==0):
	#	self.theme=load("res://Assets/Visual/Lingua.tres")
	#if (Global.fontChoice==1):
	#	self.theme=load("res://Assets/Visual/lingualight.tres")
	#if (Global.fontChoice==2):
		#self.theme=load("res://Assets/Visual/Receipt.tres")
#

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause") and (Global.wiremode== false):
		if (get_tree().paused==false ):
			_bring_to_front()
			get_tree().paused= true
			oM.visible =false
			visible=true
		elif (get_tree().paused ==true):
			get_tree().paused= false
			visible=false
			oM.visible =false


func _bring_to_front() -> void:
	var parent_node := get_parent()
	if parent_node:
		parent_node.move_child(self, parent_node.get_child_count() - 1)


func _on_resume_pressed() -> void:
	get_tree().paused = false
	visible = false
	#Switch scenes


func _on_options_pressed() -> void:
	oM.visible=true


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Master Scenes/titleScreen.tscn")


func _on_back_button_pressed() -> void:
	oM.visible=false





func _on_check_button_pressed() -> void:
	if (Global.turboMode ==false):
		Global.turboMode = true
		print (Global.turboMode)
	elif (Global.turboMode ==true):
		Global.turboMode = false
		print (Global.turboMode)


func _on_text_mode_button_item_selected(index: int) -> void:
	print(index)
	#Global.fontChoice=index


func _on_text_mode_button_item_focused(index: int) -> void:
	print(index)
	#Global.fontChoice=index
	#print(Global.fontChoice)
