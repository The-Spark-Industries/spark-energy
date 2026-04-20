extends Area2D

## Water is lethal. When the player touches this Area2D (via its CollisionShape2D), they die immediately.

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.get_meta("tag", "") != "player":
		return
	if body.has_method("die"):
		body.die()

func _on_body_exited(body: Node2D) -> void:
	if body.get_meta("tag", "") != "player":
		return
	if body.has_method("exited_water"):
		body.exited_water()
