
extends Camera2D


@export var player_path: NodePath = NodePath("../CharacterBody2D")

@export var room_size: Vector2 = Vector2(1024.0, 1024.0)

@export var transition_duration: float = 0.45

@export_enum("Linear:0", "EaseIn:1", "EaseOut:2", "EaseInOut:3") \
		var transition_ease: int = 3  # EaseInOut

@export_enum(
		"Linear:0","Sine:1","Quint:2","Quart:3",
		"Quad:4","Expo:5","Elastic:6","Cubic:7",
		"Circ:8","Bounce:9","Back:10","Spring:11"
) var transition_trans: int = 7 


var _player:       Node2D          
var _current_room: Vector2i        
var _tween:        Tween           


func _ready() -> void:
	position_smoothing_enabled = false
	drag_horizontal_enabled    = false
	drag_vertical_enabled      = false

	_player = get_node(player_path) as Node2D
	if not _player:
		push_error("RoomCamera: player_path '%s' did not resolve to a Node2D." % player_path)
		return

	_current_room   = _get_room_coords(_player.global_position)
	global_position = _room_center(_current_room)

func _physics_process(_delta: float) -> void:
	if not _player:
		return

	var new_room := _get_room_coords(_player.global_position)

	if new_room != _current_room:
		_transition_to(new_room)
		_current_room = new_room


func _get_room_coords(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / room_size.x),
		floori(world_pos.y / room_size.y)
	)

func _room_center(room: Vector2i) -> Vector2:
	return Vector2(
		room.x * room_size.x + room_size.x * 0.5,
		room.y * room_size.y + room_size.y * 0.5
	)

func _transition_to(room: Vector2i) -> void:
	var target := _room_center(room)

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()

	_tween.set_trans(_int_to_trans(transition_trans))
	_tween.set_ease(_int_to_ease(transition_ease))

	_tween.tween_property(self, "global_position", target, transition_duration)

func _int_to_trans(idx: int) -> Tween.TransitionType:
	match idx:
		0:  return Tween.TRANS_LINEAR
		1:  return Tween.TRANS_SINE
		2:  return Tween.TRANS_QUINT
		3:  return Tween.TRANS_QUART
		4:  return Tween.TRANS_QUAD
		5:  return Tween.TRANS_EXPO
		6:  return Tween.TRANS_ELASTIC
		7:  return Tween.TRANS_CUBIC
		8:  return Tween.TRANS_CIRC
		9:  return Tween.TRANS_BOUNCE
		10: return Tween.TRANS_BACK
		11: return Tween.TRANS_SPRING
		_:  return Tween.TRANS_CUBIC

func _int_to_ease(idx: int) -> Tween.EaseType:
	match idx:
		0:  return Tween.EASE_IN
		1:  return Tween.EASE_IN
		2:  return Tween.EASE_OUT
		3:  return Tween.EASE_IN_OUT
		_:  return Tween.EASE_IN_OUT
