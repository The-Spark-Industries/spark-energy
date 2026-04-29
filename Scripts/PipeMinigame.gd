@tool
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
@export var straight_textures: Array[Texture2D] = [
	preload("res://Level 1/Level 1 Art Assets/Environment/Props/Pipes/Pipe1_Dirty1.png"),
	preload("res://Level 1/Level 1 Art Assets/Environment/Props/Pipes/Pipe1_Dirty2.png"),
	preload("res://Level 1/Level 1 Art Assets/Environment/Props/Pipes/Pipe1_Dirty3.png")
]
@export var corner_textures: Array[Texture2D] = [
	preload("res://Level 1/Level 1 Art Assets/Environment/Props/Pipes/Pipe3_Dirty1.png"),
	preload("res://Level 1/Level 1 Art Assets/Environment/Props/Pipes/Pipe3_Dirty2.png"),
	preload("res://Level 1/Level 1 Art Assets/Environment/Props/Pipes/Pipe3_Dirty3.png")
]
@export var tee_textures: Array[Texture2D] = [
	preload("res://Level 1/Level 1 Art Assets/Environment/Props/Pipes/Pipe2_Dirty1.png"),
	preload("res://Level 1/Level 1 Art Assets/Environment/Props/Pipes/Pipe2_Dirty2.png"),
	preload("res://Level 1/Level 1 Art Assets/Environment/Props/Pipes/Pipe2_Dirty3.png")
]
@export var block_texture: Texture2D
@export var empty_texture: Texture2D
@export_group("Powered Visuals")
@export var powered_source_texture: Texture2D
@export var powered_sink_texture: Texture2D
@export var powered_straight_texture: Texture2D
@export var powered_corner_texture: Texture2D
@export var powered_tee_texture: Texture2D
@export var powered_block_texture: Texture2D
@export var powered_empty_texture: Texture2D
@export var powered_straight_textures: Array[Texture2D] = []
@export var powered_corner_textures: Array[Texture2D] = []
@export var powered_tee_textures: Array[Texture2D] = []
@export_group("Flow")
@export var auto_flow_preview: bool = false
@export var auto_flow_completes: bool = false
@export var corner_connector_rot_offset: int = 0
@export var tee_connector_rot_offset: int = 0
@export var solved_close_delay: float = 2.7
@export var embedded_mode: bool = false
@export var embedded_use_glyphs: bool = false
@export var embedded_cell_size: float = 48.0
@export_group("Embedded Placement")
@export var embedded_anchor_path: NodePath
@export var embedded_anchor_centered: bool = true
@export var embedded_anchor_offset: Vector2 = Vector2.ZERO

@onready var _root_panel: PanelContainer = $CenterContainer/PanelContainer
@onready var _title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Title
@onready var _info_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Info
@onready var _grid: GridContainer = $CenterContainer/PanelContainer/VBoxContainer/Grid
@onready var _status_label: Label = $CenterContainer/PanelContainer/VBoxContainer/Footer/Status
@onready var _send_button: Button = $CenterContainer/PanelContainer/VBoxContainer/Footer/SendWaterButton
@onready var _backdrop: ColorRect = $Backdrop
@onready var _sfx_init: AudioStreamPlayer = get_node_or_null("TerminalInitialize")
@onready var _sfx_move: AudioStreamPlayer = get_node_or_null("TerminalMoveSound")
@onready var _sfx_pipe: AudioStreamPlayer = get_node_or_null("PipeSoundTest")
@onready var _sfx_complete: AudioStreamPlayer = get_node_or_null("PuzzleComplete")

var _player: CharacterBody2D = null
var _cells: Array[PanelContainer] = []
var _cell_labels: Array[Label] = []
var _cell_icons: Array[Sprite2D] = []
var _pieces: Array[Dictionary] = []
var _puzzle: PipePuzzleDefinition = null
var _grid_size: int = 3
var _grid_height: int = 3

var _cursor_index: int = 0
var _grabbed_index: int = -1
var _active: bool = false
var _solved: bool = false
var _control_mode: int = 0  # 0: normal, 1: move-only, 2: rotate-only
var _embedded_refresh_pending: bool = false
var _debug_preview: bool = false
var _embedded_anchor_node: Node2D = null
var _embedded_anchor_is_internal: bool = false
var _embedded_anchor_global_target: Vector2 = Vector2.ZERO

func set_debug_preview(enabled: bool) -> void:
	_debug_preview = enabled

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	if not embedded_mode:
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 1.0
		anchor_bottom = 1.0
		offset_left = 0.0
		offset_top = 0.0
		offset_right = 0.0
		offset_bottom = 0.0
	if not _active and not embedded_mode:
		visible = false
	_apply_visual_overrides()
	_send_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_send_button.pressed.connect(_on_send_water_pressed)
	_send_button.visible = not auto_flow_completes
	if embedded_mode:
		$Backdrop.visible = false
		_root_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		$CenterContainer/PanelContainer/VBoxContainer/Title.visible = false
		$CenterContainer/PanelContainer/VBoxContainer/Info.visible = false
		$CenterContainer/PanelContainer/VBoxContainer/Footer.visible = true
		$CenterContainer/PanelContainer/VBoxContainer/Footer/Status.visible = true
		$CenterContainer/PanelContainer/VBoxContainer/Footer/Status.modulate = Color(1, 1, 1, 0)
		$CenterContainer/PanelContainer/VBoxContainer/Footer/SendWaterButton.text = "Send Water"
		_ensure_embedded_rect_size()
		if Engine.is_editor_hint():
			visible = true
			if _puzzle == null:
				_puzzle = PipePuzzleDefinition.create_default()
				_grid_size = _puzzle.grid_width
				_grid_height = _puzzle.grid_height
			_reset_puzzle()
			return
		_resolve_embedded_anchor_node()
		set_process(_embedded_anchor_node != null and not _embedded_anchor_is_internal)
		if _embedded_anchor_node != null:
			call_deferred("_update_embedded_anchor_position")
	if embedded_mode:
		# Embedded boards should render immediately as in-world previews.
		# Input remains locked because _active is still false until interact().
		visible = true
		if _puzzle == null:
			_puzzle = PipePuzzleDefinition.create_default()
			_grid_size = _puzzle.grid_width
			_grid_height = _puzzle.grid_height
		_request_embedded_refresh()
		return
	_reset_puzzle()


func _process(delta: float) -> void:
	if (Global.fontChoice==0):
		self.theme=load("res://Assets/Visual/Lingua.tres")
		$CenterContainer/PanelContainer/VBoxContainer/Footer/SendWaterButton.theme=load("res://Assets/Visual/Lingua.tres")
		
	if (Global.fontChoice==1):
		self.theme=load("res://Assets/Visual/lingualight.tres")
		$CenterContainer/PanelContainer/VBoxContainer/Footer/SendWaterButton.theme=load("res://Assets/Visual/lingualight.tres")
	if (Global.fontChoice==2):
		self.theme=load("res://Assets/Visual/Receipt.tres")
		$CenterContainer/PanelContainer/VBoxContainer/Footer/SendWaterButton.theme=load("res://Assets/Visual/Receipt.tres")
	if not embedded_mode:
		return
	if _embedded_anchor_is_internal:
		return
	_update_embedded_anchor_position()

func _ensure_embedded_rect_size() -> void:
	if not embedded_mode:
		return
	if size.x >= 8.0 and size.y >= 8.0:
		return
	var fallback_size := Vector2(352.0, 352.0)
	custom_minimum_size = fallback_size
	if is_equal_approx(offset_right, offset_left):
		offset_right = offset_left + fallback_size.x
	if is_equal_approx(offset_bottom, offset_top):
		offset_bottom = offset_top + fallback_size.y

func set_puzzle(puzzle: PipePuzzleDefinition) -> void:
	if puzzle == null:
		_puzzle = PipePuzzleDefinition.create_default()
	else:
		_puzzle = puzzle
	if _puzzle:
		_grid_size = _puzzle.grid_width
		_grid_height = _puzzle.grid_height
	if embedded_mode:
		visible = false
		if is_node_ready():
			_request_embedded_refresh()
		return
	if is_node_ready():
		_reset_puzzle()

func set_control_mode(mode: int) -> void:
	_control_mode = clampi(mode, 0, 2)

func refresh_embedded_preview() -> void:
	if not embedded_mode or _puzzle == null:
		return
	if not is_node_ready():
		return
	_request_embedded_refresh()

func _request_embedded_refresh() -> void:
	if not embedded_mode or _puzzle == null:
		return
	if _embedded_refresh_pending:
		return
	_embedded_refresh_pending = true
	if _debug_preview:
		print("[PipeMinigame] refresh requested: ", name)
	call_deferred("_apply_embedded_refresh")

func _apply_embedded_refresh() -> void:
	_embedded_refresh_pending = false
	if not embedded_mode or _puzzle == null or not is_node_ready():
		return
	_reset_puzzle()
	# Always show the embedded board after the first refresh; keep retrying signature sync in background.
	visible = true
	var puzzle_signature := get_puzzle_signature()
	var render_signature := get_render_signature()
	if _debug_preview:
		print("[PipeMinigame] apply refresh: ", name, " puzzle_sig=", puzzle_signature.left(120), " render_sig=", render_signature.left(120), " visible=", visible)
	if puzzle_signature.is_empty() or puzzle_signature != render_signature:
		await get_tree().process_frame
		call_deferred("_request_embedded_refresh")
		return
	if _debug_preview:
		print("[PipeMinigame] preview visible with matched signature: ", name)

func get_puzzle_signature() -> String:
	if _puzzle == null:
		return ""
	return _signature_from_pieces(_puzzle.pieces)

func get_render_signature() -> String:
	if _pieces.is_empty():
		return ""
	return _signature_from_pieces(_pieces)

func _signature_from_pieces(pieces: Array) -> String:
	if pieces.is_empty():
		return ""
	var parts: Array[String] = []
	parts.resize(pieces.size())
	for i in range(pieces.size()):
		var piece: Dictionary = pieces[i]
		parts[i] = "%s:%s:%s:%s" % [
			str(piece.get("kind", "")),
			str(piece.get("rot", 0)),
			str(piece.get("locked", false)),
			str(piece.get("dirt_level", 0))
		]
	return "|".join(parts)

func open_for_player(player: CharacterBody2D) -> void:
	if _active:
		#$"TerminalInitialize".play()
		return

	_player = player
	_active = true
	_solved = false
	Global.minigame_active = true
	visible = true
	if embedded_mode:
		_status_label.visible = true
		_status_label.modulate = Color(1, 1, 1, 1)
	call_deferred("_ensure_visible_on_top")
	_status_label.text = _controls_hint_text()
	if not _puzzle:
		_puzzle = PipePuzzleDefinition.create_default()
		_grid_size = _puzzle.grid_width
		_grid_height = _puzzle.grid_height
	_reset_puzzle()
	get_tree().paused = true

func close_minigame() -> void:
	_active = false
	if not embedded_mode:
		visible = false
	else:
		_title_label.visible = false
		_info_label.visible = false
		_status_label.visible = true
		_status_label.modulate = Color(1, 1, 1, 0)
	_grabbed_index = -1
	get_tree().paused = false
	Global.minigame_active = false

func _ensure_visible_on_top() -> void:
	visible = true
	if get_parent():
		get_parent().move_child(self, -1)

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
		if _grabbed_index != -1:
			_play_optional_sound(_sfx_move)
		if _grabbed_index == -1:
			_play_optional_sound(_sfx_move)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		dx = 1
		if _grabbed_index != -1:
			_play_optional_sound(_sfx_move)
		if _grabbed_index == -1:
			_play_optional_sound(_sfx_move)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		dy = -1
		if _grabbed_index != -1:
			_play_optional_sound(_sfx_move)
		if _grabbed_index == -1:
			_play_optional_sound(_sfx_move)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		dy = 1
		if _grabbed_index != -1:
			_play_optional_sound(_sfx_move)
		if _grabbed_index == -1:
			_play_optional_sound(_sfx_move)

	if dx != 0 or dy != 0:
		_move_cursor(dx, dy)
		get_viewport().set_input_as_handled()

func _play_optional_sound(sound_node: Node) -> void:
	if sound_node != null and sound_node.has_method("play"):
		sound_node.call("play")

func _build_grid_ui() -> void:
	for child in _grid.get_children():
		child.queue_free()

	_cells.clear()
	_cell_labels.clear()
	_cell_icons.clear()
	_grid.columns = _grid_size

	var separation_basis: int = max(_grid_size, _grid_height)
	var separation: int = 0 if embedded_mode else clampi(10 - ((separation_basis - 3) * 2), 3, 8)
	_grid.add_theme_constant_override("h_separation", separation)
	_grid.add_theme_constant_override("v_separation", separation)

	var layout_size := size
	if layout_size.x <= 0.0 or layout_size.y <= 0.0:
		layout_size = get_viewport_rect().size
	var cell_size: float = embedded_cell_size if embedded_mode else clampf(minf(
		(layout_size.x * 0.72 - float(separation * (_grid_size - 1))) / float(_grid_size),
		(layout_size.y * 0.45 - float(separation * (_grid_height - 1))) / float(_grid_height)
	), 32.0, 96.0)

	var panel_width: float = (cell_size * _grid_size) + float(separation * (_grid_size - 1)) + (16.0 if embedded_mode else 120.0)
	var panel_height: float = (cell_size * _grid_height) + float(separation * (_grid_height - 1)) + (84.0 if embedded_mode else 240.0)
	if not embedded_mode:
		panel_width = minf(layout_size.x * 0.92, maxf(380.0, panel_width))
		panel_height = minf(layout_size.y * 0.92, maxf(360.0, panel_height))
	_root_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	if embedded_mode:
		# Keep embedded board geometry fixed; do not let parent containers stretch cells.
		_root_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_root_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_grid.custom_minimum_size = Vector2(
			(cell_size * _grid_size) + float(separation * (_grid_size - 1)),
			(cell_size * _grid_height) + float(separation * (_grid_height - 1))
		)
	else:
		_root_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_root_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_grid.custom_minimum_size = Vector2.ZERO

	var glyph_font_size: int = int(clampf(cell_size * 0.6, 24.0, 62.0))

	for i in range(_grid_size * _grid_height):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
		cell.pivot_offset = Vector2(cell_size * 0.5, cell_size * 0.5)
		if embedded_mode:
			cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if cell_texture:
			cell.add_theme_stylebox_override("panel", _make_texture_stylebox(cell_texture))

		var icon := Sprite2D.new()
		icon.centered = true
		icon.position = Vector2(cell_size * 0.5, cell_size * 0.5)
		icon.scale = Vector2.ONE
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

	if embedded_mode and _embedded_anchor_node != null and not _active:
		call_deferred("_update_embedded_anchor_position")

func _resolve_embedded_anchor_node() -> void:
	_embedded_anchor_node = null
	_embedded_anchor_is_internal = false
	if String(embedded_anchor_path).is_empty():
		return
	_embedded_anchor_node = get_node_or_null(embedded_anchor_path) as Node2D
	if _embedded_anchor_node == null:
		push_warning("PipeMinigame: embedded_anchor_path does not point to a Node2D on %s" % name)
		return

	_embedded_anchor_is_internal = is_ancestor_of(_embedded_anchor_node)
	_embedded_anchor_global_target = _embedded_anchor_node.global_position

func _update_embedded_anchor_position() -> void:
	if not embedded_mode:
		return
	if _embedded_anchor_node == null:
		if not String(embedded_anchor_path).is_empty():
			_resolve_embedded_anchor_node()
		if _embedded_anchor_node == null:
			return

	var anchor_global := _embedded_anchor_global_target if _embedded_anchor_is_internal else _embedded_anchor_node.global_position
	var target_position := anchor_global + embedded_anchor_offset
	if embedded_anchor_centered:
		var panel_size := _root_panel.size
		if panel_size.x <= 0.0 or panel_size.y <= 0.0:
			panel_size = _root_panel.get_combined_minimum_size()
		target_position -= panel_size * 0.5
	global_position = target_position

func _reset_puzzle() -> void:
	if not _puzzle:
		_puzzle = PipePuzzleDefinition.create_default()
		_grid_size = _puzzle.grid_width
		_grid_height = _puzzle.grid_height
	else:
		_grid_size = _puzzle.grid_width
		_grid_height = _puzzle.grid_height

	_build_grid_ui()

	_pieces.clear()
	_pieces.resize(_puzzle.pieces.size())

	# Copy puzzle pieces into play area.
	for i in range(_puzzle.pieces.size()):
		_pieces[i] = _puzzle.pieces[i].duplicate()

	# Set cursor to center and start with nothing grabbed.
	var center_x: int = _grid_size / 2
	var center_y: int = _grid_height / 2
	_cursor_index = _idx(center_x, center_y)
	_grabbed_index = -1
	_title_label.text = _puzzle_display_name()
	_status_label.text = _controls_hint_text()
	_refresh_flow_state(false)
	# Re-apply visuals on next frame so TextureRect sizes are valid before rotation pivots are used.
	call_deferred("_refresh_flow_state", false)

func _puzzle_display_name() -> String:
	if _puzzle == null:
		return "Hidden Ports"
	var in_name := _port_location_name(_puzzle.source_pos)
	var out_name := _port_location_name(_puzzle.sink_pos)
	return "%dx%d hidden ports (%s, %s)" % [_grid_size, _grid_height, in_name, out_name]

func _port_location_name(pos: Vector2i) -> String:
	if pos.y < 0:
		return "TOP %s" % _axis_word(pos.x, _grid_size, "column")
	if pos.y >= _grid_height:
		return "BOTTOM %s" % _axis_word(pos.x, _grid_size, "column")
	if pos.x < 0:
		return "LEFT %s" % _axis_word(pos.y, _grid_height, "row")
	if pos.x >= _grid_size:
		return "RIGHT %s" % _axis_word(pos.y, _grid_height, "row")
	return "INSIDE (%d,%d)" % [pos.x, pos.y]

func _axis_word(index: int, count: int, axis: String) -> String:
	if index == 0:
		return "LEFT" if axis == "column" else "TOP"
	if index == count - 1:
		return "RIGHT" if axis == "column" else "BOTTOM"
	if count % 2 == 1 and index == int(count / 2):
		return "MIDDLE"
	return "%s %d" % [axis.to_upper(), index + 1]

func _toggle_select() -> void:
	if _grabbed_index == -1:
		if _can_pick(_cursor_index):
			_grabbed_index = _cursor_index
			_status_label.text = "Selected. Move with WASD, Enter to place."
	else:
		_grabbed_index = -1
		if auto_flow_completes:
			_status_label.text = "Piece placed. Power propagates automatically."
		else:
			_status_label.text = "Piece placed. Press Send Water when ready."

	_refresh_flow_state()

func _move_cursor(dx: int, dy: int) -> void:
	var current := _to_xy(_cursor_index)
	var nx: int = clampi(current.x + dx, 0, _grid_size - 1)
	var ny: int = clampi(current.y + dy, 0, _grid_height - 1)
	var target_index := _idx(nx, ny)

	if _can_move_pieces() and _grabbed_index != -1 and target_index != _grabbed_index:
		if _pieces[target_index].get("locked", false):
			return
		var moved_piece := _pieces[_grabbed_index]
		_pieces[_grabbed_index] = _pieces[target_index]
		_pieces[target_index] = moved_piece
		_grabbed_index = target_index
		$"TerminalMoveSound".play()

	_cursor_index = target_index
	_refresh_flow_state()

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
	$"RotationElectricity".play()
	_status_label.text = "Rotated piece."
	_refresh_flow_state()

func _can_move_pieces() -> bool:
	return _control_mode != 2

func _can_rotate_pieces() -> bool:
	return _control_mode != 1

func _controls_hint_text() -> String:
	match _control_mode:
		1:
			return "WASD: Move  Enter: Pick/Drop"
		2:
			return "WASD: Cursor  Q/E: Rotate"
		_:
			return "WASD: Move  Enter: Pick/Drop  Q/E: Rotate"

func _on_send_water_pressed() -> void:
	if not _active:
		return

	if auto_flow_completes:
		return

	var reached := _trace_flow_from_source()
	if _is_sink_reached(reached):
		_solved = true
		_status_label.text = "Water reached the end. Puzzle solved!"
		$"PuzzleComplete".play()
		_update_cells(reached)
		completed.emit(true)
		await get_tree().create_timer(2.7).timeout
		close_minigame()
	else:
		_status_label.text = "Flow failed before the end. Re-route the pipes."
		_update_cells(reached)

func _refresh_flow_state(allow_autocomplete: bool = true) -> void:
	if auto_flow_preview or auto_flow_completes:
		var reached := _trace_flow_from_source()
		_update_cells(reached)
		if allow_autocomplete and auto_flow_completes and _is_sink_reached(reached):
			call_deferred("_complete_from_auto_flow", reached)
		return

	_update_cells()

func _complete_from_auto_flow(reached: Array[int]) -> void:
	if not _active or _solved or not auto_flow_completes:
		return
	if not _is_sink_reached(reached):
		return
	await _handle_solved(reached, "Circuit complete. Tree is powered!")

func _is_sink_reached(reached: Array[int]) -> bool:
	if _puzzle == null:
		return false
	if not _is_in_grid(_puzzle.sink_pos):
		var sink_attachment := _virtual_port_attachment(_puzzle.sink_pos)
		if sink_attachment.is_empty():
			return false
		var sink_cell: Vector2i = sink_attachment["cell"]
		var sink_connector: int = int(sink_attachment["connector"])
		var sink_cell_idx := _idx(sink_cell.x, sink_cell.y)
		if not reached.has(sink_cell_idx):
			return false
		return _connectors(_pieces[sink_cell_idx]).has(sink_connector)
	var sink_idx := _idx(_puzzle.sink_pos.x, _puzzle.sink_pos.y)
	return reached.has(sink_idx)

func _handle_solved(reached: Array[int], solved_text: String) -> void:
	if _solved:
		return

	_solved = true
	_status_label.text = solved_text
	_play_sfx(_sfx_complete)
	_update_cells(reached)
	completed.emit(true)
	if solved_close_delay > 0.0:
		await get_tree().create_timer(solved_close_delay).timeout
	close_minigame()

func _trace_flow_from_source() -> Array[int]:
	var visited: Array[int] = []
	var queue: Array[int] = []

	if _is_in_grid(_puzzle.source_pos):
		queue.append(_idx(_puzzle.source_pos.x, _puzzle.source_pos.y))
	else:
		var source_attachment := _virtual_port_attachment(_puzzle.source_pos)
		if source_attachment.is_empty():
			return visited
		var source_cell: Vector2i = source_attachment["cell"]
		var source_connector: int = int(source_attachment["connector"])
		var source_cell_idx := _idx(source_cell.x, source_cell.y)
		if _connectors(_pieces[source_cell_idx]).has(source_connector):
			queue.append(source_cell_idx)
		else:
			return visited

	while queue.size() > 0:
		var current: int = queue.pop_front()
		if current in visited:
			continue
		visited.append(current)

		var connectors: Array[int] = _connectors(_pieces[current])
		var cxy := _to_xy(current)

		for d in connectors:
			var nxy := Vector2i(cxy.x, cxy.y) + _dir_to_vec(d)
			if nxy.x < 0 or nxy.x >= _grid_size or nxy.y < 0 or nxy.y >= _grid_height:
				continue

			var nidx := _idx(nxy.x, nxy.y)
			var n_connectors: Array[int] = _connectors(_pieces[nidx])
			if _opposite_dir(d) in n_connectors and not (nidx in visited):
				queue.append(nidx)

	return visited

func _is_in_grid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < _grid_size and pos.y >= 0 and pos.y < _grid_height

func _virtual_port_attachment(port_pos: Vector2i) -> Dictionary:
	if port_pos.y < 0 and port_pos.x >= 0 and port_pos.x < _grid_size:
		return {"cell": Vector2i(port_pos.x, 0), "connector": DIR_UP}
	if port_pos.y >= _grid_height and port_pos.x >= 0 and port_pos.x < _grid_size:
		return {"cell": Vector2i(port_pos.x, _grid_height - 1), "connector": DIR_DOWN}
	if port_pos.x < 0 and port_pos.y >= 0 and port_pos.y < _grid_height:
		return {"cell": Vector2i(0, port_pos.y), "connector": DIR_LEFT}
	if port_pos.x >= _grid_size and port_pos.y >= 0 and port_pos.y < _grid_height:
		return {"cell": Vector2i(_grid_size - 1, port_pos.y), "connector": DIR_RIGHT}
	return {}

func _update_cells(flow_cells: Array[int] = []) -> void:
	for i in range(_pieces.size()):
		var piece: Dictionary = _pieces[i]
		var use_texture := not (embedded_mode and embedded_use_glyphs)
		var piece_tex: Texture2D = _piece_texture(piece, i in flow_cells) if use_texture else null
		if piece_tex:
			_cell_icons[i].texture = piece_tex
			var pivot_basis := _cells[i].custom_minimum_size
			if pivot_basis.x <= 0.0 or pivot_basis.y <= 0.0:
				pivot_basis = _cells[i].size
			if pivot_basis.x <= 0.0 or pivot_basis.y <= 0.0:
				pivot_basis = Vector2(embedded_cell_size, embedded_cell_size)
			_cell_icons[i].position = pivot_basis * 0.5
			var tex_size := piece_tex.get_size()
			if tex_size.x > 0.0 and tex_size.y > 0.0:
				var target := Vector2(embedded_cell_size, embedded_cell_size) if embedded_mode else (pivot_basis - Vector2(12.0, 12.0))
				var fit_scale := minf(target.x / tex_size.x, target.y / tex_size.y)
				_cell_icons[i].scale = Vector2.ONE * fit_scale
			else:
				_cell_icons[i].scale = Vector2.ONE
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
	var rot := _connector_rot(piece)

	match kind:
		"source":
			match rot:
				0:
					return [DIR_RIGHT]
				1:
					return [DIR_DOWN]
				2:
					return [DIR_LEFT]
				_:
					return [DIR_UP]
		"sink":
			match rot:
				0:
					return [DIR_LEFT]
				1:
					return [DIR_UP]
				2:
					return [DIR_RIGHT]
				_:
					return [DIR_DOWN]
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
	var rot := _connector_rot(piece)

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

func _connector_rot(piece: Dictionary) -> int:
	var kind := String(piece.get("kind", "empty"))
	var rot := int(piece.get("rot", 0))
	match kind:
		"corner":
			rot += corner_connector_rot_offset
		"tee":
			rot += tee_connector_rot_offset
	return posmod(rot, 4)

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

func _piece_texture(piece: Dictionary, is_powered: bool = false) -> Texture2D:
	var dirt_level := int(piece.get("dirt_level", 0))
	match String(piece.get("kind", "empty")):
		"source":
			if is_powered and powered_source_texture:
				return powered_source_texture
			return source_texture
		"sink":
			if is_powered and powered_sink_texture:
				return powered_sink_texture
			return sink_texture
		"straight":
			if is_powered:
				return _resolve_variant_texture(powered_straight_textures, dirt_level, powered_straight_texture if powered_straight_texture else straight_texture)
			return _resolve_variant_texture(straight_textures, dirt_level, straight_texture)
		"corner":
			if is_powered:
				return _resolve_variant_texture(powered_corner_textures, dirt_level, powered_corner_texture if powered_corner_texture else corner_texture)
			return _resolve_variant_texture(corner_textures, dirt_level, corner_texture)
		"tee":
			if is_powered:
				return _resolve_variant_texture(powered_tee_textures, dirt_level, powered_tee_texture if powered_tee_texture else tee_texture)
			return _resolve_variant_texture(tee_textures, dirt_level, tee_texture)
		"block":
			if is_powered and powered_block_texture:
				return powered_block_texture
			return block_texture
		"empty":
			if is_powered and powered_empty_texture:
				return powered_empty_texture
			return empty_texture
		_:
			return null

func _resolve_variant_texture(variants: Array[Texture2D], dirt_level: int, fallback: Texture2D) -> Texture2D:
	if variants.is_empty():
		return fallback
	var idx := clampi(dirt_level, 0, variants.size() - 1)
	if variants[idx] != null:
		return variants[idx]
	return fallback

func _piece_rotation_radians(piece: Dictionary) -> float:
	var kind := String(piece.get("kind", "empty"))
	if kind == "empty" or kind == "block":
		return 0.0
	if kind == "straight":
		# Pipe1 artwork is authored as horizontal while rot=0 logic is vertical.
		return float(posmod(int(piece.get("rot", 0)) + 1, 4)) * (PI * 0.5)
	return float(int(piece.get("rot", 0))) * (PI * 0.5)

func _play_sfx(player: AudioStreamPlayer) -> void:
	if player:
		player.play()
