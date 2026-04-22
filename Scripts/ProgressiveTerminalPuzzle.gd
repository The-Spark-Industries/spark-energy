extends Node
class_name ProgressiveTerminalPuzzle

@export_group("Terminals")
@export var stage_one_terminal_path: NodePath
@export var stage_two_terminal_path: NodePath
@export var stage_three_terminal_path: NodePath
@export var lock_stage_two_until_stage_one: bool = true
@export var lock_stage_three_until_stage_two: bool = true
@export var stage_one_power_delay: float = 0.35

@export_group("Lighting")
@export var stage_one_light_paths: Array[NodePath] = []
@export var stage_two_additional_light_paths: Array[NodePath] = []
@export var stage_three_additional_light_paths: Array[NodePath] = []

var _stage_one_complete: bool = false
var _stage_two_complete: bool = false
var _stage_three_complete: bool = false

var _stage_one_terminal: Node = null
var _stage_two_terminal: Node = null
var _stage_three_terminal: Node = null

func _ready() -> void:
	_stage_one_terminal = get_node_or_null(stage_one_terminal_path)
	_stage_two_terminal = get_node_or_null(stage_two_terminal_path)
	_stage_three_terminal = get_node_or_null(stage_three_terminal_path)

	_connect_terminal_if_available(_stage_one_terminal, _on_stage_one_solved)
	_connect_terminal_if_available(_stage_two_terminal, _on_stage_two_solved)
	_connect_terminal_if_available(_stage_three_terminal, _on_stage_three_solved)

	_set_stage_one_lights(false)
	_set_stage_two_extra_lights(false)
	_set_stage_three_extra_lights(false)

	if lock_stage_two_until_stage_one:
		_set_terminal_enabled(_stage_two_terminal, false)
	if lock_stage_three_until_stage_two:
		_set_terminal_enabled(_stage_three_terminal, false)

func _connect_terminal_if_available(terminal: Node, callback: Callable) -> void:
	if terminal == null:
		return
	if terminal.has_signal("puzzle_solved") and not terminal.is_connected("puzzle_solved", callback):
		terminal.connect("puzzle_solved", callback)

func _on_stage_one_solved(_terminal: Node) -> void:
	if _stage_one_complete:
		return

	_stage_one_complete = true

	if stage_one_power_delay > 0.0:
		await get_tree().create_timer(stage_one_power_delay).timeout

	_set_stage_one_lights(true)
	_set_stage_two_extra_lights(false)
	_set_stage_three_extra_lights(false)

	if lock_stage_two_until_stage_one:
		_set_terminal_enabled(_stage_two_terminal, true)

func _on_stage_two_solved(_terminal: Node) -> void:
	if _stage_two_complete:
		return

	_stage_two_complete = true
	_set_stage_one_lights(true)
	_set_stage_two_extra_lights(true)
	_set_stage_three_extra_lights(false)

	if lock_stage_three_until_stage_two:
		_set_terminal_enabled(_stage_three_terminal, true)

func _on_stage_three_solved(_terminal: Node) -> void:
	if _stage_three_complete:
		return

	_stage_three_complete = true
	_set_stage_one_lights(true)
	_set_stage_two_extra_lights(true)
	_set_stage_three_extra_lights(true)

func _set_stage_one_lights(enabled: bool) -> void:
	for light_path in stage_one_light_paths:
		_set_light_enabled(get_node_or_null(light_path), enabled)

func _set_stage_two_extra_lights(enabled: bool) -> void:
	for light_path in stage_two_additional_light_paths:
		_set_light_enabled(get_node_or_null(light_path), enabled)

func _set_stage_three_extra_lights(enabled: bool) -> void:
	for light_path in stage_three_additional_light_paths:
		_set_light_enabled(get_node_or_null(light_path), enabled)

func _set_light_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return

	if node is PointLight2D:
		(node as PointLight2D).visible = enabled
		return

	if node is CanvasItem:
		(node as CanvasItem).visible = enabled

func _set_terminal_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return

	if node is Area2D:
		var area := node as Area2D
		area.set_deferred("monitoring", enabled)
		area.set_deferred("monitorable", enabled)

	if node.has_node("Prompt"):
		var prompt := node.get_node("Prompt") as CanvasItem
		if prompt:
			prompt.visible = false
