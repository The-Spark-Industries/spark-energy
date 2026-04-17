extends Node2D

signal player_landed
signal player_left

enum MotionMode {
	NONE,
	HORIZONTAL,
	VERTICAL,
	DIRECTION_SEQUENCE
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
var _auto_motion_elapsed: float = 0.0
var _auto_motion_started: bool = false
var _sequence_step_index: int = 0
var _sequence_step_progress: float = 0.0
var _solve_motion_started: bool = false
var _solve_motion_tween: Tween = null

## Friction coefficient when platform moves down (0-1, higher = more friction)
@export var descent_friction: float = 0.85
@export_group("Auto Motion")
@export var motion_mode: MotionMode = MotionMode.NONE
@export_range(0.0, 5000.0, 1.0) var motion_distance: float = 180.0
@export_range(0.0, 5000.0, 1.0) var motion_speed: float = 120.0
@export_range(0.0, 10.0, 0.01) var auto_motion_start_delay: float = 0.0
@export var initial_direction: InitialDirection = InitialDirection.POSITIVE
@export_group("Direction Sequence (Auto Motion)")
@export_range(0.0, 5000.0, 1.0) var sequence_right_distance: float = 0.0
@export_range(0.0, 5000.0, 1.0) var sequence_down_distance: float = 0.0
@export_range(0.0, 5000.0, 1.0) var sequence_up_distance: float = 0.0
@export_range(0.0, 5000.0, 1.0) var sequence_left_distance: float = 0.0
@export_group("Solved Trigger Motion")
@export var solved_motion_enabled: bool = false
@export var solved_motion_mode: MotionMode = MotionMode.VERTICAL
@export_range(0.0, 5000.0, 1.0) var solved_motion_distance: float = 0.0
@export_range(0.01, 60.0, 0.01) var solved_motion_duration: float = 2.0
@export_range(0.0, 10.0, 0.01) var solved_motion_pause_at_turn: float = 0.0
@export var solved_motion_return_to_start: bool = true
@export var solved_motion_loop: bool = false
@export_group("Child Follow")
@export var move_top_level_children_with_platform: bool = true

func _ready() -> void:
	_start_position = position
	_configure_initial_motion_state()
	_auto_motion_elapsed = 0.0
	_auto_motion_started = auto_motion_start_delay <= 0.0
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
	_sequence_step_index = 0
	_sequence_step_progress = 0.0

func _physics_process(delta: float) -> void:
	if motion_mode != MotionMode.NONE:
		if _auto_motion_started:
			_update_auto_motion(delta)
		else:
			_auto_motion_elapsed += delta
			if _auto_motion_elapsed >= auto_motion_start_delay:
				_auto_motion_started = true

	# Calculate platform velocity
	var delta_motion := global_position - _prev_position
	_platform_velocity = delta_motion / delta if delta > 0 else Vector2.ZERO
	_move_top_level_children(delta_motion)
	_prev_position = global_position

	# Let CharacterBody2D inherit platform motion through move_and_slide.
	if _platform_body != null:
		_platform_body.constant_linear_velocity = _platform_velocity

func _move_top_level_children(delta_motion: Vector2) -> void:
	if not move_top_level_children_with_platform:
		return
	if is_zero_approx(delta_motion.x) and is_zero_approx(delta_motion.y):
		return

	for child in get_children():
		if not (child is Node2D):
			continue
		var node2d := child as Node2D
		if node2d.top_level:
			node2d.global_position += delta_motion

func _update_auto_motion(delta: float) -> void:
	if motion_mode == MotionMode.DIRECTION_SEQUENCE:
		_update_direction_sequence_motion(delta)
		return

	if motion_distance <= 0.0 or motion_speed <= 0.0:
		position = _start_position
		return

	var axis := Vector2.RIGHT if motion_mode == MotionMode.HORIZONTAL else Vector2.DOWN
	var configured_sign := 1.0 if initial_direction == InitialDirection.POSITIVE else -1.0
	var signed_distance := motion_distance * configured_sign
	var min_travel := minf(0.0, signed_distance)
	var max_travel := maxf(0.0, signed_distance)
	var travel := (position - _start_position).dot(axis)

	travel += _motion_direction * motion_speed * delta

	if travel >= max_travel:
		travel = max_travel
		_motion_direction = -1.0
	elif travel <= min_travel:
		travel = min_travel
		_motion_direction = 1.0

	position = _start_position + axis * travel

func _update_direction_sequence_motion(delta: float) -> void:
	if motion_speed <= 0.0:
		return

	var points := _sequence_points()
	if points.size() < 5:
		return

	var remaining := motion_speed * delta
	var iterations := 0
	while remaining > 0.0 and iterations < 12:
		iterations += 1
		var from_point := points[_sequence_step_index]
		var to_point := points[_sequence_step_index + 1]
		var segment := to_point - from_point
		var segment_len := segment.length()

		if segment_len <= 0.0001:
			_advance_sequence_step()
			continue

		var segment_dir := segment / segment_len
		var segment_remaining := segment_len - _sequence_step_progress
		var consume := minf(remaining, segment_remaining)

		_sequence_step_progress += consume
		remaining -= consume
		position = from_point + segment_dir * _sequence_step_progress

		if _sequence_step_progress >= segment_len - 0.0001:
			position = to_point
			_advance_sequence_step()

func _sequence_points() -> Array[Vector2]:
	var p0 := _start_position
	var p1 := p0 + Vector2.RIGHT * sequence_right_distance
	var p2 := p1 + Vector2.DOWN * sequence_down_distance
	var p3 := p2 + Vector2.UP * sequence_up_distance
	var p4 := p3 + Vector2.LEFT * sequence_left_distance
	return [p0, p1, p2, p3, p4]

func _advance_sequence_step() -> void:
	_sequence_step_progress = 0.0
	_sequence_step_index += 1
	if _sequence_step_index > 3:
		_sequence_step_index = 0

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
		if solved_motion_pause_at_turn > 0.0:
			_solve_motion_tween.tween_interval(solved_motion_pause_at_turn)
		_solve_motion_tween.tween_callback(_start_solved_motion_loop.bind(start_pos, end_pos, solved_motion_pause_at_turn))
	elif solved_motion_return_to_start:
		if solved_motion_pause_at_turn > 0.0:
			_solve_motion_tween.tween_interval(solved_motion_pause_at_turn)
		_solve_motion_tween.tween_property(self, "position", start_pos, solved_motion_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_solved_motion_loop(start_pos: Vector2, end_pos: Vector2, pause_at_turn: float) -> void:
	if not is_inside_tree():
		return

	if _solve_motion_tween != null and _solve_motion_tween.is_valid():
		_solve_motion_tween.kill()

	_solve_motion_tween = create_tween()
	_solve_motion_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_solve_motion_tween.set_loops()
	if pause_at_turn > 0.0:
		_solve_motion_tween.tween_interval(pause_at_turn)
	_solve_motion_tween.tween_property(self, "position", start_pos, solved_motion_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if pause_at_turn > 0.0:
		_solve_motion_tween.tween_interval(pause_at_turn)
	_solve_motion_tween.tween_property(self, "position", end_pos, solved_motion_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
