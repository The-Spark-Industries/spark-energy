extends Node

@export var target_path: NodePath
@export var angle_degrees: float = 45.0
@export var half_cycle_seconds: float = 3.0

var _started: bool = false
var _loop_tween: Tween = null

func on_terminal_solved(_terminal: Node = null) -> void:
	if _started:
		return
	_started = true
	_start_loop()

func _start_loop() -> void:
	var target := get_node_or_null(target_path) as Node2D
	if target == null:
		return

	if _loop_tween != null and _loop_tween.is_valid():
		_loop_tween.kill()

	var base_rotation := target.rotation_degrees
	_loop_tween = create_tween()
	_loop_tween.set_loops()
	_loop_tween.tween_property(target, "rotation_degrees", base_rotation + angle_degrees, half_cycle_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop_tween.tween_property(target, "rotation_degrees", base_rotation, half_cycle_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
