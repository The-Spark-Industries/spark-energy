extends CharacterBody2D

@export var SPEED := 25000.0
@export var JUMP_VELOCITY := -75000.0
@export var START_GRAVITY := 6000.0
@export var COYOTE_TIME_MS := 100 # in ms
@export var JUMP_BUFFER_MS := 100 # in ms
@export var JUMP_CUT_MULTIPLIER := 0.4
@export var JUMP_ASCENT_SLOWDOWN := 0.9
@export var JUMP_DURATION_MULTIPLIER := 1.05
@export var AIR_HANG_MULTIPLIER := 0.95
@export var AIR_HANG_THRESHOLD := 5.0
@export var Y_SMOOTHING := 0.8
@export var AIR_X_SMOOTHING := 0.10
@export var MAX_FALL_SPEED := 60000.0
@export var GROUND_ACCEL := 4000.0
@export var GROUND_DECEL := 10000.0
@export var AIR_DECEL := 4500.0
@export var AIR_COAST_DECEL := 1400.0
@export var AIR_TURN_ACCEL := 3500.0

# --- State & Internal Variables ---
enum States { IDLE, RUN, JUMP, AIR, DEAD }
var state: States = States.AIR

var prev_velocity := Vector2.ZERO
var last_floor_msec := 0
var last_jump_queue_msec := 0
var current_gravity := START_GRAVITY
var has_boots := false
var _jump_arc_active := false
var _coyote_jump_available := false

# Stack for wire player is currently hovering [cite: 5]
var _pipes_inside: Array[Node] = []

## When true, the player can walk on water and will have a short grace period before dying.
@export var can_walk_on_water: bool = false
## How long the player can be on water before dying when can_walk_on_water is true (seconds).
@export var water_grace_duration: float = 0.5

var _water_overlap_count: int = 0
var _water_death_timer: Timer
## Tracks whether the water-walk grace has been used this life (one touch allowed per respawn).
var _water_walk_used: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animPlayer: AnimationPlayer = get_node_or_null("AnimationPlayer")

func _ready() -> void:
	set_meta("pipe_traveling", false)
	set_meta("tag", "player")

	var scene_path := ""
	if get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path

	if Global.has_checkpoint_for_scene(scene_path):
		global_position = Global.last_checkpoint_position
	else:
		Global.set_checkpoint(global_position, scene_path)

	_water_death_timer = Timer.new()
	_water_death_timer.one_shot = true
	_water_death_timer.wait_time = water_grace_duration
	_water_death_timer.timeout.connect(_on_water_death_timeout)
	add_child(_water_death_timer)

func _physics_process(delta: float) -> void:
	if get_meta("pipe_traveling", false):
		velocity = Vector2.ZERO
		return

	var direction = Input.get_axis("ui_left", "ui_right")
	
	# Update Floor/Coyote Timing
	if is_on_floor():
		last_floor_msec = Time.get_ticks_msec()
		_coyote_jump_available = true
	elif state != States.JUMP and state != States.AIR and state != States.DEAD:
		state = States.AIR
		if sprite: sprite.play("fall")

	match state:
		States.JUMP:
			var jump_time_scale := maxf(JUMP_DURATION_MULTIPLIER, 0.01)
			_jump_arc_active = true
			velocity.y = (JUMP_VELOCITY * JUMP_ASCENT_SLOWDOWN / jump_time_scale) * delta
			if sprite: sprite.play("jump")
			if animPlayer:
				animPlayer.stop()
				animPlayer.play("jump")
			state = States.AIR

		States.AIR:
			if is_on_floor():
				state = States.IDLE
				_jump_arc_active = false
				if animPlayer: animPlayer.play("land")
			
			# Variable Jump Height [cite: 6]
			if Input.is_action_just_released("jump") or Input.is_action_just_released("ui_up"):
				velocity.y *= JUMP_CUT_MULTIPLIER
			
			_apply_run_logic(direction, delta)
			
			# Jump Input (with Coyote Time)
			if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_up"):
				if _coyote_jump_available and Time.get_ticks_msec() - last_floor_msec < COYOTE_TIME_MS:
					state = States.JUMP
					_coyote_jump_available = false
				else:
					last_jump_queue_msec = Time.get_ticks_msec()
			
			# Gravity & Air Hang Peak Logic
			var gravity_to_apply := current_gravity
			if _jump_arc_active:
				var jump_time_scale := maxf(JUMP_DURATION_MULTIPLIER, 0.01)
				gravity_to_apply /= jump_time_scale * jump_time_scale
			if velocity.y < 0.0:
				gravity_to_apply *= JUMP_ASCENT_SLOWDOWN
			velocity.y += gravity_to_apply * delta
			if abs(velocity.y) < AIR_HANG_THRESHOLD:
				current_gravity *= AIR_HANG_MULTIPLIER
			else:
				current_gravity = START_GRAVITY

		States.IDLE:
			if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_up") or (Time.get_ticks_msec() - last_jump_queue_msec < JUMP_BUFFER_MS):
				state = States.JUMP
				_coyote_jump_available = false
				last_jump_queue_msec = 0
			else:
				_apply_run_logic(direction, delta)
				if sprite:
					sprite.scale.x = 1
					sprite.play("idle")
				if direction != 0:
					state = States.RUN

		States.RUN:
			if sprite: sprite.play("run")
			_apply_run_logic(direction, delta)
			
			if direction == 0:
				state = States.IDLE
			# Ensure jump works during run too
			elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_up"):
				state = States.JUMP
				_coyote_jump_available = false

	# Final Smoothing and Terminal Velocity
	velocity.y = lerp(prev_velocity.y, velocity.y, Y_SMOOTHING)
	velocity.y = min(velocity.y, MAX_FALL_SPEED)
	
	prev_velocity = velocity
	move_and_slide()

	# Wire transport [cite: 7]
	if Input.is_action_just_pressed("interact"):
		var active := _active_pipe()
		if active and active.has_method("transport"):
			active.transport(self)

func _apply_run_logic(direction: float, delta: float) -> void:
	var target_speed := SPEED * direction * delta
	var accel := GROUND_ACCEL

	if is_on_floor():
		if direction == 0.0:
			accel = GROUND_DECEL
	else:
		if direction == 0.0:
			accel = AIR_COAST_DECEL
		elif signf(direction) != signf(velocity.x) and absf(velocity.x) > 0.01:
			accel = AIR_TURN_ACCEL
		else:
			accel = GROUND_ACCEL

	velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	if direction != 0 and sprite:
		sprite.flip_h = direction < 0

# --- Wire/Pipe Callbacks [cite: 7, 8] ---

func _active_pipe() -> Node:
	if _pipes_inside.is_empty():
		return null
	return _pipes_inside.back()

func _on_pipe_entered(pipe_end: Node) -> void:
	if pipe_end not in _pipes_inside:
		_pipes_inside.append(pipe_end)

func _on_pipe_exited(pipe_end: Node) -> void:
	_pipes_inside.erase(pipe_end)

func entered_water() -> void:
	if state == States.DEAD:
		return

	_water_overlap_count += 1

	if _water_overlap_count == 1:
		if can_walk_on_water and not _water_walk_used:
			_water_walk_used = true
			_water_death_timer.wait_time = water_grace_duration
			_water_death_timer.start()
		else:
			die()

func exited_water() -> void:
	if _water_overlap_count > 0:
		_water_overlap_count -= 1

	if _water_overlap_count == 0 and _water_death_timer:
		_water_death_timer.stop()

func _on_water_death_timeout() -> void:
	die()

func die() -> void:
	state = States.DEAD
	velocity = Vector2.ZERO
	if sprite:
		sprite.stop()
		sprite.play("dead")
	get_tree().create_timer(0.2).timeout.connect(_respawn, CONNECT_ONE_SHOT)

func _respawn() -> void:
	global_position = Global.last_checkpoint_position
	velocity = Vector2.ZERO
	state = States.IDLE
	_jump_arc_active = false
	current_gravity = START_GRAVITY
	_water_overlap_count = 0
	_water_walk_used = false
	if _water_death_timer and _water_death_timer.time_left > 0.0:
		_water_death_timer.stop()
	if sprite:
		sprite.play("idle")
