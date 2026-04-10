extends Node2D

## Attach to any world object that should release water after a terminal is solved.
@export_group("Water Flow")
@export var stream_node_path: NodePath
@export var wheel_node_path: NodePath
@export var water_to_wheel_delay: float = 0.25
@export var wheel_spin_time_per_turn: float = 0.6

var _activated: bool = false

func on_terminal_solved(_terminal: Node = null) -> void:
	start_water_dispense(_terminal)

func start_water_dispense(_terminal: Node = null) -> void:
	if _activated:
		return
	_activated = true

	if not String(stream_node_path).is_empty():
		_set_flow_visual_active(get_node_or_null(stream_node_path), true)

	if not String(wheel_node_path).is_empty():
		if water_to_wheel_delay > 0.0:
			await get_tree().create_timer(water_to_wheel_delay).timeout
		_start_wheel_spin(get_node_or_null(wheel_node_path))

func _set_flow_visual_active(node: Node, active: bool) -> void:
	if node == null:
		return

	if node is CanvasItem:
		(node as CanvasItem).visible = active

	if node is GPUParticles2D:
		(node as GPUParticles2D).emitting = active
	elif node is CPUParticles2D:
		(node as CPUParticles2D).emitting = active

	if node.has_node("FlowAnimation"):
		var flow_anim := node.get_node("FlowAnimation") as AnimationPlayer
		if flow_anim:
			if active and flow_anim.has_animation("default"):
				flow_anim.play("default")
			elif not active:
				flow_anim.stop()

func _start_wheel_spin(node: Node) -> void:
	var wheel := node as Node2D
	if wheel == null:
		return

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(wheel, "rotation", TAU, wheel_spin_time_per_turn).as_relative().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
