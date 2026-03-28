extends Control

signal completed(success: bool)

const DIR_UP := 0
const DIR_RIGHT := 1
const DIR_DOWN := 2
const DIR_LEFT := 3

const CELL_NORMAL := Color("2f3642")
const CELL_CURSOR := Color("4fc9ff")
const CELL_SELECTED := Color("ffb300")
const CELL_FLOW := Color("2b6d8a")

@export_group("Visuals")
@export var ui_font: Font
@export var ui_text_color: Color = Color(1, 1, 1, 1)
@export var backdrop_texture: Texture2D
@export var panel_texture: Texture2D
@export var cell_texture: Texture2D
@export var source_texture: Texture2D
@export var sink_texture: Texture2D
@export var straight_texture: Texture2D
@export var corner_texture: Texture2D
@export var tee_texture: Texture2D
@export var block_texture: Texture2D
@export var empty_texture: Texture2D

@onready var _root_panel: PanelContainer = $CenterContainer/PanelContainer
@onready var _title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Title
@onready var _info_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Info
@onready var _grid: GridContainer = $CenterContainer/PanelContainer/VBoxContainer/Grid
@onready var _status_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Footer/Status
@onready var _send_button: Button = $CenterContainer/PanelContainer/VBoxContainer/Footer/SendWaterButton
@onready var _backdrop: ColorRect = $Backdrop

var _player: CharacterBody2D = null
var _cells: Array[PanelContainer] = []
var _cell_labels: Array[Label] = []
var _cell_icons: Array[TextureRect] = []
var _pieces: Array[Dictionary] = []
var _puzzle: PipePuzzleDefinition = null
var _grid_size: int = 3

var _cursor_index: int = 0
var _grabbed_index: int = -1
var _active: bool = false
var _solved: bool = false
var _control_mode: int = 0  # 0: normal, 1: move-only, 2: rotate-only

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	if not _active:
		visible = false
	_apply_visual_overrides()
	_send_button.pressed.connect(_on_send_water_pressed)
	_reset_puzzle()

func set_puzzle(puzzle: PipePuzzleDefinition) -> void:
	_puzzle = puzzle
	if _puzzle:
		_grid_size = _puzzle.grid_size

func set_control_mode(mode: int) -> void:
	_control_mode = clampi(mode, 0, 2)

func open_for_player(player: CharacterBody2D) -> void:
	_player = player
	_active = true
	_solved = false
	visible = true
	call_deferred("_ensure_visible_on_top")
	_status_label.text = _controls_hint_text()
	if not _puzzle:
		_puzzle = PipePuzzleDefinition.create_default()
		_grid_size = _puzzle.grid_size
	_reset_puzzle()
	get_tree().paused = true

func close_minigame() -> void:
	_active = false
	visible = false
	_grabbed_index = -1
	get_tree().paused = false

func _ensure_visible_on_top() -> void:
	visible = true
	if get_parent():
		get_parent().move_child(self, get_parent().get_child_count() - 1)

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event.is_action_pressed("ui_cancel"):
		close_minigame()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		if _can_move_pieces():
			_toggle_select()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("q"):
		if _can_rotate_pieces():
			_rotate_at_selection(-1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("e"):
		if _can_rotate_pieces():
			_rotate_at_selection(1)
		get_viewport().set_input_as_handled()
		return

	var dx := 0
	var dy := 0

	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		dx = -1
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		dx = 1
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		dy = -1
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		dy = 1

	if dx != 0 or dy != 0:
		_move_cursor(dx, dy)
		get_viewport().set_input_as_handled()

func _build_grid_ui() -> void:
	for child in _grid.get_children():
		child.queue_free()

	_cells.clear()
	_cell_labels.clear()
	_cell_icons.clear()
	_grid.columns = _grid_size

	var separation: int = clampi(10 - ((_grid_size - 3) * 2), 3, 8)
	_grid.add_theme_constant_override("h_separation", separation)
	_grid.add_theme_constant_override("v_separation", separation)

	var viewport_size := get_viewport_rect().size
	var available_grid_width: float = maxf(220.0, viewport_size.x * 0.72)
	var available_grid_height: float = maxf(220.0, viewport_size.y * 0.45)
	var cell_size_w: float = (available_grid_width - float(separation * (_grid_size - 1))) / float(_grid_size)
	var cell_size_h: float = (available_grid_height - float(separation * (_grid_size - 1))) / float(_grid_size)
	var cell_size: float = clampf(minf(cell_size_w, cell_size_h), 32.0, 96.0)

	var panel_width: float = minf(viewport_size.x * 0.92, maxf(380.0, (cell_size * _grid_size) + 120.0))
	var panel_height: float = minf(viewport_size.y * 0.92, maxf(360.0, (cell_size * _grid_size) + 240.0))
	_root_panel.custom_minimum_size = Vector2(panel_width, panel_height)

	var glyph_font_size: int = int(clampf(cell_size * 0.6, 24.0, 62.0))

	for i in range(_grid_size * _grid_size):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
		cell.pivot_offset = Vector2(cell_size * 0.5, cell_size * 0.5)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if cell_texture:
			cell.add_theme_stylebox_override("panel", _make_texture_stylebox(cell_texture))

		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = 6.0
		icon.offset_top = 6.0
		icon.offset_right = -6.0
		icon.offset_bottom = -6.0
		icon.visible = false
		cell.add_child(icon)

		var label := Label.new()
		label.anchor_right = 1.0
		label.anchor_bottom = 1.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", glyph_font_size)
		label.add_theme_color_override("font_color", ui_text_color)
		if ui_font:
			label.add_theme_font_override("font", ui_font)

		cell.add_child(label)
		_grid.add_child(cell)
		_cells.append(cell)
		_cell_labels.append(label)
		_cell_icons.append(icon)

func _reset_puzzle() -> void:
	if not _puzzle:
		_puzzle = PipePuzzleDefinition.create_default()
		_grid_size = _puzzle.grid_size
	else:
		_grid_size = _puzzle.grid_size

	_build_grid_ui()

	_pieces.clear()
	_pieces.resize(_puzzle.pieces.size())

	# Copy puzzle pieces into play area.
	for i in range(_puzzle.pieces.size()):
		_pieces[i] = _puzzle.pieces[i].duplicate()

	# Set cursor to center and start with nothing grabbed.
	var center_x: int = _grid_size / 2
	var center_y: int = _grid_size / 2
	_cursor_index = _idx(center_x, center_y)
	_grabbed_index = -1
	_info_label.text = "Build a connected pipe route from source to drain."
	_status_label.text = _controls_hint_text()
	_update_cells()

func _toggle_select() -> void:
	if _grabbed_index == -1:
		if _can_pick(_cursor_index):
			_grabbed_index = _cursor_index
			_status_label.text = "Selected. Move with WASD, Enter to place."
	else:
		_grabbed_index = -1
		_status_label.text = "Piece placed. Press Send Water when ready."

	_update_cells()

func _move_cursor(dx: int, dy: int) -> void:
	var current := _to_xy(_cursor_index)
	var nx: int = clampi(current.x + dx, 0, _grid_size - 1)
	var ny: int = clampi(current.y + dy, 0, _grid_size - 1)
	var target_index := _idx(nx, ny)

	if _can_move_pieces() and _grabbed_index != -1 and target_index != _grabbed_index:
		if _pieces[target_index].get("locked", false):
			return
		var moved_piece := _pieces[_grabbed_index]
		_pieces[_grabbed_index] = _pieces[target_index]
		_pieces[target_index] = moved_piece
		_grabbed_index = target_index

	_cursor_index = target_index
	_update_cells()

func _rotate_at_selection(dir: int) -> void:
	if not _can_rotate_pieces():
		return

	var idx := _cursor_index
	if _grabbed_index != -1:
		idx = _grabbed_index

	if _pieces[idx].get("locked", false):
		return
	if _pieces[idx].get("kind", "") == "empty":
		return

	_pieces[idx]["rot"] = posmod(int(_pieces[idx].get("rot", 0)) + dir, 4)
	_status_label.text = "Rotated piece."
	_update_cells()

func _can_move_pieces() -> bool:
	return _control_mode != 2

func _can_rotate_pieces() -> bool:
	return _control_mode != 1

func _controls_hint_text() -> String:
	match _control_mode:
		1:
			return "WASD: Move  Enter: Pick/Drop  Rotation disabled"
		2:
			return "WASD: Cursor  Q/E: Rotate  Piece moving disabled"
		_:
			return "WASD: Move  Enter: Pick/Drop  Q/E: Rotate"

func _on_send_water_pressed() -> void:
	if not _active:
		return

	var reached := _trace_flow_from_source()
	var sink_idx := _idx(_puzzle.sink_pos.x, _puzzle.sink_pos.y)
	if reached.has(sink_idx):
		_solved = true
		_status_label.text = "Water reached the end. Puzzle solved!"
		_update_cells(reached)
		completed.emit(true)
		await get_tree().create_timer(0.8).timeout
		close_minigame()
	else:
		_status_label.text = "Flow failed before the end. Re-route the pipes."
		_update_cells(reached)

func _trace_flow_from_source() -> Array[int]:
	var source_idx := _idx(_puzzle.source_pos.x, _puzzle.source_pos.y)
	var visited: Array[int] = []
	var queue: Array[int] = [source_idx]

	while queue.size() > 0:
		var current: int = queue.pop_front()
		if current in visited:
			continue
		visited.append(current)

		var connectors: Array[int] = _connectors(_pieces[current])
		var cxy := _to_xy(current)

		for d in connectors:
			var nxy := Vector2i(cxy.x, cxy.y) + _dir_to_vec(d)
			if nxy.x < 0 or nxy.x >= _grid_size or nxy.y < 0 or nxy.y >= _grid_size:
				continue

			var nidx := _idx(nxy.x, nxy.y)
			var n_connectors: Array[int] = _connectors(_pieces[nidx])
			if _opposite_dir(d) in n_connectors and not (nidx in visited):
				queue.append(nidx)

	return visited

func _update_cells(flow_cells: Array[int] = []) -> void:
	for i in range(_pieces.size()):
		var piece: Dictionary = _pieces[i]
		var piece_tex := _piece_texture(piece)
		if piece_tex:
			_cell_icons[i].texture = piece_tex
			_cell_icons[i].rotation = _piece_rotation_radians(piece)
			_cell_icons[i].visible = true
			_cell_labels[i].text = ""
		else:
			_cell_icons[i].visible = false
			_cell_labels[i].text = _glyph_for_piece(piece)

		var color := CELL_NORMAL
		if i in flow_cells:
			color = CELL_FLOW
		if i == _cursor_index:
			color = CELL_CURSOR
		if i == _grabbed_index:
			color = CELL_SELECTED

		_cells[i].self_modulate = color
		if i == _grabbed_index:
			_cells[i].scale = Vector2(1.14, 1.14)
			_cells[i].z_index = 20
		elif i == _cursor_index:
			_cells[i].scale = Vector2(1.06, 1.06)
			_cells[i].z_index = 10
		else:
			_cells[i].scale = Vector2.ONE
			_cells[i].z_index = 0

func _can_pick(index: int) -> bool:
	if _pieces[index].get("locked", false):
		return false
	return _pieces[index].get("kind", "") != "empty"

func _make_piece(kind: String, rot: int, locked: bool) -> Dictionary:
	return {
		"kind": kind,
		"rot": posmod(rot, 4),
		"locked": locked
	}

func _connectors(piece: Dictionary) -> Array[int]:
	var kind := String(piece.get("kind", "empty"))
	var rot := int(piece.get("rot", 0))

	match kind:
		"source":
			return [DIR_RIGHT]
		"sink":
			return [DIR_LEFT]
		"straight":
			if rot % 2 == 0:
				return [DIR_UP, DIR_DOWN]
			return [DIR_LEFT, DIR_RIGHT]
		"corner":
			match rot:
				0:
					return [DIR_UP, DIR_RIGHT]
				1:
					return [DIR_RIGHT, DIR_DOWN]
				2:
					return [DIR_DOWN, DIR_LEFT]
				_:
					return [DIR_LEFT, DIR_UP]
		"tee":
			match rot:
				0:
					return [DIR_UP, DIR_LEFT, DIR_RIGHT]
				1:
					return [DIR_UP, DIR_RIGHT, DIR_DOWN]
				2:
					return [DIR_LEFT, DIR_RIGHT, DIR_DOWN]
				_:
					return [DIR_UP, DIR_LEFT, DIR_DOWN]
		"block":
			return []
		_:
			return []

func _glyph_for_piece(piece: Dictionary) -> String:
	var kind := String(piece.get("kind", "empty"))
	var rot := int(piece.get("rot", 0))

	match kind:
		"source":
			return "◉"
		"sink":
			return "◎"
		"straight":
			if rot % 2 == 0:
				return "│"
			return "─"
		"corner":
			match rot:
				0:
					return "└"
				1:
					return "┌"
				2:
					return "┐"
				_:
					return "┘"
		"tee":
			match rot:
				0:
					return "┴"
				1:
					return "├"
				2:
					return "┬"
				_:
					return "┤"
		"block":
			return "■"
		_:
			return "·"

func _idx(x: int, y: int) -> int:
	return y * _grid_size + x

func _to_xy(index: int) -> Vector2i:
	return Vector2i(index % _grid_size, index / _grid_size)

func _dir_to_vec(d: int) -> Vector2i:
	match d:
		DIR_UP:
			return Vector2i(0, -1)
		DIR_RIGHT:
			return Vector2i(1, 0)
		DIR_DOWN:
			return Vector2i(0, 1)
		_:
			return Vector2i(-1, 0)

func _opposite_dir(d: int) -> int:
	return (d + 2) % 4

func _apply_visual_overrides() -> void:
	if backdrop_texture:
		var bg := get_node_or_null("BackdropTexture") as TextureRect
		if bg == null:
			bg = TextureRect.new()
			bg.name = "BackdropTexture"
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.anchor_right = 1.0
			bg.anchor_bottom = 1.0
			add_child(bg)
			move_child(bg, 0)
		bg.texture = backdrop_texture
		_backdrop.color = Color(0, 0, 0, 0.35)

	if panel_texture:
		_root_panel.add_theme_stylebox_override("panel", _make_texture_stylebox(panel_texture))

	var text_controls: Array[Control] = [_title_label, _info_label, _status_label, _send_button]
	for c in text_controls:
		c.add_theme_color_override("font_color", ui_text_color)
		if ui_font:
			c.add_theme_font_override("font", ui_font)

func _make_texture_stylebox(tex: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex
	return style

func _piece_texture(piece: Dictionary) -> Texture2D:
	match String(piece.get("kind", "empty")):
		"source":
			return source_texture
		"sink":
			return sink_texture
		"straight":
			return straight_texture
		"corner":
			return corner_texture
		"tee":
			return tee_texture
		"block":
			return block_texture
		"empty":
			return empty_texture
		_:
			return null

func _piece_rotation_radians(piece: Dictionary) -> float:
	var kind := String(piece.get("kind", "empty"))
	if kind == "empty" or kind == "block":
		return 0.0
	return float(int(piece.get("rot", 0))) * (PI * 0.5)
