extends Camera2D

## Assign a node whose children are camera targets (e.g. empty Node2D with child Node2Ds).
## Whichever child is closest to the player becomes the camera position.
@export var camera_targets_path: NodePath = NodePath("")

## If camera_targets_path is empty, nodes in this group are used as targets.
@export var camera_targets_group: StringName = &"camera_points"

@export var player_path: NodePath = NodePath("../CharacterBody2D")
@export var transition_duration: float = 0.45
@export_enum("Linear:0", "EaseIn:1", "EaseOut:2", "EaseInOut:3") \
		var transition_ease: int = 3
@export_enum(
		"Linear:0","Sine:1","Quint:2","Quart:3",
		"Quad:4","Expo:5","Elastic:6","Cubic:7",
		"Circ:8","Bounce:9","Back:10","Spring:11"
) var transition_trans: int = 7

var _player: Node2D
var _targets: Array[Node2D] = []
var _current_target: Node2D
var _tween: Tween

func _ready() -> void:
	position_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false

	_player = get_node_or_null(player_path) as Node2D
	if not _player:
		push_error("RoomCamera: player_path '%s' did not resolve to a Node2D." % player_path)

	_refresh_targets()
	if _targets.is_empty():
		push_warning("RoomCamera: No camera target nodes found. Add children to the camera_targets_path node, or add nodes to group '%s'." % camera_targets_group)
	else:
		_current_target = _closest_target_to(_player.global_position)
		if _current_target:
			global_position = _current_target.global_position

func _physics_process(_delta: float) -> void:
	if not _player or _targets.is_empty():
		return

	var closest := _closest_target_to(_player.global_position)
	if closest and closest != _current_target:
		_current_target = closest
		_transition_to(closest.global_position)

func _refresh_targets() -> void:
	_targets.clear()
	if camera_targets_path != NodePath(""):
		var container = get_node_or_null(camera_targets_path)
		if container:
			for child in container.get_children():
				if child is Node2D:
					_targets.append(child as Node2D)
	if _targets.is_empty() and camera_targets_group:
		for node in get_tree().get_nodes_in_group(camera_targets_group):
			if node is Node2D:
				_targets.append(node as Node2D)

func _closest_target_to(world_pos: Vector2) -> Node2D:
	if _targets.is_empty():
		return null
	var best: Node2D = _targets[0]
	var best_d := world_pos.distance_squared_to(best.global_position)
	for i in range(1, _targets.size()):
		var t: Node2D = _targets[i]
		var d := world_pos.distance_squared_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best

func _transition_to(target_pos: Vector2) -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(_int_to_trans(transition_trans))
	_tween.set_ease(_int_to_ease(transition_ease))
	_tween.tween_property(self, "global_position", target_pos, transition_duration)

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
