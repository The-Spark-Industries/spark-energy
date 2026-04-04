## Defines a single pipe puzzle layout.
## Use class_name to make it a type hint available everywhere.
class_name PipePuzzleDefinition
extends RefCounted

## Legacy square-grid size alias kept for compatibility with existing data.
var grid_size: int = 3

## Grid dimensions.
var grid_width: int = 3
var grid_height: int = 3

## Array of piece definitions indexed by [y * grid_width + x].
## Each piece is: {"kind": "source"/"sink"/"straight"/"corner"/"tee"/"block"/"empty", "rot": 0-3, "locked": true/false}
var pieces: Array[Dictionary] = []

## (x, y) where water source is located.
var source_pos: Vector2i = Vector2i(0, 1)

## (x, y) where water sink is located.
var sink_pos: Vector2i = Vector2i(2, 1)

func _init(_grid_width: int = 3, _grid_height: int = -1) -> void:
	if _grid_height < 1:
		_grid_height = _grid_width
	grid_width = max(1, _grid_width)
	grid_height = max(1, _grid_height)
	grid_size = grid_width
	pieces.resize(grid_width * grid_height)
	for i in range(pieces.size()):
		pieces[i] = {"kind": "empty", "rot": 0, "locked": false}

## Helper: set a piece at grid position (x, y).
func set_piece(x: int, y: int, kind: String, rot: int = 0, locked: bool = false) -> void:
	if x < 0 or y < 0 or x >= grid_width or y >= grid_height:
		return
	var idx := y * grid_width + x
	if idx >= 0 and idx < pieces.size():
		pieces[idx] = {"kind": kind, "rot": rot, "locked": locked}

## Helper: get a piece by grid position.
func get_piece(x: int, y: int) -> Dictionary:
	if x < 0 or y < 0 or x >= grid_width or y >= grid_height:
		return {}
	var idx := y * grid_width + x
	if idx >= 0 and idx < pieces.size():
		return pieces[idx]
	return {}

## Helper: convert to serializable dict for saving.
func to_dict() -> Dictionary:
	return {
		"grid_size": grid_width,
		"grid_width": grid_width,
		"grid_height": grid_height,
		"pieces": pieces,
		"source_pos": [source_pos.x, source_pos.y],
		"sink_pos": [sink_pos.x, sink_pos.y]
	}

## Helper: create from dict.
static func from_dict(data: Dictionary) -> PipePuzzleDefinition:
	var width := int(data.get("grid_width", data.get("grid_size", 3)))
	var height := int(data.get("grid_height", data.get("grid_size", width)))
	var puzzle := PipePuzzleDefinition.new(width, height)
	puzzle.pieces = data.get("pieces", [])
	puzzle.pieces.resize(width * height)
	for i in range(puzzle.pieces.size()):
		if typeof(puzzle.pieces[i]) != TYPE_DICTIONARY:
			puzzle.pieces[i] = {"kind": "empty", "rot": 0, "locked": false}
	var src_arr = data.get("source_pos", [0, 1])
	var snk_arr = data.get("sink_pos", [max(0, width - 1), 1])
	puzzle.source_pos = Vector2i(src_arr[0], src_arr[1])
	puzzle.sink_pos = Vector2i(snk_arr[0], snk_arr[1])
	return puzzle

## Create a default 3x3 puzzle suitable for testing.
static func create_default() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(3)
	puzzle.set_piece(0, 1, "source", 0, true)
	puzzle.set_piece(2, 1, "sink", 0, true)
	puzzle.set_piece(1, 1, "block", 0, true)
	puzzle.set_piece(0, 0, "corner", 0)
	puzzle.set_piece(1, 0, "straight", 1)
	puzzle.set_piece(2, 0, "corner", 1)
	puzzle.set_piece(0, 2, "empty")
	puzzle.set_piece(1, 2, "straight", 0)
	puzzle.set_piece(2, 2, "tee", 0)
	return puzzle

## Create a unique 3x3 puzzle.
static func create_puzzle_3x3() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(3)
	puzzle.set_piece(0, 1, "source", 0, true)
	puzzle.set_piece(2, 1, "sink", 0, true)
	puzzle.set_piece(1, 1, "block", 0, true)
	# Route: down, right, up, right
	puzzle.set_piece(0, 0, "empty")
	puzzle.set_piece(1, 0, "corner", 0)
	puzzle.set_piece(2, 0, "straight", 1)
	puzzle.set_piece(0, 2, "corner", 2)
	puzzle.set_piece(1, 2, "straight", 1)
	puzzle.set_piece(2, 2, "corner", 3)
	return puzzle

## Create a unique 4x4 puzzle.
static func create_puzzle_4x4() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(4)
	puzzle.set_piece(0, 2, "source", 0, true)
	puzzle.set_piece(3, 2, "sink", 0, true)
	puzzle.source_pos = Vector2i(0, 2)
	puzzle.sink_pos = Vector2i(3, 2)

	# Single valid route: source -> down -> right -> up -> sink.
	puzzle.set_piece(1, 2, "corner", 2)
	puzzle.set_piece(1, 3, "corner", 0)
	puzzle.set_piece(2, 3, "corner", 3)
	puzzle.set_piece(2, 2, "corner", 1)
	puzzle.set_piece(2, 1, "block", 0, true)
	
	return puzzle

## Create a unique 5x5 puzzle.
static func create_puzzle_5x5() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(5)
	puzzle.set_piece(0, 2, "source", 0, true)
	puzzle.set_piece(4, 2, "sink", 0, true)
	puzzle.source_pos = Vector2i(0, 2)
	puzzle.sink_pos = Vector2i(4, 2)

	# Single valid route with a couple of turns.
	puzzle.set_piece(1, 2, "corner", 2)
	puzzle.set_piece(1, 3, "corner", 0)
	puzzle.set_piece(2, 3, "straight", 1)
	puzzle.set_piece(3, 3, "corner", 3)
	puzzle.set_piece(3, 2, "corner", 1)
	puzzle.set_piece(2, 2, "block", 0, true)
	puzzle.set_piece(2, 1, "block", 0, true)
	puzzle.set_piece(2, 4, "block", 0, true)
	
	return puzzle

## Create a unique 6x6 puzzle.
static func create_puzzle_6x6() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(6)
	puzzle.set_piece(0, 3, "source", 0, true)
	puzzle.set_piece(5, 3, "sink", 0, true)
	puzzle.source_pos = Vector2i(0, 3)
	puzzle.sink_pos = Vector2i(5, 3)

	puzzle.set_piece(1, 3, "corner", 3)
	puzzle.set_piece(1, 2, "straight", 0)
	puzzle.set_piece(1, 1, "corner", 1)
	puzzle.set_piece(2, 1, "straight", 1)
	puzzle.set_piece(3, 1, "straight", 1)
	puzzle.set_piece(4, 1, "corner", 2)
	puzzle.set_piece(4, 2, "straight", 0)
	puzzle.set_piece(4, 3, "corner", 0)
	puzzle.set_piece(2, 3, "block", 0, true)
	puzzle.set_piece(3, 3, "block", 0, true)
	puzzle.set_piece(2, 2, "block", 0, true)
	puzzle.set_piece(3, 2, "block", 0, true)
	puzzle.set_piece(3, 4, "block", 0, true)

	return puzzle

## Create an alternate 6x6 puzzle.
static func create_puzzle_6x6_b() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(6)
	puzzle.set_piece(0, 2, "source", 0, true)
	puzzle.set_piece(5, 2, "sink", 0, true)
	puzzle.source_pos = Vector2i(0, 2)
	puzzle.sink_pos = Vector2i(5, 2)

	# Route: right -> down -> right -> up -> right
	puzzle.set_piece(1, 2, "corner", 2)
	puzzle.set_piece(1, 3, "corner", 0)
	puzzle.set_piece(2, 3, "straight", 1)
	puzzle.set_piece(3, 3, "corner", 3)
	puzzle.set_piece(3, 2, "corner", 1)
	puzzle.set_piece(4, 2, "straight", 1)

	puzzle.set_piece(2, 2, "block", 0, true)
	puzzle.set_piece(2, 1, "block", 0, true)
	puzzle.set_piece(3, 1, "block", 0, true)
	puzzle.set_piece(4, 3, "block", 0, true)

	return puzzle

## Create a unique 7x7 puzzle.
static func create_puzzle_7x7() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(7)
	puzzle.set_piece(0, 3, "source", 0, true)
	puzzle.set_piece(6, 3, "sink", 0, true)
	puzzle.source_pos = Vector2i(0, 3)
	puzzle.sink_pos = Vector2i(6, 3)

	puzzle.set_piece(1, 3, "corner", 3)
	puzzle.set_piece(1, 2, "straight", 0)
	puzzle.set_piece(1, 1, "corner", 1)
	puzzle.set_piece(2, 1, "straight", 1)
	puzzle.set_piece(3, 1, "straight", 1)
	puzzle.set_piece(4, 1, "straight", 1)
	puzzle.set_piece(5, 1, "corner", 2)
	puzzle.set_piece(5, 2, "straight", 0)
	puzzle.set_piece(5, 3, "corner", 0)
	puzzle.set_piece(2, 3, "block", 0, true)
	puzzle.set_piece(3, 3, "block", 0, true)
	puzzle.set_piece(4, 3, "block", 0, true)
	puzzle.set_piece(2, 2, "block", 0, true)
	puzzle.set_piece(3, 2, "block", 0, true)
	puzzle.set_piece(4, 2, "block", 0, true)
	puzzle.set_piece(3, 4, "block", 0, true)

	return puzzle

## Create an alternate 7x7 puzzle.
static func create_puzzle_7x7_b() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(7)
	puzzle.set_piece(0, 4, "source", 0, true)
	puzzle.set_piece(6, 4, "sink", 0, true)
	puzzle.source_pos = Vector2i(0, 4)
	puzzle.sink_pos = Vector2i(6, 4)

	# Route: right -> up -> right -> down -> right
	puzzle.set_piece(1, 4, "corner", 3)
	puzzle.set_piece(1, 3, "corner", 1)
	puzzle.set_piece(2, 3, "straight", 1)
	puzzle.set_piece(3, 3, "straight", 1)
	puzzle.set_piece(4, 3, "corner", 2)
	puzzle.set_piece(4, 4, "corner", 0)
	puzzle.set_piece(5, 4, "straight", 1)

	puzzle.set_piece(2, 4, "block", 0, true)
	puzzle.set_piece(3, 4, "block", 0, true)
	puzzle.set_piece(2, 2, "block", 0, true)
	puzzle.set_piece(3, 2, "block", 0, true)
	puzzle.set_piece(4, 2, "block", 0, true)
	puzzle.set_piece(4, 5, "block", 0, true)

	return puzzle

## Create a unique 9x8 puzzle.
static func create_puzzle_9x8() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(9, 8)
	puzzle.source_pos = Vector2i(0, 4)
	puzzle.sink_pos = Vector2i(8, 4)
	puzzle.set_piece(0, 4, "source", 0, true)
	puzzle.set_piece(8, 4, "sink", 0, true)
	puzzle.set_piece(1, 4, "straight", 1)
	puzzle.set_piece(2, 4, "corner", 1)
	puzzle.set_piece(2, 5, "straight", 0)
	puzzle.set_piece(2, 6, "corner", 0)
	puzzle.set_piece(3, 6, "straight", 1)
	puzzle.set_piece(4, 6, "straight", 1)
	puzzle.set_piece(5, 6, "straight", 1)
	puzzle.set_piece(6, 6, "corner", 3)
	puzzle.set_piece(6, 5, "straight", 0)
	puzzle.set_piece(6, 4, "corner", 0)
	puzzle.set_piece(7, 4, "straight", 1)

	for y in range(8):
		for x in range(9):
			if puzzle.get_piece(x, y).is_empty():
				puzzle.set_piece(x, y, "block", 0, true)

	# Keep the route pieces movable.
	puzzle.set_piece(1, 4, "straight", 1)
	puzzle.set_piece(2, 4, "corner", 1)
	puzzle.set_piece(2, 5, "straight", 0)
	puzzle.set_piece(2, 6, "corner", 0)
	puzzle.set_piece(3, 6, "straight", 1)
	puzzle.set_piece(4, 6, "straight", 1)
	puzzle.set_piece(5, 6, "straight", 1)
	puzzle.set_piece(6, 6, "corner", 3)
	puzzle.set_piece(6, 5, "straight", 0)
	puzzle.set_piece(6, 4, "corner", 0)
	puzzle.set_piece(7, 4, "straight", 1)
	return puzzle

## Create a unique 9x9 puzzle.
static func create_puzzle_9x9() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(9, 9)
	puzzle.source_pos = Vector2i(0, 4)
	puzzle.sink_pos = Vector2i(8, 4)
	puzzle.set_piece(0, 4, "source", 0, true)
	puzzle.set_piece(8, 4, "sink", 0, true)
	puzzle.set_piece(1, 4, "straight", 1)
	puzzle.set_piece(2, 4, "corner", 1)
	puzzle.set_piece(2, 5, "straight", 0)
	puzzle.set_piece(2, 6, "straight", 0)
	puzzle.set_piece(2, 7, "corner", 0)
	puzzle.set_piece(3, 7, "straight", 1)
	puzzle.set_piece(4, 7, "straight", 1)
	puzzle.set_piece(5, 7, "straight", 1)
	puzzle.set_piece(6, 7, "corner", 3)
	puzzle.set_piece(6, 6, "straight", 0)
	puzzle.set_piece(6, 5, "straight", 0)
	puzzle.set_piece(6, 4, "corner", 0)
	puzzle.set_piece(7, 4, "straight", 1)

	for y in range(9):
		for x in range(9):
			if puzzle.get_piece(x, y).is_empty():
				puzzle.set_piece(x, y, "block", 0, true)

	# Keep the route pieces movable.
	puzzle.set_piece(1, 4, "straight", 1)
	puzzle.set_piece(2, 4, "corner", 1)
	puzzle.set_piece(2, 5, "straight", 0)
	puzzle.set_piece(2, 6, "straight", 0)
	puzzle.set_piece(2, 7, "corner", 0)
	puzzle.set_piece(3, 7, "straight", 1)
	puzzle.set_piece(4, 7, "straight", 1)
	puzzle.set_piece(5, 7, "straight", 1)
	puzzle.set_piece(6, 7, "corner", 3)
	puzzle.set_piece(6, 6, "straight", 0)
	puzzle.set_piece(6, 5, "straight", 0)
	puzzle.set_piece(6, 4, "corner", 0)
	puzzle.set_piece(7, 4, "straight", 1)
	return puzzle
