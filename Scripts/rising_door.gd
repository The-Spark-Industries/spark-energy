extends Node2D

@export_group("Descending Safety")
@export var shove_player_underneath: bool = true
@export_range(0.0, 2000.0, 1.0) var shove_speed: float = 900.0
@export_range(0.0, 64.0, 0.5) var shove_clearance: float = 6.0
@export_range(0.0, 64.0, 0.5) var underside_contact_band: float = 8.0
@export_range(0.0, 500.0, 0.1) var min_descend_speed: float = 1.0

var _door_body: StaticBody2D = null
var _prev_global_position: Vector2 = Vector2.ZERO
var _door_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_door_body = get_node_or_null("StaticBody2D") as StaticBody2D
	_prev_global_position = global_position

func _process(delta: float) -> void:
	if (self.name=="risingDoorLeftMiddle"):
		print("confirm")
		if (Global.maze_resetter==1):
			self.position.x=-416
			self.position.y=-520



func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	var delta_motion := global_position - _prev_global_position
	_door_velocity = delta_motion / delta
	_prev_global_position = global_position

	_maybe_shove_player_from_underneath(delta)

func _maybe_shove_player_from_underneath(delta: float) -> void:
	if not shove_player_underneath:
		return
	if _door_body == null:
		return
	if _door_velocity.y <= min_descend_speed:
		return
	if absf(_door_velocity.x) > 0.01:
		return

	var door_rect := _collision_rect_in_global(_door_body)
	if door_rect.size == Vector2.ZERO:
		return

	for player in _player_bodies_in_scene():
		var player_rect := _collision_rect_in_global(player)
		if player_rect.size == Vector2.ZERO:
			continue
		if not _is_underneath_contact_band(door_rect, player_rect):
			continue

		var target_x := _target_shove_center_x(door_rect, player_rect)
		var current_x := player.global_position.x
		var next_x := move_toward(current_x, target_x, shove_speed * delta)
		var delta_x := next_x - current_x
		if is_zero_approx(delta_x):
			continue

		player.global_position.x = next_x
		player.velocity.x = delta_x / delta

func _player_bodies_in_scene() -> Array[CharacterBody2D]:
	var players: Array[CharacterBody2D] = []
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody2D:
			players.append(node as CharacterBody2D)
	return players

func _is_underneath_contact_band(door_rect: Rect2, player_rect: Rect2) -> bool:
	var door_left := door_rect.position.x
	var door_right := door_left + door_rect.size.x
	var door_bottom := door_rect.position.y + door_rect.size.y
	var player_left := player_rect.position.x
	var player_right := player_left + player_rect.size.x
	var player_top := player_rect.position.y
	var player_bottom := player_top + player_rect.size.y

	var horizontal_overlap := player_right > door_left and player_left < door_right
	if not horizontal_overlap:
		return false

	return player_top <= door_bottom + underside_contact_band and player_bottom >= door_bottom - underside_contact_band

func _target_shove_center_x(door_rect: Rect2, player_rect: Rect2) -> float:
	var door_left := door_rect.position.x
	var door_right := door_left + door_rect.size.x
	var player_half_width := player_rect.size.x * 0.5
	var player_center_x := player_rect.position.x + player_half_width

	var left_target := door_left - player_half_width - shove_clearance
	var right_target := door_right + player_half_width + shove_clearance

	if absf(player_center_x - left_target) <= absf(player_center_x - right_target):
		return left_target
	return right_target

func _collision_rect_in_global(body: Node2D) -> Rect2:
	var shape_node := _first_enabled_collision_shape(body)
	if shape_node == null or shape_node.shape == null:
		return Rect2()

	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return Rect2()

	var center := shape_node.global_position
	var half := rect_shape.size * 0.5
	return Rect2(center - half, rect_shape.size)

func _first_enabled_collision_shape(parent: Node) -> CollisionShape2D:
	for child in parent.get_children():
		if child is CollisionShape2D:
			var shape := child as CollisionShape2D
			if not shape.disabled:
				return shape
	return null
