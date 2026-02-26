extends Area2D

## When a body enters, if it's the player (has "tag" = "player" and a die method), the player dies.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.get_meta("tag", "") != "player":
		return
	if body.has_method("die"):
		body.die()
