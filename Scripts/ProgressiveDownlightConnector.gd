extends Node

## Connects each stage of the Room 10 progressive puzzle to a downlight.
## Attach this as a child of Room10ProgressivePuzzle and set the exported paths.

@export var stage1_terminal_path: NodePath
@export var stage2_terminal_path: NodePath
@export var stage3_terminal_path: NodePath

@export var downlight1_path: NodePath  # activates on stage 1 solve
@export var downlight2_path: NodePath  # activates on stage 2 solve
@export var downlight3_path: NodePath  # activates on stage 3 solve

func _ready() -> void:
	_connect_terminal(stage1_terminal_path, downlight1_path)
	_connect_terminal(stage2_terminal_path, downlight2_path)
	_connect_terminal(stage3_terminal_path, downlight3_path)

func _connect_terminal(terminal_path: NodePath, light_path: NodePath) -> void:
	if terminal_path.is_empty() or light_path.is_empty():
		return
	var terminal := get_node_or_null(terminal_path)
	var light := get_node_or_null(light_path)
	if terminal == null:
		push_warning("ProgressiveDownlightConnector: terminal not found at %s" % terminal_path)
		return
	if light == null:
		push_warning("ProgressiveDownlightConnector: downlight not found at %s" % light_path)
		return
	if terminal.has_signal("puzzle_solved"):
		terminal.puzzle_solved.connect(_activate_downlight.bind(light))
	else:
		push_warning("ProgressiveDownlightConnector: terminal at %s has no puzzle_solved signal" % terminal_path)

func _activate_downlight(light_node: Node) -> void:
	# Try the named method first (in case downlight.gd exposes one)
	if light_node.has_method("activate"):
		light_node.activate()
		return
	# Fallback: make the node visible and enable any Light2D children
	light_node.visible = true
	for child in light_node.get_children():
		if child is PointLight2D or child is DirectionalLight2D:
			child.visible = true
