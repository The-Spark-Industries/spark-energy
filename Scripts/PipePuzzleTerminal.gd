extends Area2D

@export var minigame_scene: PackedScene = preload("res://Master Scenes/PipeMinigame.tscn")
@export var puzzle_definition: Dictionary = {}  # Serializable puzzle; auto-populate with default if empty.
@export_enum("Default 3x3", "3x3", "4x4", "5x5", "6x6") var puzzle_layout: int = 0
@export_group("Solved Platform Motion")
@export var moving_platform_path: NodePath
@export var platform_move_distance: float = 140.0
@export var platform_move_duration: float = 1.4

var _bodies_inside: Array[Node] = []
var _ui_layer: CanvasLayer = null
var _minigame: Control = null
var _solved: bool = false
var _puzzle: PipePuzzleDefinition = null
var _randomized_once: bool = false
var _platform_motion_started: bool = false

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
			_:
				_puzzle = PipePuzzleDefinition.create_default()
		puzzle_definition = _puzzle.to_dict()
	else:
		_puzzle = PipePuzzleDefinition.from_dict(puzzle_definition)

func interact(player: CharacterBody2D) -> bool:
	if _solved:
		if has_node("Prompt"):
			$Prompt.text = "Solved"
			$Prompt.visible = true
		return false

	_randomize_puzzle_first_open()

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
		if _minigame.has_signal("completed"):
			_minigame.connect("completed", _on_minigame_completed)
	elif _ui_layer:
		_ui_layer.move_child(_minigame, _ui_layer.get_child_count() - 1)

	if _minigame.has_method("set_puzzle"):
		_minigame.call("set_puzzle", _puzzle)

	if _minigame.has_method("open_for_player"):
		_minigame.call("open_for_player", player)
		return true

	return false

func _on_minigame_completed(success: bool) -> void:
	if success:
		_solved = true
		if has_node("Prompt"):
			$Prompt.text = "Solved"
		_start_platform_motion_if_needed()

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
