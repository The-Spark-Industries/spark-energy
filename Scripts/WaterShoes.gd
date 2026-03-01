extends Area2D

## Pickup that grants the ability to walk on water.
## When the player touches this, their `can_walk_on_water` flag is set to true.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.get_meta("tag", "") != "player":
		return

	# Safely set the flag on the player script, if it exists.
	if "can_walk_on_water" in body:
		body.can_walk_on_water = true

	queue_free()
