extends Node2D

signal player_landed
signal player_left

enum MotionMode {
	NONE,
	HORIZONTAL,
	VERTICAL
}

enum InitialDirection {
	POSITIVE,
	NEGATIVE
}

var _player_on_platform: bool = false
var _player_body: CharacterBody2D = null
var _prev_position: Vector2 = Vector2.ZERO
var _platform_velocity: Vector2 = Vector2.ZERO
var _platform_body: StaticBody2D = null
var _start_position: Vector2 = Vector2.ZERO
var _motion_direction: float = 1.0
var _solve_motion_started: bool = false
var _solve_motion_tween: Tween = null

## Friction coefficient when platform moves down (0-1, higher = more friction)
@export var descent_friction: float = 0.85
@export_group("Auto Motion")
@export var motion_mode: MotionMode = MotionMode.NONE
@export_range(0.0, 5000.0, 1.0) var motion_distance: float = 180.0
@export_range(0.0, 5000.0, 1.0) var motion_speed: float = 120.0
@export var initial_direction: InitialDirection = InitialDirection.POSITIVE
@export_group("Solved Trigger Motion")
@export var solved_motion_enabled: bool = false
@export var solved_motion_mode: MotionMode = MotionMode.VERTICAL
@export_range(0.0, 5000.0, 1.0) var solved_motion_distance: float = 0.0
@export_range(0.01, 60.0, 0.01) var solved_motion_duration: float = 2.0
@export var solved_motion_return_to_start: bool = true
@export var solved_motion_loop: bool = false

func _ready() -> void:
	_start_position = position
	_configure_initial_motion_state()
	_prev_position = global_position
	process_physics_priority = -10
	_platform_body = get_node_or_null("PlatformBody") as StaticBody2D
	if _platform_body == null:
		_platform_body = get_node_or_null("StaticBody2D") as StaticBody2D
	var area := $Area2D as Area2D
	if area:
		area.body_entered.connect(_on_area_body_entered)
		area.body_exited.connect(_on_area_body_exited)

func _configure_initial_motion_state() -> void:
	_motion_direction = 1.0 if initial_direction == InitialDirection.POSITIVE else -1.0

	if motion_mode == MotionMode.NONE or motion_distance <= 0.0:
		return

	if initial_direction == InitialDirection.NEGATIVE:
		var axis := Vector2.RIGHT if motion_mode == MotionMode.HORIZONTAL else Vector2.DOWN
		position = _start_position + axis * motion_distance

func _physics_process(delta: float) -> void:
	if motion_mode != MotionMode.NONE:
		_update_auto_motion(delta)

	# Calculate platform velocity
	_platform_velocity = (global_position - _prev_position) / delta if delta > 0 else Vector2.ZERO
	_prev_position = global_position

	# Let CharacterBody2D inherit platform motion through move_and_slide.
	if _platform_body != null:
		_platform_body.constant_linear_velocity = _platform_velocity

func _update_auto_motion(delta: float) -> void:
	if motion_distance <= 0.0 or motion_speed <= 0.0:
		position = _start_position
		return

	var axis := Vector2.RIGHT if motion_mode == MotionMode.HORIZONTAL else Vector2.DOWN
	var min_pos := _start_position
	var max_pos := _start_position + axis * motion_distance

	position += axis * _motion_direction * motion_speed * delta

	if motion_mode == MotionMode.HORIZONTAL:
		if position.x >= max_pos.x:
			position.x = max_pos.x
			_motion_direction = -1.0
		elif position.x <= min_pos.x:
			position.x = min_pos.x
			_motion_direction = 1.0
	else:
		if position.y >= max_pos.y:
			position.y = max_pos.y
			_motion_direction = -1.0
		elif position.y <= min_pos.y:
			position.y = min_pos.y
			_motion_direction = 1.0

func _on_area_body_entered(body: Node2D) -> void:
	# Check multiple conditions to detect the player
	if body.name == "Player" or body.is_in_group("player") or (body.script and body.script.resource_path.contains("Player")):
		print("Player detected on platform: ", body.name)
		_player_on_platform = true
		_player_body = body as CharacterBody2D
		player_landed.emit()

func _on_area_body_exited(body: Node2D) -> void:
	# Check if it's the player leaving
	if body.name == "Player" or body.is_in_group("player") or (body.script and body.script.resource_path.contains("Player")):
		print("Player left platform: ", body.name)
		_player_on_platform = false
		if body == _player_body:
			_player_body = null
		player_left.emit()

func is_player_on_platform() -> bool:
	return _player_on_platform and _player_body != null and is_instance_valid(_player_body)

func get_player_on_platform() -> CharacterBody2D:
	if _player_body != null and is_instance_valid(_player_body):
		return _player_body
	return null

func on_terminal_solved(_terminal: Node = null) -> void:
	power_on(_terminal)

func activate(_source: Node = null) -> void:
	power_on(_source)

func trigger(_source: Node = null) -> void:
	power_on(_source)

func start() -> void:
	power_on()

func power_on(_source: Node = null) -> void:
	_start_solved_motion_if_needed()

func _start_solved_motion_if_needed() -> void:
	if _solve_motion_started:
		return
	if not solved_motion_enabled:
		return
	if solved_motion_mode == MotionMode.NONE:
		return
	if solved_motion_distance <= 0.0:
		return

	_solve_motion_started = true
	motion_mode = MotionMode.NONE

	if _solve_motion_tween != null and _solve_motion_tween.is_valid():
		_solve_motion_tween.kill()

	var axis := Vector2.RIGHT if solved_motion_mode == MotionMode.HORIZONTAL else Vector2.UP
	var start_pos := position
	var end_pos := start_pos + axis * solved_motion_distance

	_solve_motion_tween = create_tween()
	_solve_motion_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_solve_motion_tween.tween_property(self, "position", end_pos, solved_motion_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if solved_motion_loop:
		_solve_motion_tween.tween_callback(_start_solved_motion_loop.bind(start_pos, end_pos))
	elif solved_motion_return_to_start:
		_solve_motion_tween.tween_property(self, "position", start_pos, solved_motion_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_solved_motion_loop(start_pos: Vector2, end_pos: Vector2) -> void:
	if not is_inside_tree():
		return

	if _solve_motion_tween != null and _solve_motion_tween.is_valid():
		_solve_motion_tween.kill()

	_solve_motion_tween = create_tween()
	_solve_motion_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_solve_motion_tween.set_loops()
	_solve_motion_tween.tween_property(self, "position", start_pos, solved_motion_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_solve_motion_tween.tween_property(self, "position", end_pos, solved_motion_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
