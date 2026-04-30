extends Control

static var _input_owner: Node = null

@onready var oM =$optionsMenu
@onready var _ambience_bus_idx: int = AudioServer.get_bus_index("Ambience")

var _ambience_muted_by_pause_menu: bool = false
var _ambience_previous_mute_state: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.theme=load("res://Assets/Visual/Lingua.tres")

	if not get_parent() is CanvasLayer:
		call_deferred("_setup_canvas_layer")

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_input(true)
	set_process_unhandled_input(true)

	visible = false
	oM.visible = false
	call_deferred("_bring_to_front")
	z_index = 200

func _setup_canvas_layer() -> void:
	if not get_parent() is CanvasLayer:
		var cl := CanvasLayer.new()
		cl.layer = 200
		get_tree().current_scene.add_child(cl)
		reparent(cl, false)

func _exit_tree() -> void:
	_restore_ambience_if_needed()
	if _input_owner == self:
		_input_owner = null

func _process(delta: float) -> void:
	if (Global.fontChoice==0):
		self.theme=load("res://Assets/Visual/Lingua.tres")
	if (Global.fontChoice==1):
		self.theme=load("res://Assets/Visual/lingualight.tres")
	if (Global.fontChoice==2):
		self.theme=load("res://Assets/Visual/Receipt.tres")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _input(event: InputEvent) -> void:
	_handle_pause_input(event)

func _unhandled_input(event: InputEvent) -> void:
	_handle_pause_input(event)

func _handle_pause_input(event: InputEvent) -> void:
	if Global.wiremode or Global.minigame_active:
		return

	if event.is_action_pressed("pause") and not event.is_echo() and (Global.wiremode == false) and (Global.minigame_active == false):
		if (Global.tutorialchecker == 2):
			Global.tutorialchecker = 3

	if Global.tutorialchecker == 2:
		Global.tutorialchecker = 3

	_set_pause_state(not get_tree().paused)
	get_viewport().set_input_as_handled()

func _is_pause_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
				return true

	if event.is_action_pressed("pause") and not event.is_echo():
		return true

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		return true

	return false


func _set_pause_state(paused: bool) -> void:
	if paused:
		_bring_to_front()
		get_tree().paused = true
		oM.visible = false
		visible = true
		_set_ambience_paused_for_menu(true)
	else:
		get_tree().paused = false
		visible = false
		oM.visible = false
		_set_ambience_paused_for_menu(false)


func _bring_to_front() -> void:
	pass


func _on_resume_pressed() -> void:
	get_tree().paused = false
	visible = false
	_set_ambience_paused_for_menu(false)
	#Switch scenes


func _on_options_pressed() -> void:
	_show_options_menu()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	_set_ambience_paused_for_menu(false)
	get_tree().change_scene_to_file("res://Master Scenes/titleScreen.tscn")
	
	Global.tutorialchecker = 0
	Global.jumpcounter = 0

func _on_back_button_pressed() -> void:
	oM.visible=false

func _show_options_menu() -> void:
	var viewport_size := get_viewport_rect().size
	# Keep legacy option children on-screen even if their authored offsets are negative.
	oM.position = Vector2(viewport_size.x * 0.5, viewport_size.y + 120.0)
	oM.z_index = z_index + 1
	oM.visible = true
	oM.move_to_front()

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
	get_tree().paused = false
	visible = false
	oM.visible = false
	_set_ambience_paused_for_menu(false)
	

func _set_ambience_paused_for_menu(paused_for_menu: bool) -> void:
	if _ambience_bus_idx < 0:
		return

	if paused_for_menu:
		if _ambience_muted_by_pause_menu:
			return
		_ambience_previous_mute_state = AudioServer.is_bus_mute(_ambience_bus_idx)
		AudioServer.set_bus_mute(_ambience_bus_idx, true)
		_ambience_muted_by_pause_menu = true
		return

	_restore_ambience_if_needed()

func _restore_ambience_if_needed() -> void:
	if _ambience_bus_idx < 0:
		return
	if not _ambience_muted_by_pause_menu:
		return
	AudioServer.set_bus_mute(_ambience_bus_idx, _ambience_previous_mute_state)
	_ambience_muted_by_pause_menu = false

func _current_room_id() -> String:
	if not get_tree() or get_tree().current_scene == null:
		return ""

	var room_camera := get_tree().current_scene.get_node_or_null("RoomCamera")
	if room_camera and room_camera.has_method("get_current_target"):
		var current_target: Node2D = room_camera.call("get_current_target") as Node2D
		if current_target:
			return current_target.name

	return ""
