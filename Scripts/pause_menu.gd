extends Control

static var _input_owner: Node = null

@onready var oM =$optionsMenu

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.theme=load("res://Assets/Visual/Lingua.tres")

	if _input_owner == null:
		_input_owner = self
	else:
		set_process_input(false)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		return

	visible = false
	oM.visible = false
	_bring_to_front()
	z_index = 200

func _process(delta: float) -> void:
	if (Global.fontChoice==0):
		self.theme=load("res://Assets/Visual/Lingua.tres")
	if (Global.fontChoice==1):
		self.theme=load("res://Assets/Visual/lingualight.tres")
	if (Global.fontChoice==2):
		self.theme=load("res://Assets/Visual/Receipt.tres")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _input(event: InputEvent) -> void:
	if _input_owner != self:
		return

	if event.is_action_pressed("pause") and not event.is_echo() and (Global.wiremode == false):
		if (Global.tutorialchecker == 2):
			Global.tutorialchecker = 3

		_set_pause_state(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _set_pause_state(paused: bool) -> void:
	if paused:
		_bring_to_front()
		get_tree().paused = true
		oM.visible = false
		visible = true
	else:
		get_tree().paused = false
		visible = false
		oM.visible = false


func _bring_to_front() -> void:
	var parent_node := get_parent()
	if parent_node:
		parent_node.call_deferred("move_child", self, parent_node.get_child_count() - 1)
		parent_node.call_deferred("move_child", self, parent_node.get_child_count() - 1)


func _on_resume_pressed() -> void:
	_set_pause_state(false)
	#Switch scenes


func _on_options_pressed() -> void:
	oM.visible=true


func _on_quit_pressed() -> void:
	_set_pause_state(false)
	get_tree().change_scene_to_file("res://Master Scenes/titleScreen.tscn")
	
	Global.tutorialchecker = 0
	Global.jumpcounter = 0

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
	Global.fontChoice=index


func _on_text_mode_button_item_focused(index: int) -> void:
	print(index)
	#Global.fontChoice=index
	#print(Global.fontChoice)

func _on_reset_level_button_pressed() -> void:
	var scene_path := ""

	Global.tutorialchecker = 0
	Global.jumpcounter = 0

	if get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path

	if Global.reset_level_to_first_checkpoint(scene_path):
		_reload_current_scene()

func _on_reset_room_button_pressed() -> void:
	var scene_path := ""
	if get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path

	var room_id := _current_room_id()
	if Global.reset_room_to_checkpoint(scene_path, room_id):
		_reload_current_scene()

func _reload_current_scene() -> void:
	_set_pause_state(false)
	get_tree().reload_current_scene()


func _on_check_button_toggled(_button_pressed: bool) -> void:
	pass


func _exit_tree() -> void:
	if _input_owner == self:
		_input_owner = null

func _current_room_id() -> String:
	if not get_tree() or get_tree().current_scene == null:
		return ""

	var room_camera := get_tree().current_scene.get_node_or_null("RoomCamera")
	if room_camera and room_camera.has_method("get_current_target"):
		var current_target: Node2D = room_camera.call("get_current_target") as Node2D
		if current_target:
			return current_target.name

	return ""
