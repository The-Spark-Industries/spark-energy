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
	var room_id := _room_id_for_position(global_position)

	Global.set_checkpoint(global_position, scene_path, room_id)

func _room_id_for_position(world_pos: Vector2) -> String:
	if not get_tree() or get_tree().current_scene == null:
		return ""

	var room_camera := get_tree().current_scene.get_node_or_null("RoomCamera")
	if room_camera and room_camera.has_method("get_camera_targets"):
		var targets: Array = room_camera.call("get_camera_targets")
		if not targets.is_empty():
			var best_target: Node2D = null
			var best_dist := INF
			for target in targets:
				if target is Node2D:
					var target_node := target as Node2D
					var dist := world_pos.distance_squared_to(target_node.global_position)
					if dist < best_dist:
						best_dist = dist
						best_target = target_node
			if best_target:
				return best_target.name

	return ""
