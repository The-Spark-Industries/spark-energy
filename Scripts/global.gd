extends Node

## Last checkpoint position the player touched. Used for respawn on death.
var last_checkpoint_position: Vector2 = Vector2.ZERO

func set_checkpoint(pos: Vector2) -> void:
	last_checkpoint_position = pos
