extends Node2D

signal player_landed
signal player_left

var _player_on_platform: bool = false
var _player_body: CharacterBody2D = null

func _ready() -> void:
	var area := $Area2D as Area2D
	if area:
		area.body_entered.connect(_on_area_body_entered)
		area.body_exited.connect(_on_area_body_exited)

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
