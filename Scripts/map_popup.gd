extends Control

const MAP_ROWS := 5
const MAP_COLS := 5
const TOTAL_ROOMS := MAP_ROWS * MAP_COLS

const MAP_BACKGROUND_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const MAP_PANEL_COLOR := Color(0.08, 0.08, 0.08, 0.9)
const MAP_ROOM_COLOR := Color(0.25, 0.25, 0.25, 1.0)
const MAP_ACTIVE_ROOM_COLOR := Color(0.95, 0.85, 0.2, 1.0)
const MAP_CELL_SIZE := Vector2(150.0, 87.5)

@onready var _map_backdrop: ColorRect = get_node_or_null("MapBackdrop") as ColorRect
@onready var _map_panel: Panel = get_node_or_null("MapBackdrop/MapPanel") as Panel
@onready var _map_grid: GridContainer = get_node_or_null("MapBackdrop/MapPanel/MapCenter/MapGrid") as GridContainer

var _map_cells: Array[ColorRect] = []
var _ordered_room_nodes: Array[Node2D] = []
var _current_room: Node2D

func _ready() -> void:
	if _map_backdrop == null or _map_panel == null or _map_grid == null:
		push_error("MapPopup: Missing required nodes (MapBackdrop/MapPanel/MapCenter/MapGrid).")
		return

	_setup_panel_style()
	_build_grid_cells()
	_map_backdrop.visible = false

func toggle() -> void:
	if _map_backdrop == null:
		return
	_map_backdrop.visible = not _map_backdrop.visible

func is_open() -> bool:
	if _map_backdrop == null:
		return false
	return _map_backdrop.visible

func set_rooms(room_nodes: Array[Node2D]) -> void:
	_ordered_room_nodes = room_nodes.duplicate()
	_ordered_room_nodes.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		if absf(a.global_position.y - b.global_position.y) > 0.1:
			return a.global_position.y < b.global_position.y
		return a.global_position.x < b.global_position.x
	)
	_update_highlight()

func set_current_room(room: Node2D) -> void:
	_current_room = room
	_update_highlight()

func _setup_panel_style() -> void:
	if _map_backdrop == null or _map_panel == null:
		return

	_map_backdrop.color = MAP_BACKGROUND_COLOR

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = MAP_PANEL_COLOR
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.content_margin_left = 24
	panel_style.content_margin_top = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_bottom = 24
	_map_panel.add_theme_stylebox_override("panel", panel_style)

func _build_grid_cells() -> void:
	if _map_grid == null:
		return

	for child in _map_grid.get_children():
		child.queue_free()
	_map_cells.clear()

	for _i in range(TOTAL_ROOMS):
		var cell := ColorRect.new()
		cell.custom_minimum_size = MAP_CELL_SIZE
		cell.color = MAP_ROOM_COLOR
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map_grid.add_child(cell)
		_map_cells.append(cell)

func _update_highlight() -> void:
	for cell in _map_cells:
		cell.color = MAP_ROOM_COLOR

	if _ordered_room_nodes.is_empty() or _current_room == null:
		return

	var room_index := _ordered_room_nodes.find(_current_room)
	if room_index >= 0 and room_index < _map_cells.size():
		_map_cells[room_index].color = MAP_ACTIVE_ROOM_COLOR
