extends Area2D
class_name WireEnd

# True = this endpoint sits at progress_ratio 0 (start of the Path2D curve).
# False = this endpoint sits at progress_ratio 1 (end of the curve).
# In each WirePath, exactly ONE WireEnd should be is_start = true.
@export var is_start: bool = true


var _wire_path: Node = null          # parent WirePath
var _bodies_inside: Array = []       # players currently in range


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var parent := get_parent()
	if parent and parent.has_method("register_end"):
		_wire_path = parent
		_wire_path.register_end(self, is_start)
	else:
		push_warning("WireEnd '%s': parent is not a WirePath." % name)

	# Hide the optional Prompt label.
	if has_node("Prompt"):
		$Prompt.visible = false


func transport(player: CharacterBody2D) -> bool:
	if not _wire_path:
		return false
	return await _wire_path.begin_travel(player, self)


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	if body in _bodies_inside:
		return
	_bodies_inside.append(body)

	if has_node("Prompt"):
		$Prompt.visible = true

	# Tell the player it entered a wire endpoint.
	if body.has_method("_on_pipe_entered"):
		body._on_pipe_entered(self)

func _on_body_exited(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	_bodies_inside.erase(body)

	if _bodies_inside.is_empty() and has_node("Prompt"):
		$Prompt.visible = false

	if body.has_method("_on_pipe_exited"):
		body._on_pipe_exited(self)
