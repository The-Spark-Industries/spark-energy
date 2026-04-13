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
@export var target_method: StringName = &"activate"
@export var fallback_methods: Array[StringName] = [&"power_on", &"on_terminal_solved", &"activate", &"trigger", &"start"]

@export_group("Visual")
@export var visual_node_path: NodePath
@export var unpowered_modulate: Color = Color(0.35, 0.35, 0.35, 1.0)
@export var powered_modulate: Color = Color(1.0, 0.95, 0.3, 1.0)

var _powered: bool = false

func _ready() -> void:
	_powered = starts_powered
	_apply_visual_state()

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
	_apply_visual_state()

	if not was_powered:
		power_changed.emit(true)
		powered_on.emit(source if source != null else self)

	_schedule_target_trigger(source if source != null else self)

func power_off(source: Node = null) -> void:
	if not _powered:
		return

	_powered = false
	_apply_visual_state()
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
	for target_path in target_paths:
		if String(target_path).is_empty():
			continue

		var target := get_node_or_null(target_path)
		if target == null:
			push_warning("WirePowerRelay '%s': target path not found: %s" % [name, String(target_path)])
			continue

		if _call_target_method(target, target_method, source):
			continue

		var called := false
		for fallback in fallback_methods:
			if fallback == target_method:
				continue
			if _call_target_method(target, fallback, source):
				called = true
				break

		if not called:
			push_warning("WirePowerRelay '%s': target '%s' has no callable power method." % [name, target.name])

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

func _apply_visual_state() -> void:
	var visual := get_node_or_null(visual_node_path)
	if visual == null or not (visual is CanvasItem):
		return

	var canvas_item := visual as CanvasItem
	canvas_item.modulate = powered_modulate if _powered else unpowered_modulate
