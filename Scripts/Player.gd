extends CharacterBody2D

const SPEED         := 400
const JUMP_VELOCITY := -600

# Stack for wire player is currently hovering, allows for multiple wires
var _pipes_inside: Array[Node] = []


func _ready() -> void:
	set_meta("pipe_traveling", false)


func _physics_process(_delta: float) -> void:
	if get_meta("pipe_traveling", false):
		velocity = Vector2.ZERO
		return

	var input_vector := Vector2.ZERO

	input_vector.x = Input.get_action_strength("ui_right") \
				   - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") \
				   - Input.get_action_strength("ui_up")

	if Input.is_action_pressed("move_left"):
		input_vector.x = -1
	elif Input.is_action_pressed("move_right"):
		input_vector.x = 1
	if Input.is_action_pressed("move_up"):
		input_vector.y = -1
	elif Input.is_action_pressed("move_down"):
		input_vector.y = 1

	var joy := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	if joy.length() > 0.1:
		input_vector = joy

	input_vector = input_vector.normalized()
	velocity.x   = input_vector.x * SPEED

	# ── Jump ──────────────────────────────────────────────────────────────────
	if is_on_floor():
		if Input.is_action_just_pressed("jump") \
		or Input.is_action_just_pressed("move_up") \
		or Input.is_action_just_pressed("ui_up"):
			velocity.y = JUMP_VELOCITY

	velocity.y += 20  # gravity
	move_and_slide()

	# Wire transport
	if Input.is_action_just_pressed("interact"):
		var active := _active_pipe()
		if active and active.has_method("transport"):
			active.transport(self)

#WireEnd callbacks 

## Returns the currently active WireEnd (the most recently entered), or null.
func _active_pipe() -> Node:
	if _pipes_inside.is_empty():
		return null
	return _pipes_inside.back()


## Appends to the stack 
func _on_pipe_entered(pipe_end: Node) -> void:
	if pipe_end not in _pipes_inside:
		_pipes_inside.append(pipe_end)

## Only removes one specific wire — all other overlapping wires stay active.
func _on_pipe_exited(pipe_end: Node) -> void:
	_pipes_inside.erase(pipe_end)
