extends Control

const MAP_ROWS := 5
const MAP_COLS := 5
const TOTAL_ROOMS := MAP_ROWS * MAP_COLS

const MAP_BACKGROUND_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const MAP_PANEL_COLOR := Color(0.08, 0.08, 0.08, 0.9)
const MAP_ROOM_COLOR := Color(0.25, 0.25, 0.25, 1.0)
const MAP_ACTIVE_ROOM_COLOR := Color(0.95, 0.85, 0.2, 1.0)

var _map_visible := false
var _map_backdrop: ColorRect
var _map_panel: Panel
var _map_grid: GridContainer
var _map_cells: Array[ColorRect] = []

var _room_camera: Camera2D
var _ordered_room_nodes: Array[Node2D] = []
var _current_room_index := -1

@onready var _inventory_icon: Sprite2D = %Icon

func _ready() -> void:
	print(Global.inventory)
	if Global.inventory.size() == 0:
		_inventory_icon.visible = false

	_room_camera = get_parent() as Camera2D
	_setup_map_ui()
	_refresh_room_nodes()
	_update_map_highlight()


#Checks if there's anything in the inventory, to add it. Meant for the start of the game.
func _process(delta: float) -> void:
	if Global.inventory.size() == 0:
		_inventory_icon.visible = false
	else:
		_inventory_icon.visible = true

	if _map_visible:
		_update_map_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_toggle"):
		_toggle_map()
		get_viewport().set_input_as_handled()

func _toggle_map() -> void:
	_map_visible = not _map_visible
	_map_backdrop.visible = _map_visible
	if _map_visible:
		_refresh_room_nodes()
		_update_map_highlight()

func _setup_map_ui() -> void:
	_map_backdrop = ColorRect.new()
	_map_backdrop.name = "MapBackdrop"
	_map_backdrop.layout_mode = 1
	_map_backdrop.anchors_preset = 15
	_map_backdrop.anchor_right = 1.0
	_map_backdrop.anchor_bottom = 1.0
	_map_backdrop.color = MAP_BACKGROUND_COLOR
	_map_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_backdrop.visible = false
	add_child(_map_backdrop)

	_map_panel = Panel.new()
	_map_panel.name = "MapPanel"
	_map_panel.layout_mode = 1
	_map_panel.anchors_preset = 8  # Center
	_map_panel.anchor_left = 0.5
	_map_panel.anchor_top = 0.5
	_map_panel.anchor_right = 0.5
	_map_panel.anchor_bottom = 0.5
	_map_panel.offset_left = -400.0
	_map_panel.offset_top = -240.0
	_map_panel.offset_right = 400.0
	_map_panel.offset_bottom = 240.0
	_map_panel.grow_horizontal = 2
	_map_panel.grow_vertical = 2
	_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_backdrop.add_child(_map_panel)

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

	_map_grid = GridContainer.new()
	_map_grid.name = "MapGrid"
	_map_grid.layout_mode = 1
	_map_grid.anchors_preset = 15
	_map_grid.anchor_right = 1.0
	_map_grid.anchor_bottom = 1.0
	_map_grid.columns = MAP_COLS
	_map_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_grid.add_theme_constant_override("h_separation", 12)
	_map_grid.add_theme_constant_override("v_separation", 12)
	_map_panel.add_child(_map_grid)

	for _i in range(TOTAL_ROOMS):
		var cell := ColorRect.new()
		cell.custom_minimum_size = Vector2(110.0, 70.0)
		cell.color = MAP_ROOM_COLOR
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map_grid.add_child(cell)
		_map_cells.append(cell)

func _refresh_room_nodes() -> void:
	_ordered_room_nodes.clear()
	if _room_camera == null:
		return

	if _room_camera.has_method("get_camera_targets"):
		var targets: Array = _room_camera.call("get_camera_targets")
		for target in targets:
			if target is Node2D:
				_ordered_room_nodes.append(target as Node2D)

	_ordered_room_nodes.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		if absf(a.global_position.y - b.global_position.y) > 0.1:
			return a.global_position.y < b.global_position.y
		return a.global_position.x < b.global_position.x
	)

func _update_map_highlight() -> void:
	for cell in _map_cells:
		cell.color = MAP_ROOM_COLOR

	if _room_camera == null or _ordered_room_nodes.is_empty():
		return

	var current_target: Node2D = null
	if _room_camera.has_method("get_current_target"):
		current_target = _room_camera.call("get_current_target") as Node2D

	if current_target == null:
		return

	_current_room_index = _ordered_room_nodes.find(current_target)
	if _current_room_index >= 0 and _current_room_index < _map_cells.size():
		_map_cells[_current_room_index].color = MAP_ACTIVE_ROOM_COLOR
