extends Area2D
class_name PipeEnd

## The other end of this pipe. Must be another PipeEnd node in the same scene.
@export var linked_end: NodePath = NodePath("")

## Pixels above this node's global_position where the player is placed on exit.
@export var exit_offset: Vector2 = Vector2(0.0, -80.0)

## Seconds of input-lock given to the player after arriving at the exit.
@export var travel_cooldown: float = 0.4

signal pipe_available(can_use: bool)


var _resolved_end: PipeEnd = null 
var _bodies_inside: Array  = []    
var _busy: bool            = false 


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	await get_tree().process_frame
	if linked_end != NodePath(""):
		_resolved_end = get_node_or_null(linked_end) as PipeEnd
		if not _resolved_end:
			push_warning("PipeEnd '%s': linked_end path '%s' did not resolve." \
				% [name, linked_end])

	if has_node("Prompt"):
		$Prompt.visible = false


## Called by the Player when the player presses "interact" near this endpoint.
func transport(player: CharacterBody2D) -> bool:
	if _busy:
		return false
	if not _resolved_end:
		push_warning("PipeEnd '%s': no linked endpoint set." % name)
		return false

	_busy = true
	_resolved_end._busy = true  # lock the destination too so it can't fire back immediately

	player.set_meta("pipe_traveling", true)

	# ── Instant teleport to exit position ─────────────────────────────────────
	var exit_pos: Vector2 = _resolved_end.global_position + _resolved_end.exit_offset
	player.global_position = exit_pos
	player.velocity         = Vector2.ZERO

	await get_tree().create_timer(travel_cooldown).timeout
	player.set_meta("pipe_traveling", false)
	_busy              = false
	_resolved_end._busy = false

	return true


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	if body in _bodies_inside:
		return
	_bodies_inside.append(body)

	# Show the prompt label if present.
	if has_node("Prompt"):
		$Prompt.visible = true

	pipe_available.emit(true)
	if body.has_method("_on_pipe_entered"):
		body._on_pipe_entered(self)

func _on_body_exited(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	_bodies_inside.erase(body)

	if _bodies_inside.is_empty() and has_node("Prompt"):
		$Prompt.visible = false

	pipe_available.emit(false)
	if body.has_method("_on_pipe_exited"):
		body._on_pipe_exited(self)
