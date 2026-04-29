extends Area2D

@export var target_room_name: String = ""
@export var target_spawn_node_name: String = ""
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var one_shot: bool = true

func _ready() -> void:
	# Detect only player layer by default and avoid acting as a collider body itself.
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not (body is CharacterBody2D):
		return

	if target_room_name == "":
		return

	if one_shot:
		set_deferred("monitoring", false)

	if Engine.is_editor_hint():
		print("LevelTransitionTrigger: would move to room: ", target_room_name)
		return

	var transition := get_tree().root.get_node_or_null("SceneTransition")
	if transition == null:
		transition = get_tree().current_scene.get_node_or_null("SceneTransition")

	if transition == null:
		var transition_script := load("res://Scripts/SceneTransition.gd") as Script
		if transition_script != null:
			var transition_node := Node.new()
			transition_node.name = "SceneTransition"
			transition_node.set_script(transition_script)
			get_tree().current_scene.add_child(transition_node)
			transition = transition_node

	if transition == null:
		push_error("LevelTransitionTrigger: SceneTransition not found and could not be created.")
		return

	if transition.has_method("transition_to_room"):
		transition.call("transition_to_room", target_room_name, body as CharacterBody2D, spawn_offset, target_spawn_node_name)
