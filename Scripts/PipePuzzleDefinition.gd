## Defines a single pipe puzzle layout.
## Use class_name to make it a type hint available everywhere.
class_name PipePuzzleDefinition
extends RefCounted

## Grid size (width and height are the same).
var grid_size: int = 3

## Array of piece definitions indexed by [y * grid_size + x].
## Each piece is: {"kind": "source"/"sink"/"straight"/"corner"/"tee"/"empty", "rot": 0-3, "locked": true/false}
var pieces: Array[Dictionary] = []

## (x, y) where water source is located.
var source_pos: Vector2i = Vector2i(0, 1)

## (x, y) where water sink is located.
var sink_pos: Vector2i = Vector2i(2, 1)

func _init(_grid_size: int = 3) -> void:
	grid_size = _grid_size
	pieces.resize(grid_size * grid_size)
	for i in range(pieces.size()):
		pieces[i] = {"kind": "empty", "rot": 0, "locked": false}

## Helper: set a piece at grid position (x, y).
func set_piece(x: int, y: int, kind: String, rot: int = 0, locked: bool = false) -> void:
	var idx := y * grid_size + x
	if idx >= 0 and idx < pieces.size():
		pieces[idx] = {"kind": kind, "rot": rot, "locked": locked}

## Helper: get a piece by grid position.
func get_piece(x: int, y: int) -> Dictionary:
	var idx := y * grid_size + x
	if idx >= 0 and idx < pieces.size():
		return pieces[idx]
	return {}

## Helper: convert to serializable dict for saving.
func to_dict() -> Dictionary:
	return {
		"grid_size": grid_size,
		"pieces": pieces,
		"source_pos": [source_pos.x, source_pos.y],
		"sink_pos": [sink_pos.x, sink_pos.y]
	}

## Helper: create from dict.
static func from_dict(data: Dictionary) -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(data.get("grid_size", 3))
	puzzle.pieces = data.get("pieces", [])
	var src_arr = data.get("source_pos", [0, 1])
	var snk_arr = data.get("sink_pos", [2, 1])
	puzzle.source_pos = Vector2i(src_arr[0], src_arr[1])
	puzzle.sink_pos = Vector2i(snk_arr[0], snk_arr[1])
	return puzzle

## Create a default 3x3 puzzle suitable for testing.
static func create_default() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(3)
	puzzle.set_piece(0, 1, "source", 0, true)
	puzzle.set_piece(2, 1, "sink", 0, true)
	puzzle.set_piece(0, 0, "corner", 0)
	puzzle.set_piece(1, 0, "straight", 1)
	puzzle.set_piece(2, 0, "corner", 1)
	puzzle.set_piece(0, 2, "empty")
	puzzle.set_piece(1, 1, "empty")
	puzzle.set_piece(1, 2, "straight", 0)
	puzzle.set_piece(2, 2, "tee", 0)
	return puzzle

## Create a unique 3x3 puzzle.
static func create_puzzle_3x3() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(3)
	puzzle.set_piece(0, 1, "source", 0, true)
	puzzle.set_piece(2, 1, "sink", 0, true)
	# Route: down, right, up, right
	puzzle.set_piece(0, 0, "empty")
	puzzle.set_piece(1, 0, "corner", 0)
	puzzle.set_piece(2, 0, "straight", 1)
	puzzle.set_piece(0, 2, "corner", 2)
	puzzle.set_piece(1, 1, "tee", 1)
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
	
	# Create a more complex routing through the middle
	puzzle.set_piece(0, 0, "corner", 0)
	puzzle.set_piece(1, 0, "straight", 1)
	puzzle.set_piece(2, 0, "corner", 1)
	puzzle.set_piece(3, 0, "empty")
	
	puzzle.set_piece(0, 1, "empty")
	puzzle.set_piece(1, 1, "tee", 0)
	puzzle.set_piece(2, 1, "straight", 0)
	puzzle.set_piece(3, 1, "corner", 1)
	
	puzzle.set_piece(1, 2, "straight", 1)
	puzzle.set_piece(2, 2, "corner", 2)
	
	puzzle.set_piece(0, 3, "straight", 0)
	puzzle.set_piece(1, 3, "corner", 3)
	puzzle.set_piece(2, 3, "straight", 1)
	puzzle.set_piece(3, 3, "corner", 2)
	
	return puzzle

## Create a unique 5x5 puzzle.
static func create_puzzle_5x5() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(5)
	puzzle.set_piece(0, 2, "source", 0, true)
	puzzle.set_piece(4, 2, "sink", 0, true)
	puzzle.source_pos = Vector2i(0, 2)
	puzzle.sink_pos = Vector2i(4, 2)
	
	# Complex maze-like routing
	puzzle.set_piece(0, 0, "corner", 0)
	puzzle.set_piece(1, 0, "straight", 1)
	puzzle.set_piece(2, 0, "corner", 1)
	puzzle.set_piece(3, 0, "tee", 0)
	puzzle.set_piece(4, 0, "empty")
	
	puzzle.set_piece(0, 1, "straight", 0)
	puzzle.set_piece(1, 1, "tee", 3)
	puzzle.set_piece(2, 1, "empty")
	puzzle.set_piece(3, 1, "straight", 0)
	puzzle.set_piece(4, 1, "corner", 2)
	
	puzzle.set_piece(1, 2, "straight", 1)
	puzzle.set_piece(2, 2, "corner", 2)
	puzzle.set_piece(3, 2, "straight", 1)
	
	puzzle.set_piece(0, 3, "straight", 0)
	puzzle.set_piece(1, 3, "corner", 0)
	puzzle.set_piece(2, 3, "tee", 2)
	puzzle.set_piece(3, 3, "straight", 0)
	puzzle.set_piece(4, 3, "corner", 3)
	
	puzzle.set_piece(1, 4, "straight", 1)
	puzzle.set_piece(2, 4, "straight", 1)
	puzzle.set_piece(3, 4, "corner", 3)
	puzzle.set_piece(4, 4, "straight", 0)
	
	return puzzle
