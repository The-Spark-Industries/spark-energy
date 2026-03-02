extends Area2D

## Water is solid. When the player touches it:
## - If they CANNOT walk on water, they die immediately.
## - If they CAN walk on water, they get a short grace period (handled by the player script).

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.get_meta("tag", "") != "player":
		return
	# Let the player decide whether to die immediately or after a grace period.
	if body.has_method("entered_water"):
		body.entered_water()
	elif body.has_method("die"):
		body.die()

func _on_body_exited(body: Node2D) -> void:
	if body.get_meta("tag", "") != "player":
		return
	if body.has_method("exited_water"):
		body.exited_water()
