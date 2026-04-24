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

const DEFAULT_DIRT_LEVEL := 0

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
		pieces[i] = {"kind": "empty", "rot": 0, "locked": false, "dirt_level": DEFAULT_DIRT_LEVEL}

## Helper: set a piece at grid position (x, y).
func set_piece(x: int, y: int, kind: String, rot: int = 0, locked: bool = false) -> void:
	if x < 0 or y < 0 or x >= grid_width or y >= grid_height:
		return
	var idx := y * grid_width + x
	if idx >= 0 and idx < pieces.size():
		pieces[idx] = {"kind": kind, "rot": rot, "locked": locked, "dirt_level": DEFAULT_DIRT_LEVEL}

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
			puzzle.pieces[i] = {"kind": "empty", "rot": 0, "locked": false, "dirt_level": DEFAULT_DIRT_LEVEL}
			continue

		if not puzzle.pieces[i].has("dirt_level"):
			puzzle.pieces[i]["dirt_level"] = DEFAULT_DIRT_LEVEL
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

## Create a compact 2x2 puzzle.
static func create_puzzle_2x2() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(2)
	puzzle.source_pos = Vector2i(0, 0)
	puzzle.sink_pos = Vector2i(1, 1)

	puzzle.set_piece(0, 0, "source", 1, true)
	puzzle.set_piece(1, 1, "sink", 3, true)
	puzzle.set_piece(1, 0, "corner", 2)
	puzzle.set_piece(0, 1, "corner", 0)

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

## Convert in-grid source/sink endpoints to hidden ports just outside the board.
## Endpoint cells are converted to bridge pieces so puzzles remain solvable.
static func with_hidden_ports(puzzle: PipePuzzleDefinition) -> PipePuzzleDefinition:
	if puzzle == null:
		return null

	if _is_in_grid_pos(puzzle, puzzle.source_pos):
		_convert_endpoint_to_hidden_port(puzzle, puzzle.source_pos, true)
	if _is_in_grid_pos(puzzle, puzzle.sink_pos):
		_convert_endpoint_to_hidden_port(puzzle, puzzle.sink_pos, false)

	return puzzle

static func _convert_endpoint_to_hidden_port(puzzle: PipePuzzleDefinition, pos: Vector2i, is_source: bool) -> void:
	var piece := puzzle.get_piece(pos.x, pos.y)
	if piece.is_empty():
		return

	var connectors := _piece_connectors(piece)
	if connectors.is_empty():
		return

	var inner_dir := int(connectors[0])
	var preferred_outside := _opposite_dir(inner_dir)
	var outside_dir := _pick_outside_dir_for_edge_pos(puzzle, pos, preferred_outside)
	if outside_dir == -1:
		return

	var bridge := _bridge_piece_for_dirs(outside_dir, inner_dir)
	puzzle.set_piece(pos.x, pos.y, String(bridge.get("kind", "empty")), int(bridge.get("rot", 0)), bool(piece.get("locked", true)))

	var hidden_pos := pos + _dir_to_vec(outside_dir)
	if is_source:
		puzzle.source_pos = hidden_pos
	else:
		puzzle.sink_pos = hidden_pos

static func _is_in_grid_pos(puzzle: PipePuzzleDefinition, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < puzzle.grid_width and pos.y >= 0 and pos.y < puzzle.grid_height

static func _pick_outside_dir_for_edge_pos(puzzle: PipePuzzleDefinition, pos: Vector2i, preferred_dir: int) -> int:
	var candidates: Array[int] = []
	if pos.x == 0:
		candidates.append(3)
	if pos.x == puzzle.grid_width - 1:
		candidates.append(1)
	if pos.y == 0:
		candidates.append(0)
	if pos.y == puzzle.grid_height - 1:
		candidates.append(2)

	for d in candidates:
		if d == preferred_dir:
			return d
	if candidates.is_empty():
		return -1
	return candidates[0]

static func _bridge_piece_for_dirs(a: int, b: int) -> Dictionary:
	if (a == 0 and b == 2) or (a == 2 and b == 0):
		return {"kind": "straight", "rot": 0}
	if (a == 1 and b == 3) or (a == 3 and b == 1):
		return {"kind": "straight", "rot": 1}
	if (a == 0 and b == 1) or (a == 1 and b == 0):
		return {"kind": "corner", "rot": 0}
	if (a == 1 and b == 2) or (a == 2 and b == 1):
		return {"kind": "corner", "rot": 1}
	if (a == 2 and b == 3) or (a == 3 and b == 2):
		return {"kind": "corner", "rot": 2}
	return {"kind": "corner", "rot": 3}

static func _piece_connectors(piece: Dictionary) -> Array[int]:
	var kind := String(piece.get("kind", "empty"))
	var rot := posmod(int(piece.get("rot", 0)), 4)

	match kind:
		"source":
			match rot:
				0:
					return [1]
				1:
					return [2]
				2:
					return [3]
				_:
					return [0]
		"sink":
			match rot:
				0:
					return [3]
				1:
					return [0]
				2:
					return [1]
				_:
					return [2]
		"straight":
			if rot % 2 == 0:
				return [0, 2]
			return [1, 3]
		"corner":
			match rot:
				0:
					return [0, 1]
				1:
					return [1, 2]
				2:
					return [2, 3]
				_:
					return [3, 0]
		"tee":
			match rot:
				0:
					return [0, 3, 1]
				1:
					return [0, 1, 2]
				2:
					return [3, 1, 2]
				_:
					return [0, 3, 2]
		_:
			return []

static func _dir_to_vec(d: int) -> Vector2i:
	match d:
		0:
			return Vector2i(0, -1)
		1:
			return Vector2i(1, 0)
		2:
			return Vector2i(0, 1)
		_:
			return Vector2i(-1, 0)

static func _opposite_dir(d: int) -> int:
	return (d + 2) % 4

## Create a 3x3 puzzle with hidden source/sink ports outside the visible grid.
## Source is above the top-middle cell; sink is below the bottom-left cell.
static func create_puzzle_3x3_hidden_ports() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(3)
	puzzle.source_pos = Vector2i(1, -1)
	puzzle.sink_pos = Vector2i(0, 3)

	# Solved route: (1,0) -> (1,1) -> (0,1) -> (0,2) -> sink(outside)
	puzzle.set_piece(1, 0, "straight", 0)
	puzzle.set_piece(1, 1, "corner", 3)
	puzzle.set_piece(0, 1, "corner", 1)
	puzzle.set_piece(0, 2, "straight", 0)

	# Keep other cells empty so move-only shuffling still creates a valid challenge.
	for y in range(3):
		for x in range(3):
			if puzzle.get_piece(x, y).is_empty():
				puzzle.set_piece(x, y, "empty")

	return puzzle

## Create a unique 4x4 puzzle.
static func create_puzzle_4x4() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(4)
	puzzle.source_pos = Vector2i(3, 0)
	puzzle.sink_pos = Vector2i(0, 3)

	for y in range(4):
		for x in range(4):
			puzzle.set_piece(x, y, "block", 0, true)

	puzzle.set_piece(3, 0, "source", 2, true)
	puzzle.set_piece(0, 3, "sink", 1, true)

	# Friendly zig-zag path already faces the right way, so no rotation is needed.
	puzzle.set_piece(2, 0, "corner", 1)
	puzzle.set_piece(2, 1, "straight", 0)
	puzzle.set_piece(2, 2, "corner", 3)
	puzzle.set_piece(1, 2, "straight", 1)
	puzzle.set_piece(0, 2, "corner", 1)
	
	return puzzle

## Create a unique 5x5 puzzle.
static func create_puzzle_5x5() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(5)
	puzzle.source_pos = Vector2i(0, 4)
	puzzle.sink_pos = Vector2i(4, 2)

	for y in range(5):
		for x in range(5):
			puzzle.set_piece(x, y, "block", 0, true)

	puzzle.set_piece(0, 4, "source", 0, true)
	puzzle.set_piece(4, 2, "sink", 0, true)

	# Playful snake path already faces the right way, so no rotation is needed.
	puzzle.set_piece(1, 4, "straight", 1)
	puzzle.set_piece(2, 4, "corner", 3)
	puzzle.set_piece(2, 3, "straight", 0)
	puzzle.set_piece(2, 2, "corner", 1)
	puzzle.set_piece(3, 2, "straight", 1)
	
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

## Create a rotate-focused wire puzzle in a Christmas-tree layout (9x8).
static func create_wire_tree_9x8() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(9, 8)
	puzzle.source_pos = Vector2i(4, 0)
	puzzle.sink_pos = Vector2i(4, 7)

	for y in range(8):
		for x in range(9):
			puzzle.set_piece(x, y, "block", 0, true)

	# Tree trunk and endpoints.
	puzzle.set_piece(4, 0, "source", 1, true)
	puzzle.set_piece(4, 7, "sink", 1, true)
	puzzle.set_piece(4, 1, "straight", 0)
	puzzle.set_piece(4, 2, "tee", 1)
	puzzle.set_piece(4, 3, "tee", 3)
	puzzle.set_piece(4, 4, "tee", 1)
	puzzle.set_piece(4, 5, "tee", 3)
	puzzle.set_piece(4, 6, "straight", 0)

	# Upper branches.
	puzzle.set_piece(3, 2, "corner", 1)
	puzzle.set_piece(2, 2, "tee", 2)
	puzzle.set_piece(1, 2, "corner", 0)
	puzzle.set_piece(5, 2, "corner", 2)
	puzzle.set_piece(6, 2, "tee", 2)
	puzzle.set_piece(7, 2, "corner", 3)

	# Middle branches.
	puzzle.set_piece(3, 3, "tee", 0)
	puzzle.set_piece(2, 3, "corner", 1)
	puzzle.set_piece(1, 3, "corner", 0)
	puzzle.set_piece(5, 3, "tee", 0)
	puzzle.set_piece(6, 3, "corner", 2)
	puzzle.set_piece(7, 3, "corner", 3)

	# Lower branches.
	puzzle.set_piece(3, 4, "corner", 2)
	puzzle.set_piece(2, 4, "tee", 0)
	puzzle.set_piece(1, 4, "corner", 1)
	puzzle.set_piece(5, 4, "corner", 3)
	puzzle.set_piece(6, 4, "tee", 0)
	puzzle.set_piece(7, 4, "corner", 2)

	# Base/support pieces.
	puzzle.set_piece(3, 5, "corner", 0)
	puzzle.set_piece(2, 5, "straight", 1)
	puzzle.set_piece(1, 5, "corner", 1)
	puzzle.set_piece(5, 5, "corner", 3)
	puzzle.set_piece(6, 5, "straight", 1)
	puzzle.set_piece(7, 5, "corner", 2)

	return puzzle

## Create a full 6x6 wire board (every cell is a wire node).
static func create_wire_full_6x6() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(6, 6)
	puzzle.source_pos = Vector2i(0, 2)
	puzzle.sink_pos = Vector2i(5, 3)

	for y in range(6):
		for x in range(6):
			if x == puzzle.source_pos.x and y == puzzle.source_pos.y:
				puzzle.set_piece(x, y, "source", 0, true)
				continue
			if x == puzzle.sink_pos.x and y == puzzle.sink_pos.y:
				puzzle.set_piece(x, y, "sink", 0, true)
				continue

			var selector := (x + y) % 3
			var kind := "straight"
			if selector == 1:
				kind = "corner"
			elif selector == 2:
				kind = "tee"

			var rot := posmod((x * 2) + y, 4)
			puzzle.set_piece(x, y, kind, rot, false)

	return puzzle

## Create a full 6x7 wire board (every cell is a wire node).
static func create_wire_full_6x7() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(6, 7)
	puzzle.source_pos = Vector2i(0, 3)
	puzzle.sink_pos = Vector2i(5, 3)

	for y in range(7):
		for x in range(6):
			if x == puzzle.source_pos.x and y == puzzle.source_pos.y:
				puzzle.set_piece(x, y, "source", 0, true)
				continue
			if x == puzzle.sink_pos.x and y == puzzle.sink_pos.y:
				puzzle.set_piece(x, y, "sink", 0, true)
				continue

			var selector := (x + y) % 3
			var kind := "straight"
			if selector == 1:
				kind = "corner"
			elif selector == 2:
				kind = "tee"

			var rot := posmod((x * 2) + y, 4)
			puzzle.set_piece(x, y, kind, rot, false)

	return puzzle

## Create a full 7x6 wire board (every cell is a wire node).
static func create_wire_full_7x6() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(7, 6)
	puzzle.source_pos = Vector2i(0, 3)
	puzzle.sink_pos = Vector2i(6, 3)

	for y in range(6):
		for x in range(7):
			if x == puzzle.source_pos.x and y == puzzle.source_pos.y:
				puzzle.set_piece(x, y, "source", 0, true)
				continue
			if x == puzzle.sink_pos.x and y == puzzle.sink_pos.y:
				puzzle.set_piece(x, y, "sink", 0, true)
				continue

			var selector := (x + y) % 3
			var kind := "straight"
			if selector == 1:
				kind = "corner"
			elif selector == 2:
				kind = "tee"

			var rot := posmod((x * 2) + y, 4)
			puzzle.set_piece(x, y, kind, rot, false)

	return puzzle

## Create a full 8x7 wire board (every cell is a wire node).
static func create_wire_full_8x7() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(8, 7)
	puzzle.source_pos = Vector2i(0, 3)
	puzzle.sink_pos = Vector2i(7, 3)

	for y in range(7):
		for x in range(8):
			if x == puzzle.source_pos.x and y == puzzle.source_pos.y:
				puzzle.set_piece(x, y, "source", 0, true)
				continue
			if x == puzzle.sink_pos.x and y == puzzle.sink_pos.y:
				puzzle.set_piece(x, y, "sink", 0, true)
				continue

			var selector := (x + y) % 3
			var kind := "straight"
			if selector == 1:
				kind = "corner"
			elif selector == 2:
				kind = "tee"

			var rot := posmod((x * 2) + y, 4)
			puzzle.set_piece(x, y, kind, rot, false)

	return puzzle

## Create a full 8x8 wire board (every cell is a wire node).
static func create_wire_full_8x8() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(8, 8)
	puzzle.source_pos = Vector2i(0, 4)
	puzzle.sink_pos = Vector2i(7, 4)

	for y in range(8):
		for x in range(8):
			if x == puzzle.source_pos.x and y == puzzle.source_pos.y:
				puzzle.set_piece(x, y, "source", 0, true)
				continue
			if x == puzzle.sink_pos.x and y == puzzle.sink_pos.y:
				puzzle.set_piece(x, y, "sink", 0, true)
				continue

			var selector := (x + y) % 3
			var kind := "straight"
			if selector == 1:
				kind = "corner"
			elif selector == 2:
				kind = "tee"

			var rot := posmod((x * 2) + y, 4)
			puzzle.set_piece(x, y, kind, rot, false)

	return puzzle

## Create a full 8x4 wire board (every cell is a wire node).
static func create_wire_full_8x4() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(8, 4)
	puzzle.source_pos = Vector2i(0, 2)
	puzzle.sink_pos = Vector2i(7, 2)

	for y in range(4):
		for x in range(8):
			if x == puzzle.source_pos.x and y == puzzle.source_pos.y:
				puzzle.set_piece(x, y, "source", 0, true)
				continue
			if x == puzzle.sink_pos.x and y == puzzle.sink_pos.y:
				puzzle.set_piece(x, y, "sink", 0, true)
				continue

			var selector := (x + y) % 3
			var kind := "straight"
			if selector == 1:
				kind = "corner"
			elif selector == 2:
				kind = "tee"

			var rot := posmod((x * 2) + y, 4)
			puzzle.set_piece(x, y, kind, rot, false)

	return puzzle

## Create a full 6x3 wire board (every cell is a wire node).
static func create_wire_full_6x3() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(6, 3)
	puzzle.source_pos = Vector2i(0, 1)
	puzzle.sink_pos = Vector2i(5, 1)

	for y in range(3):
		for x in range(6):
			if x == puzzle.source_pos.x and y == puzzle.source_pos.y:
				puzzle.set_piece(x, y, "source", 0, true)
				continue
			if x == puzzle.sink_pos.x and y == puzzle.sink_pos.y:
				puzzle.set_piece(x, y, "sink", 0, true)
				continue

			var selector := (x + y) % 3
			var kind := "straight"
			if selector == 1:
				kind = "corner"
			elif selector == 2:
				kind = "tee"

			var rot := posmod((x * 2) + y, 4)
			puzzle.set_piece(x, y, kind, rot, false)

	return puzzle

## Create a full 6x5 wire board (every cell is a wire node).
static func create_wire_full_6x5() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(6, 5)
	puzzle.source_pos = Vector2i(0, 2)
	puzzle.sink_pos = Vector2i(5, 2)

	for y in range(5):
		for x in range(6):
			if x == puzzle.source_pos.x and y == puzzle.source_pos.y:
				puzzle.set_piece(x, y, "source", 0, true)
				continue
			if x == puzzle.sink_pos.x and y == puzzle.sink_pos.y:
				puzzle.set_piece(x, y, "sink", 0, true)
				continue

			var selector := (x + y) % 3
			var kind := "straight"
			if selector == 1:
				kind = "corner"
			elif selector == 2:
				kind = "tee"

			var rot := posmod((x * 2) + y, 4)
			puzzle.set_piece(x, y, kind, rot, false)

	return puzzle

## Create a full 4x5 wire board (every cell is a wire node).
static func create_wire_full_4x5() -> PipePuzzleDefinition:
	var puzzle := PipePuzzleDefinition.new(4, 5)
	puzzle.source_pos = Vector2i(0, 2)
	puzzle.sink_pos = Vector2i(3, 2)

	for y in range(5):
		for x in range(4):
			if x == puzzle.source_pos.x and y == puzzle.source_pos.y:
				puzzle.set_piece(x, y, "source", 0, true)
				continue
			if x == puzzle.sink_pos.x and y == puzzle.sink_pos.y:
				puzzle.set_piece(x, y, "sink", 0, true)
				continue

			var selector := (x + y) % 3
			var kind := "straight"
			if selector == 1:
				kind = "corner"
			elif selector == 2:
				kind = "tee"

			var rot := posmod((x * 2) + y, 4)
			puzzle.set_piece(x, y, kind, rot, false)

	return puzzle
