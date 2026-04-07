extends Node2D

signal player_landed
signal player_left

var _player_on_platform: bool = false
var _player_body: CharacterBody2D = null
var _prev_position: Vector2 = Vector2.ZERO
var _platform_velocity: Vector2 = Vector2.ZERO
var _platform_body: StaticBody2D = null

## Friction coefficient when platform moves down (0-1, higher = more friction)
@export var descent_friction: float = 0.85

func _ready() -> void:
	_prev_position = global_position
	process_physics_priority = -10
	_platform_body = get_node_or_null("PlatformBody") as StaticBody2D
	if _platform_body == null:
		_platform_body = get_node_or_null("StaticBody2D") as StaticBody2D
	var area := $Area2D as Area2D
	if area:
		area.body_entered.connect(_on_area_body_entered)
		area.body_exited.connect(_on_area_body_exited)

func _physics_process(delta: float) -> void:
	# Calculate platform velocity
	_platform_velocity = (global_position - _prev_position) / delta if delta > 0 else Vector2.ZERO
	_prev_position = global_position

	# Let CharacterBody2D inherit platform motion through move_and_slide.
	if _platform_body != null:
		_platform_body.constant_linear_velocity = _platform_velocity

func _on_area_body_entered(body: Node2D) -> void:
	# Check multiple conditions to detect the player
	if body.name == "Player" or body.is_in_group("player") or (body.script and body.script.resource_path.contains("Player")):
		print("Player detected on platform: ", body.name)
		_player_on_platform = true
		_player_body = body as CharacterBody2D
		player_landed.emit()

func _on_area_body_exited(body: Node2D) -> void:
	# Check if it's the player leaving
	if body.name == "Player" or body.is_in_group("player") or (body.script and body.script.resource_path.contains("Player")):
		print("Player left platform: ", body.name)
		_player_on_platform = false
		if body == _player_body:
			_player_body = null
		player_left.emit()

func is_player_on_platform() -> bool:
	return _player_on_platform and _player_body != null and is_instance_valid(_player_body)

func get_player_on_platform() -> CharacterBody2D:
	if _player_body != null and is_instance_valid(_player_body):
		return _player_body
	return null
