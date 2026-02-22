extends Node2D
class_name WirePath

@export var travel_duration: float = 0.6

## Offset applied at the exit endpoint so the player doesn't overlap it.
@export var exit_offset: Vector2 = Vector2(0.0, -80.0)

## Easing for the travel animation.
@export_enum("Linear:0","Sine:1","Cubic:2","Quad:3","Quart:4","Expo:5") \
		var travel_curve: int = 2  # Cubic by default

# ── Internal refs (set automatically) ─────────────────────────────────────────

var _path_follow: PathFollow2D = null
var _end_a: Node = null        # WireEnd at progress=0 (start)
var _end_b: Node = null        # WireEnd at progress=1 (end)
var _traveling_player: CharacterBody2D = null  # non-null while traveling
var _tween: Tween = null
var _busy: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Find the Path2D and its PathFollow2D child.
	for child in get_children():
		if child is Path2D:
			for sub in child.get_children():
				if sub is PathFollow2D:
					_path_follow = sub
					break
			break

	if not _path_follow:
		push_error("WirePath '%s': needs a Path2D with a PathFollow2D child." % name)
		return

	_path_follow.rotates = false
	_path_follow.loop = false

func _process(_delta: float) -> void:
	if _traveling_player and _path_follow:
		_traveling_player.global_position = _path_follow.global_position


func register_end(wire_end: Node, is_start: bool) -> void:
	if is_start:
		_end_a = wire_end
	else:
		_end_b = wire_end

func get_other_end(wire_end: Node) -> Node:
	if wire_end == _end_a:
		return _end_b
	return _end_a

func begin_travel(player: CharacterBody2D, from_end: Node) -> bool:
	if _busy:
		return false
	if not _path_follow:
		return false
	if not _end_a or not _end_b:
		push_warning("WirePath '%s': both EndA and EndB must be registered." % name)
		return false

	_busy = true
	_traveling_player = player

	player.set_meta("pipe_traveling", true)
	player.velocity = Vector2.ZERO

	var start_progress: float
	var end_progress: float
	var exit_end: Node

	if from_end == _end_a:
		start_progress = 0.0
		end_progress = 1.0
		exit_end = _end_b
	else:
		start_progress = 1.0
		end_progress = 0.0
		exit_end = _end_a

	_path_follow.progress_ratio = start_progress

	player.global_position = _path_follow.global_position

	# Tween the path follower's progress_ratio from start → end.
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(_idx_to_trans(travel_curve))
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_path_follow, "progress_ratio", end_progress, travel_duration)

	await _tween.finished

	player.global_position = exit_end.global_position + exit_offset
	player.velocity = Vector2.ZERO

	await get_tree().create_timer(0.15).timeout

	player.set_meta("pipe_traveling", false)
	_traveling_player = null
	_busy = false

	return true

func _idx_to_trans(idx: int) -> Tween.TransitionType:
	match idx:
		0: return Tween.TRANS_LINEAR
		1: return Tween.TRANS_SINE
		2: return Tween.TRANS_CUBIC
		3: return Tween.TRANS_QUAD
		4: return Tween.TRANS_QUART
		5: return Tween.TRANS_EXPO
		_: return Tween.TRANS_CUBIC
