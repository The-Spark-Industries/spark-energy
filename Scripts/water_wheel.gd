extends Node2D

@export var enable_oscillation: bool = false
@export_range(0.05, 10.0, 0.05) var rotation_duration: float = 0.8
@export var oscillation_angle_degrees: float = 90.0
@export_range(0.0, 5.0, 0.05) var pause_between_swaps: float = 0.7

var _base_rotation: float
var _oscillation_tween: Tween

func _ready() -> void:
	_base_rotation = rotation
	if enable_oscillation:
		_start_oscillation()

func _start_oscillation() -> void:
	if _oscillation_tween and _oscillation_tween.is_valid():
		_oscillation_tween.kill()

	var left_rotation := _base_rotation - deg_to_rad(oscillation_angle_degrees)

	_oscillation_tween = create_tween()
	_oscillation_tween.set_loops()
	_oscillation_tween.tween_property(self, "rotation", left_rotation, rotation_duration)
	if pause_between_swaps > 0.0:
		_oscillation_tween.tween_interval(pause_between_swaps)
	_oscillation_tween.tween_property(self, "rotation", _base_rotation, rotation_duration)
	if pause_between_swaps > 0.0:
		_oscillation_tween.tween_interval(pause_between_swaps)
