extends Control

var _room_camera: Camera2D
var _ordered_room_nodes: Array[Node2D] = []

@onready var _inventory_icon: Sprite2D = %Icon
@onready var _map_popup: Control = get_node_or_null("MapPopup") as Control

func _ready() -> void:
	_inventory_icon.visible = Global.inventory.size() > 0
	_room_camera = get_parent() as Camera2D
	set_process_input(true)

	if _map_popup == null:
		push_error("gameInterface: MapPopup child node not found.")
		return

	_refresh_room_nodes()
	if _map_popup and _map_popup.has_method("set_rooms"):
		_map_popup.call("set_rooms", _ordered_room_nodes)
	_update_map_current_room()


#Checks if there's anything in the inventory, to add it. Meant for the start of the game.
func _process(delta: float) -> void:
	_inventory_icon.visible = Global.inventory.size() > 0

	if _map_popup and _map_popup.has_method("is_open") and _map_popup.call("is_open"):
		_update_map_current_room()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("map_toggle"):
		_toggle_map()
		get_viewport().set_input_as_handled()

func _toggle_map() -> void:
	if _map_popup == null:
		push_error("MapPopup node not found in gameInterface scene")
		return

	_map_popup.call("toggle")
	if _map_popup.call("is_open"):
		_refresh_room_nodes()
		if _map_popup.has_method("set_rooms"):
			_map_popup.call("set_rooms", _ordered_room_nodes)
		_update_map_current_room()

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

func _update_map_current_room() -> void:
	if _room_camera == null or _map_popup == null:
		return

	var current_target: Node2D = null
	if _room_camera.has_method("get_current_target"):
		current_target = _room_camera.call("get_current_target") as Node2D

	if current_target == null:
		return

	if _map_popup.has_method("set_current_room"):
		_map_popup.call("set_current_room", current_target)
