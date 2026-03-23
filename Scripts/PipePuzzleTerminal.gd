extends Area2D

@export var minigame_scene: PackedScene = preload("res://Master Scenes/PipeMinigame.tscn")
@export var puzzle_definition: Dictionary = {}  # Serializable puzzle; auto-populate with default if empty.

var _bodies_inside: Array[Node] = []
var _ui_layer: CanvasLayer = null
var _minigame: Control = null
var _solved: bool = false
var _puzzle: PipePuzzleDefinition = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if has_node("Prompt"):
		$Prompt.visible = false
	# Initialize puzzle from export data or use default.
	if puzzle_definition.is_empty():
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
