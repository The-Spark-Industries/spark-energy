extends Node2D

@export var target_path: NodePath
@export var angle_degrees: float = 90.0
@export var duration_seconds: float = 0.6
@export var rotate_once: bool = true

var _activated: bool = false
var _tween: Tween = null

func on_terminal_solved(_terminal: Node = null) -> void:
	if rotate_once and _activated:
		return

	var target := _resolve_target()
	if target == null:
		return

	_activated = true
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var to_rotation := target.rotation_degrees + angle_degrees
	_tween = create_tween()
	_tween.tween_property(target, "rotation_degrees", to_rotation, maxf(duration_seconds, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _resolve_target() -> Node2D:
	if not String(target_path).is_empty():
		return get_node_or_null(target_path) as Node2D
	return self
