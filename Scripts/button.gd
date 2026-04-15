extends Area2D


var readyToPress: bool= false
#Checks if the player is near the button
@onready var buttonstatus: int = 0
#Determines the on/off state 

@export_group("Button Outputs")
@export var output_target_paths: Array[NodePath] = []
@export var output_method: StringName = &"activate"
@export var output_fallback_methods: Array[StringName] = [&"power_on", &"on_terminal_solved", &"activate", &"trigger", &"start"]

@onready var buttonchange= $buttonSprites
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# # Changes the sprite to whatever the button status is.
func _process(delta: float) -> void:
	buttonchange.frame=buttonstatus
	
		


func _input(event: InputEvent) -> void:
	if (Input.is_action_just_pressed("interact")) and (readyToPress==true):
		buttonstatus=1
		_trigger_outputs()
		await get_tree().create_timer(0.5).timeout
		buttonstatus=0

func _trigger_outputs() -> void:
	for target_path in output_target_paths:
		if String(target_path).is_empty():
			continue

		var target := get_node_or_null(target_path)
		if target == null:
			continue

		if _call_output_method(target, output_method):
			continue

		for fallback_method in output_fallback_methods:
			if fallback_method == output_method:
				continue
			if _call_output_method(target, fallback_method):
				break

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
	if (body is CharacterBody2D):
		readyToPress= true

func _on_body_exited(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= false
