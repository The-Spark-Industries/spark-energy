extends Area2D

var readyToPress: bool= false
#Checks if the player is near the lever
@onready var leverstatus: int = 0
#Determines the on/off state 

@export_group("Lever Actions")
@export var waterfall_path: NodePath
@export var lift_target_path: NodePath
@export var wheel_target_path: NodePath
@export var lift_pixels: float = 96.0
@export_range(0.1, 10.0, 0.1) var lift_duration: float = 2.4
@export var output_target_paths: Array[NodePath] = []
@export var output_target_groups: Array[StringName] = []
@export var output_on_method: StringName = &"activate"
@export var output_off_method: StringName = &"deactivate"
@export var output_on_fallback_methods: Array[StringName] = [&"power_on", &"on_terminal_solved", &"activate", &"trigger", &"start"]
@export var output_off_fallback_methods: Array[StringName] = [&"power_off", &"deactivate", &"stop", &"stop_spin", &"disable"]
@export var lift_loop: bool = false
@export var single_use : bool =false

var _triggered_once: bool = false
var _lift_tween: Tween = null

@onready var change= $leverSprites
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if has_node("Prompt"):
		$Prompt.visible = false
	$Prompt.theme=load("res://Assets/Visual/Lingua.tres")



# # Changes the sprite to whatever the lever status is.
func _process(delta: float) -> void:
	change.frame=leverstatus

	if (Global.fontChoice==0):
		$Prompt.theme=load("res://Assets/Visual/Lingua.tres")
	if (Global.fontChoice==1):
		$Prompt.theme=load("res://Assets/Visual/lingualight.tres")
	if (Global.fontChoice==2):
		$Prompt.theme=load("res://Assets/Visual/Receipt.tres")


func _input(event: InputEvent) -> void:
	if (Input.is_action_just_pressed("interact")) and (readyToPress==true):
		if (leverstatus==0):
			leverstatus=1
			_apply_configured_actions()
			_play_lever_sound()
		elif (leverstatus==1):
			if (single_use==false):
				_revert_configured_actions()
				$"leverSound".play()
				leverstatus=0

			

func _play_lever_sound() -> void:
	var sfx := get_node_or_null("leverSound") as AudioStreamPlayer
	if sfx == null:
		sfx = get_node_or_null("leverSound2") as AudioStreamPlayer
	if sfx:
		sfx.play()

func _apply_configured_actions() -> void:
	_trigger_wheel_spin()
	_trigger_outputs(true)

	if _triggered_once:
		return

	if not String(waterfall_path).is_empty():
		var waterfall := get_node_or_null(waterfall_path) as CanvasItem
		if waterfall:
			waterfall.visible = true

	if not String(lift_target_path).is_empty() and not is_zero_approx(lift_pixels):
		var lift_target := get_node_or_null(lift_target_path) as Node2D
		if lift_target:
			if _lift_tween and _lift_tween.is_valid():
				_lift_tween.kill()
			var start_y := lift_target.position.y
			_lift_tween = create_tween()
			_lift_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			if lift_loop:
				_lift_tween.set_loops()
				_lift_tween.tween_property(lift_target, "position:y", start_y - lift_pixels, lift_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				_lift_tween.tween_property(lift_target, "position:y", start_y, lift_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			else:
				_lift_tween.tween_property(lift_target, "position:y", start_y - lift_pixels, lift_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_triggered_once = true

func _revert_configured_actions() -> void:
	_stop_wheel_spin()
	_trigger_outputs(false)

	if not String(waterfall_path).is_empty():
		var waterfall := get_node_or_null(waterfall_path) as CanvasItem
		if waterfall:
			waterfall.visible = false

	if _lift_tween and _lift_tween.is_valid():
		_lift_tween.kill()
		_lift_tween = null

func _trigger_wheel_spin() -> void:
	var wheel: Node = null
	if not String(wheel_target_path).is_empty():
		wheel = get_node_or_null(wheel_target_path)

	if wheel == null:
		# Fallback for scene variants where the export path was not set.
		wheel = get_tree().current_scene.get_node_or_null("waterWheelRoom11")

	if wheel == null:
		return

	if wheel.has_method("start_spin"):
		wheel.call("start_spin")
		return
	if wheel.has_method("_start_spin"):
		wheel.call("_start_spin")

func _stop_wheel_spin() -> void:
	var wheel: Node = null
	if not String(wheel_target_path).is_empty():
		wheel = get_node_or_null(wheel_target_path)

	if wheel == null:
		# Fallback for scene variants where the export path was not set.
		wheel = get_tree().current_scene.get_node_or_null("waterWheelRoom11")

	if wheel == null:
		return

	if wheel.has_method("stop_spin"):
		wheel.call("stop_spin")
		return
	if wheel.has_method("stop"):
		wheel.call("stop")

func _trigger_outputs(is_on: bool) -> void:
	var called_nodes := {}

	for target_path in output_target_paths:
		if String(target_path).is_empty():
			continue

		var target := get_node_or_null(target_path)
		if target == null:
			continue

		var target_id := target.get_instance_id()
		if called_nodes.has(target_id):
			continue
		called_nodes[target_id] = true

		_trigger_single_output(target, is_on)

	for group_name in output_target_groups:
		var group_name_str := String(group_name)
		if group_name_str.is_empty():
			continue

		for target in get_tree().get_nodes_in_group(group_name_str):
			if target == null:
				continue

			var target_id := target.get_instance_id()
			if called_nodes.has(target_id):
				continue
			called_nodes[target_id] = true

			_trigger_single_output(target, is_on)

func _trigger_single_output(target: Object, is_on: bool) -> void:
	var primary_method := output_on_method if is_on else output_off_method
	if _call_output_method(target, primary_method):
		return

	var fallbacks := output_on_fallback_methods if is_on else output_off_fallback_methods
	for fallback_method in fallbacks:
		if fallback_method == primary_method:
			continue
		if _call_output_method(target, fallback_method):
			return

func _call_output_method(target: Object, method_name: StringName) -> bool:
	var method_str := String(method_name)
	if method_str.is_empty() or not target.has_method(method_str):
		return false

	var arg_count := -1
	for method_info in target.get_method_list():
		if String(method_info.get("name", "")) == method_str:
			var args = method_info.get("args", [])
			if args is Array:
				arg_count = args.size()
			break

	if arg_count == 0:
		target.call(method_str)
	elif arg_count == 1:
		target.call(method_str, self)
	else:
		target.call(method_str, self, self)

	return true
		


func _on_body_entered(body: Node2D) -> void:
	if (body is CharacterBody2D) and (Global.tutorialchecker<3) and (leverstatus==1 and single_use==false):
		readyToPress= true
		if has_node("Prompt"):
			$Prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= false
		if has_node("Prompt"):
			$Prompt.visible = false
