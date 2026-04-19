extends Node2D

@export var enable_spin: bool = false
@export_range(0.1, 20.0, 0.1) var spin_time_per_turn: float = 7.0
@export var spin_clockwise: bool = true
@export var enable_oscillation: bool = false
@export_range(0.05, 10.0, 0.05) var rotation_duration: float = 0.8
@export var oscillation_angle_degrees: float = 90.0
@export_range(0.0, 5.0, 0.05) var pause_between_swaps: float = 0.7

var _base_rotation: float
var _oscillation_tween: Tween
var _spin_tween: Tween

func _ready() -> void:
	_base_rotation = rotation
	if enable_spin:
		start_spin()
	elif enable_oscillation:
		_start_oscillation()

func start_spin() -> void:
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()

	var direction := -1.0 if spin_clockwise else 1.0
	_spin_tween = create_tween()
	_spin_tween.set_loops()
	_spin_tween.tween_property(self, "rotation", direction * TAU, spin_time_per_turn).as_relative().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	
	$"WaterWheelNoise".play()

func stop_spin() -> void:
	if _spin_tween and _spin_tween.is_valid():
		_spin_tween.kill()
		_spin_tween = null
		
	$"WaterWheelNoise".stop()

func _start_oscillation() -> void:
	if _oscillation_tween and _oscillation_tween.is_valid():
		_oscillation_tween.kill()
		
	$"WaterWheelNoise".play()

	var left_rotation := _base_rotation - deg_to_rad(oscillation_angle_degrees)

	_oscillation_tween = create_tween()
	_oscillation_tween.set_loops()
	_oscillation_tween.tween_property(self, "rotation", left_rotation, rotation_duration)
	_oscillation_tween.tween_callback(func(): $WaterWheelNoise.stream_paused = true)
	if pause_between_swaps > 0.0:
		_oscillation_tween.tween_interval(pause_between_swaps)
	_oscillation_tween.tween_callback(func(): $WaterWheelNoise.stream_paused = false)
	_oscillation_tween.tween_property(self, "rotation", _base_rotation, rotation_duration)
	_oscillation_tween.tween_callback(func(): $WaterWheelNoise.stream_paused = true)
	if pause_between_swaps > 0.0:
		_oscillation_tween.tween_interval(pause_between_swaps)
	_oscillation_tween.tween_callback(func(): $WaterWheelNoise.stream_paused = false)
