extends Area2D

## When the player enters this area, it becomes the current respawn point.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.get_meta("tag", "") != "player":
		return
	Global.set_checkpoint(global_position)
