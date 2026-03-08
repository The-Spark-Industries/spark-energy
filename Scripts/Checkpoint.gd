extends Area2D

## When the player enters this area, it becomes the current respawn point.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.get_meta("tag", "") != "player":
		return

	var scene_path := ""
	if get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path

	Global.set_checkpoint(global_position, scene_path)
