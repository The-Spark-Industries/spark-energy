extends Node2D
class_name WirePowerRelay

signal power_changed(is_powered: bool)
signal powered_on(source: Node)
signal powered_off(source: Node)

@export_group("Power")
@export var starts_powered: bool = false
@export var one_shot_activation: bool = true
@export var propagation_delay: float = 0.0

@export_group("Outputs")
@export var target_paths: Array[NodePath] = []
@export var target_groups: Array[StringName] = []
@export var target_method: StringName = &"activate"
@export var fallback_methods: Array[StringName] = [&"power_on", &"on_terminal_solved", &"activate", &"trigger", &"start"]

@export_group("Visual")
@export var visual_node_path: NodePath
@export var animated_sprite_path: NodePath
@export var unpowered_animation: StringName = &"unpowered"
@export var power_animation: StringName = &"powered"
@export var unpowered_modulate: Color = Color(0.35, 0.35, 0.35, 1.0)
@export var powered_modulate: Color = Color(1.0, 0.95, 0.3, 1.0)

var _powered: bool = false

func _ready() -> void:
	_powered = starts_powered
	_apply_visual_state(false)

func on_terminal_solved(terminal: Node = null) -> void:
	power_on(terminal)

func activate(source: Node = null) -> void:
	power_on(source)

func trigger(source: Node = null) -> void:
	power_on(source)

func power_on(source: Node = null) -> void:
	if _powered and one_shot_activation:
		return

	var was_powered := _powered
	_powered = true
	_apply_visual_state(not was_powered)

	if not was_powered:
		power_changed.emit(true)
		powered_on.emit(source if source != null else self)

	_schedule_target_trigger(source if source != null else self)

func power_off(source: Node = null) -> void:
	if not _powered:
		return

	_powered = false
	_apply_visual_state(false)
	power_changed.emit(false)
	powered_off.emit(source if source != null else self)

func set_powered(value: bool, source: Node = null) -> void:
	if value:
		power_on(source)
	else:
		power_off(source)

func is_powered() -> bool:
	return _powered

func _schedule_target_trigger(source: Node) -> void:
	if propagation_delay <= 0.0:
		_trigger_targets(source)
		return

	var timer := get_tree().create_timer(propagation_delay)
	timer.timeout.connect(func() -> void:
		if is_inside_tree():
			_trigger_targets(source)
	)

func _trigger_targets(source: Node) -> void:
	var called_nodes := {}

	for target_path in target_paths:
		if String(target_path).is_empty():
			continue

		var target := get_node_or_null(target_path)
		if target == null:
			push_warning("WirePowerRelay '%s': target path not found: %s" % [name, String(target_path)])
			continue

		var target_id := target.get_instance_id()
		if called_nodes.has(target_id):
			continue
		called_nodes[target_id] = true

		_trigger_single_target(target, source, called_nodes)

	for group_name in target_groups:
		var group_name_str := String(group_name)
		if group_name_str.is_empty():
			continue

		for target in get_tree().get_nodes_in_group(group_name_str):
			if target == null:
				continue

			var target_id := target.get_instance_id()
			if called_nodes.has(target_id):
				continue
			called_nodes[target_id] = true

			_trigger_single_target(target, source, called_nodes)

func _trigger_single_target(target: Object, source: Node, called_nodes: Dictionary) -> void:
	if _call_target_method(target, target_method, source):
		return

	var called := false
	for fallback in fallback_methods:
		if fallback == target_method:
			continue
		if _call_target_method(target, fallback, source):
			called = true
			break

	if called:
		return

	if target is Node and _trigger_descendants(target as Node, source, called_nodes):
		return

	if target is Node:
		push_warning("WirePowerRelay '%s': target '%s' has no callable power method." % [name, (target as Node).name])

func _trigger_descendants(root: Node, source: Node, called_nodes: Dictionary) -> bool:
	var triggered_any := false

	for child in root.get_children():
		if not (child is Node):
			continue

		var node := child as Node
		var child_id := node.get_instance_id()
		if not called_nodes.has(child_id):
			called_nodes[child_id] = true
			if _call_target_method(node, target_method, source):
				triggered_any = true
			else:
				for fallback in fallback_methods:
					if fallback == target_method:
						continue
					if _call_target_method(node, fallback, source):
						triggered_any = true
						break

		if _trigger_descendants(node, source, called_nodes):
			triggered_any = true

	return triggered_any

func _call_target_method(target: Object, method_name: StringName, source: Node) -> bool:
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
		target.call(method_str, source)
	else:
		target.call(method_str, self, source)

	return true

func _apply_visual_state(play_power_transition: bool) -> void:
	var visual := get_node_or_null(visual_node_path)
	if visual != null and visual is CanvasItem:
		var canvas_item := visual as CanvasItem
		canvas_item.modulate = powered_modulate if _powered else unpowered_modulate

	var sprite := _resolve_animated_sprite(visual)
	if sprite == null:
		return

	if _powered:
		var powered_anim := _resolve_powered_animation_name(sprite)
		if not powered_anim.is_empty():
			sprite.play(powered_anim)
	else:
		if _sprite_has_animation(sprite, unpowered_animation):
			sprite.play(String(unpowered_animation))

func _resolve_powered_animation_name(sprite: AnimatedSprite2D) -> String:
	if _sprite_has_animation(sprite, power_animation):
		return String(power_animation)
	if _sprite_has_animation(sprite, &"powered"):
		return "powered"
	if _sprite_has_animation(sprite, &"power"):
		return "power"
	return ""

func _resolve_animated_sprite(visual: Node) -> AnimatedSprite2D:
	if not String(animated_sprite_path).is_empty():
		var node := get_node_or_null(animated_sprite_path)
		if node is AnimatedSprite2D:
			return node as AnimatedSprite2D

	if visual is AnimatedSprite2D:
		return visual as AnimatedSprite2D

	if visual != null:
		var child := visual.get_node_or_null("AnimatedSprite2D")
		if child is AnimatedSprite2D:
			return child as AnimatedSprite2D

	var fallback := get_node_or_null("AnimatedSprite2D")
	if fallback is AnimatedSprite2D:
		return fallback as AnimatedSprite2D

	return null

func _sprite_has_animation(sprite: AnimatedSprite2D, animation_name: StringName) -> bool:
	if sprite == null or sprite.sprite_frames == null:
		return false
	var name := String(animation_name)
	if name.is_empty():
		return false
	return sprite.sprite_frames.has_animation(name)
