extends Area2D

signal puzzle_solved(terminal: Node)

@export var minigame_scene: PackedScene = preload("res://Master Scenes/PipeMinigame.tscn")
@export var puzzle_definition: Dictionary = {}  # Serializable puzzle; auto-populate with default if empty.
@export_enum("Default 3x3", "3x3", "4x4", "5x5", "6x6", "7x7", "9x8", "9x9") var puzzle_layout: int = 0
@export_enum("Normal", "Move Only", "Rotate Only") var control_mode: int = 0
@export_group("Solved Platform Motion")
@export var moving_platform_path: NodePath
@export var platform_move_distance: float = 140.0
@export var platform_move_duration: float = 1.4
@export_group("Solved Water Flow")
@export var water_stream_path: NodePath
@export var water_wheel_path: NodePath
@export var water_to_wheel_delay: float = 0.25
@export var wheel_spin_time_per_turn: float = 0.6
@export_group("Solved Rise Motion")
@export var solved_rise_target_path: NodePath
@export var solved_rise_distance: float = 0.0
@export var solved_rise_duration: float = 1.0
@export_group("Embedded Puzzle Board")
@export var embedded_minigame_path: NodePath
@export_group("Solved Linked Object")
@export var linked_object_path: NodePath
@export var linked_object_method: StringName = &"on_terminal_solved"

var _bodies_inside: Array[Node] = []
var _ui_layer: CanvasLayer = null
var _minigame: Control = null
var _solved: bool = false
var _puzzle: PipePuzzleDefinition = null
var _randomized_once: bool = false
var _platform_motion_started: bool = false
var _wheel_spin_started: bool = false
var _solved_rise_started: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if has_node("Prompt"):
		$Prompt.visible = false
	# Initialize puzzle from export data or use default.
	if puzzle_definition.is_empty():
		match puzzle_layout:
			1:
				_puzzle = PipePuzzleDefinition.create_puzzle_3x3()
			2:
				_puzzle = PipePuzzleDefinition.create_puzzle_4x4()
			3:
				_puzzle = PipePuzzleDefinition.create_puzzle_5x5()
			4:
				_puzzle = PipePuzzleDefinition.create_puzzle_6x6()
			5:
				_puzzle = PipePuzzleDefinition.create_puzzle_7x7()
			6:
				_puzzle = PipePuzzleDefinition.create_puzzle_9x8()
			7:
				_puzzle = PipePuzzleDefinition.create_puzzle_9x9()
			_:
				_puzzle = PipePuzzleDefinition.create_default()
		puzzle_definition = _puzzle.to_dict()
	else:
		_puzzle = PipePuzzleDefinition.from_dict(puzzle_definition)

	# Randomize at level load so puzzle state is ready before any interaction.
	_randomize_puzzle_first_open()

	# For in-world puzzle boxes, preload the board so the full layout is visible before interaction.
	if not String(embedded_minigame_path).is_empty():
		call_deferred("_setup_embedded_preview")

func _setup_embedded_preview() -> void:
	var embedded := get_node_or_null(embedded_minigame_path) as Control
	if embedded == null:
		return

	_minigame = embedded
	if _minigame.has_method("set_puzzle"):
		_minigame.call("set_puzzle", _puzzle)
	if _minigame.has_method("set_control_mode"):
		_minigame.call("set_control_mode", control_mode)
	if _minigame.has_signal("completed") and not _minigame.is_connected("completed", _on_minigame_completed):
		_minigame.connect("completed", _on_minigame_completed)

func interact(player: CharacterBody2D) -> bool:
	if _solved:
		if has_node("Prompt"):
			$Prompt.text = "Solved"
			$Prompt.visible = true
		return false

	if _minigame == null:
		if not String(embedded_minigame_path).is_empty():
			_minigame = get_node_or_null(embedded_minigame_path) as Control
			if _minigame == null:
				push_warning("PipePuzzleTerminal: embedded_minigame_path not found. Overlay fallback disabled for this terminal.")
				return false
		if _minigame == null:
			if _ui_layer == null:
				_ui_layer = CanvasLayer.new()
				_ui_layer.layer = 100
				get_tree().current_scene.add_child(_ui_layer)

			_minigame = minigame_scene.instantiate() as Control
			if _minigame == null:
				push_error("PipePuzzleTerminal: failed to instantiate PipeMinigame scene.")
				return false

			_ui_layer.add_child(_minigame)
			_ui_layer.move_child(_minigame, _ui_layer.get_child_count() - 1)
	elif _ui_layer:
		_ui_layer.move_child(_minigame, _ui_layer.get_child_count() - 1)

	if _minigame.has_signal("completed") and not _minigame.is_connected("completed", _on_minigame_completed):
		_minigame.connect("completed", _on_minigame_completed)

	if _minigame.has_method("set_puzzle"):
		_minigame.call("set_puzzle", _puzzle)
	if _minigame.has_method("set_control_mode"):
		_minigame.call("set_control_mode", control_mode)

	if _minigame.has_method("open_for_player"):
		_minigame.call("open_for_player", player)
		return true

	return false

func _on_minigame_completed(success: bool) -> void:
	if success:
		_solved = true
		if has_node("Prompt"):
			$Prompt.text = "Solved"
		_notify_linked_object_on_solve()
		await _start_connected_water_flow()
		_start_solved_rise_if_needed()
		_start_platform_motion_if_needed()

func _notify_linked_object_on_solve() -> void:
	puzzle_solved.emit(self)

	if String(linked_object_path).is_empty():
		return

	var linked := get_node_or_null(linked_object_path)
	if linked == null:
		push_warning("PipePuzzleTerminal: linked_object_path not found.")
		return

	if not String(linked_object_method).is_empty() and linked.has_method(String(linked_object_method)):
		linked.call(String(linked_object_method), self)
		return

	# Fallback names for convenience.
	if linked.has_method("start_water_dispense"):
		linked.call("start_water_dispense", self)
	elif linked.has_method("activate"):
		linked.call("activate", self)
	elif linked.has_method("trigger"):
		linked.call("trigger", self)

func _start_connected_water_flow() -> void:
	if not String(water_stream_path).is_empty():
		var stream_node := get_node_or_null(water_stream_path)
		_set_flow_visual_active(stream_node, true)

	if not String(water_wheel_path).is_empty():
		if water_to_wheel_delay > 0.0:
			await get_tree().create_timer(water_to_wheel_delay).timeout
		_start_wheel_spin(get_node_or_null(water_wheel_path))

func _start_solved_rise_if_needed() -> void:
	if _solved_rise_started:
		return
	if String(solved_rise_target_path).is_empty():
		return
	if is_zero_approx(solved_rise_distance):
		return

	var target := get_node_or_null(solved_rise_target_path) as Node2D
	if target == null:
		push_warning("PipePuzzleTerminal: solved_rise_target_path not found.")
		return

	_solved_rise_started = true
	var start_y := target.position.y
	var tween := create_tween()
	tween.tween_property(target, "position:y", start_y - solved_rise_distance, solved_rise_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_flow_visual_active(node: Node, active: bool) -> void:
	if node == null:
		return

	if node is CanvasItem:
		(node as CanvasItem).visible = active

	# Supports GPUParticles2D/CPUParticles2D if a particle stream node is used.
	if node is GPUParticles2D:
		(node as GPUParticles2D).emitting = active
	elif node is CPUParticles2D:
		(node as CPUParticles2D).emitting = active

	# Supports an AnimationPlayer child named FlowAnimation for custom visuals.
	if node.has_node("FlowAnimation"):
		var flow_anim := node.get_node("FlowAnimation") as AnimationPlayer
		if flow_anim:
			if active:
				if flow_anim.has_animation("default"):
					flow_anim.play("default")
			else:
				flow_anim.stop()

func _start_wheel_spin(node: Node) -> void:
	if _wheel_spin_started:
		return
	var wheel := node as Node2D
	if wheel == null:
		return

	_wheel_spin_started = true
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(wheel, "rotation", TAU, wheel_spin_time_per_turn).as_relative().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	if body in _bodies_inside:
		return

	_bodies_inside.append(body)
	if has_node("Prompt"):
		$Prompt.visible = true

	if body.has_method("_on_interactable_entered"):
		body._on_interactable_entered(self)

func _on_body_exited(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return

	_bodies_inside.erase(body)
	if _bodies_inside.is_empty() and has_node("Prompt"):
		$Prompt.visible = false

	if body.has_method("_on_interactable_exited"):
		body._on_interactable_exited(self)

func _randomize_puzzle_first_open() -> void:
	if _randomized_once or _puzzle == null:
		return

	var movable_indices: Array[int] = []
	var movable_pieces: Array[Dictionary] = []
	for i in range(_puzzle.pieces.size()):
		var piece: Dictionary = _puzzle.pieces[i]
		if piece.get("locked", false):
			continue
		movable_indices.append(i)
		movable_pieces.append(piece.duplicate())

	if movable_indices.is_empty():
		_randomized_once = true
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Shuffle all movable slots (including empties) so each terminal starts unique.
	for i in range(movable_pieces.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Dictionary = movable_pieces[i]
		movable_pieces[i] = movable_pieces[j]
		movable_pieces[j] = temp

	for i in range(movable_indices.size()):
		var piece: Dictionary = movable_pieces[i]
		if piece.get("kind", "") != "empty":
			piece["rot"] = rng.randi_range(0, 3)
		_puzzle.pieces[movable_indices[i]] = piece

	puzzle_definition = _puzzle.to_dict()
	_randomized_once = true

func _start_platform_motion_if_needed() -> void:
	if _platform_motion_started:
		return
	if puzzle_layout != 2:
		return
	if String(moving_platform_path).is_empty():
		return

	var platform := get_node_or_null(moving_platform_path) as Node2D
	if platform == null:
		return

	var start_x := platform.position.x
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(platform, "position:x", start_x + platform_move_distance, platform_move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(platform, "position:x", start_x - platform_move_distance, platform_move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_platform_motion_started = true
