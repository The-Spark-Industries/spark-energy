extends Node

## Autoload singleton that provides a fade-to-black scene transition.
## Add this script as an Autoload (Project Settings -> AutoLoad) named `SceneTransition`.

@export var fade_duration: float = 0.5

var _busy: bool = false
var _overlay: CanvasLayer
var _rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create a CanvasLayer with a fullscreen black ColorRect
	_overlay = CanvasLayer.new()
	_overlay.layer = 200
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.offset_left = 0.0
	_rect.offset_top = 0.0
	_rect.offset_right = 0.0
	_rect.offset_bottom = 0.0
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	_overlay.add_child(_rect)
	add_child(_overlay)

func transition_to(scene_path: String) -> void:
	if _busy:
		return
	_busy = true

	# Pause the game to stop gameplay input/processing while allowing this node to process
	get_tree().paused = true

	await _fade_to(1.0)

	# Change scene while screen is black
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneTransition: failed to change to scene %s (err=%d)" % [scene_path, err])

	# Wait a frame for new scene to initialize
	await get_tree().process_frame

	await _fade_to(0.0)

	get_tree().paused = false
	_busy = false

func transition_to_room(target_room_name: String, player: CharacterBody2D = null, player_offset: Vector2 = Vector2.ZERO, target_spawn_node_name: String = "") -> void:
	if _busy:
		return
	_busy = true

	get_tree().paused = true

	await _fade_to(1.0)

	var current_scene := get_tree().current_scene
	if current_scene == null:
		push_error("SceneTransition: no current scene for room transition.")
		await _fade_back_in_after_error()
		return

	var camera_points := current_scene.get_node_or_null("camera_points")
	if camera_points == null:
		push_error("SceneTransition: camera_points node not found for room transition.")
		await _fade_back_in_after_error()
		return

	var target_room := camera_points.get_node_or_null(target_room_name) as Node2D
	if target_room == null:
		push_error("SceneTransition: target room '%s' not found." % target_room_name)
		await _fade_back_in_after_error()
		return

	var active_player := player
	if active_player == null:
		active_player = current_scene.get_node_or_null("CharacterBody2D") as CharacterBody2D

	var spawn_position := target_room.global_position
	if target_spawn_node_name != "":
		var spawn_node := current_scene.get_node_or_null(target_spawn_node_name) as Node2D
		if spawn_node != null:
			spawn_position = spawn_node.global_position
		else:
			push_warning("SceneTransition: spawn node '%s' not found, falling back to room '%s'." % [target_spawn_node_name, target_room_name])

	if active_player != null and is_instance_valid(active_player):
		active_player.global_position = spawn_position + player_offset
		active_player.velocity = Vector2.ZERO

	var room_camera := current_scene.get_node_or_null("RoomCamera") as Camera2D
	if room_camera != null:
		room_camera.global_position = target_room.global_position

	await get_tree().process_frame

	await _fade_to(0.0)

	get_tree().paused = false
	_busy = false

func _fade_back_in_after_error() -> void:
	await _fade_to(0.0)
	get_tree().paused = false
	_busy = false

func _fade_to(alpha: float) -> void:
	if _rect == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_rect, "color:a", clampf(alpha, 0.0, 1.0), fade_duration)
	await tween.finished
