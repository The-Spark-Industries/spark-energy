extends Node

const SAVE_FILE_PATH := "user://savegame.json"
## Set to false to ignore checkpoint saves/loads and spawn from scene start.
var checkpoints_enabled: bool = false

## Last checkpoint position the player touched.
var last_checkpoint_position: Vector2 = Vector2.ZERO
## Scene path where the last checkpoint was touched.
var last_checkpoint_scene_path: String = ""
## Room identifier where the last checkpoint was touched.
var last_checkpoint_room_id: String = ""
## True when there is a checkpoint loaded or set
var has_saved_checkpoint: bool = false

## Scene -> first checkpoint dictionary.
## Value format: {"x": float, "y": float, "room_id": String}
var first_checkpoint_by_scene: Dictionary = {}

## Scene -> room -> checkpoint dictionary.
## Value format: {"x": float, "y": float}
var room_checkpoints_by_scene: Dictionary = {}
var laddermode: bool = false

var inventory: Array = []
var max_inventory_size= 100

var wiremode: bool = false
var minigame_active: bool = false

var fontChoice: int

var turboMode: bool = false

var tutorialchecker: int = 0

var jumpcounter : int =0

var speedrun_time =0

var maze_decider: int= 0

var maze_resetter: int= 0

var speedrunshow: bool = true

var timerstopper: bool = false

## Tutorial seen flags: tracks which tutorials have been viewed
## Format: {"pipe_terminal": bool, "wire_terminal": bool}
var tutorials: Dictionary = {
	"pipe_terminal": false,
	"wire_terminal": false
}

func _ready() -> void:
	load_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func set_checkpoint(pos: Vector2, scene_path: String = "", room_id: String = "") -> void:
	if not checkpoints_enabled:
		return

	if scene_path == "":
		scene_path = _current_scene_path()

	if room_id == "":
		room_id = _room_id_for_world_position(pos)

	last_checkpoint_position = pos
	if scene_path != "":
		last_checkpoint_scene_path = scene_path
	last_checkpoint_room_id = room_id
	has_saved_checkpoint = true
	_register_first_checkpoint_if_missing(scene_path, pos, room_id)
	_register_room_checkpoint(scene_path, room_id, pos)
	save_game()

func has_checkpoint_for_scene(scene_path: String) -> bool:
	if not checkpoints_enabled:
		return false

	if not has_saved_checkpoint:
		return false
	return last_checkpoint_scene_path == scene_path

func ensure_scene_defaults(scene_path: String, spawn_pos: Vector2, room_id: String = "") -> void:
	if scene_path == "":
		scene_path = _current_scene_path()

	if room_id == "":
		room_id = _room_id_for_world_position(spawn_pos)

	_register_first_checkpoint_if_missing(scene_path, spawn_pos, room_id)
	_register_room_checkpoint_if_missing(scene_path, room_id, spawn_pos)

	if not checkpoints_enabled:
		last_checkpoint_position = spawn_pos
		last_checkpoint_scene_path = scene_path
		last_checkpoint_room_id = room_id
		has_saved_checkpoint = true
		return

	if not has_saved_checkpoint or not has_checkpoint_for_scene(scene_path):
		last_checkpoint_position = spawn_pos
		last_checkpoint_scene_path = scene_path
		last_checkpoint_room_id = room_id
		has_saved_checkpoint = true

	save_game()

func reset_level_to_first_checkpoint(scene_path: String = "") -> bool:
	if not checkpoints_enabled:
		return false

	if scene_path == "":
		scene_path = _current_scene_path()

	if scene_path == "":
		return false

	var first_data: Dictionary = first_checkpoint_by_scene.get(scene_path, {})
	if first_data.is_empty():
		return false

	last_checkpoint_position = Vector2(
		float(first_data.get("x", 0.0)),
		float(first_data.get("y", 0.0))-100.00
	)
	last_checkpoint_scene_path = scene_path
	last_checkpoint_room_id = String(first_data.get("room_id", ""))
	has_saved_checkpoint = true
	save_game()
	return true

func reset_room_to_checkpoint(scene_path: String = "", room_id: String = "") -> bool:
	if not checkpoints_enabled:
		return false

	if scene_path == "":
		scene_path = _current_scene_path()

	if scene_path == "":
		return false

	if room_id == "":
		room_id = _current_room_id()

	if room_id == "":
		return false

	var room_map: Dictionary = room_checkpoints_by_scene.get(scene_path, {})
	if room_map.is_empty():
		return false

	var room_data: Dictionary = room_map.get(room_id, {})
	if room_data.is_empty():
		return false

	last_checkpoint_position = Vector2(
		float(room_data.get("x", 0.0)),
		float(room_data.get("y", 0.0))
	)
	last_checkpoint_scene_path = scene_path
	last_checkpoint_room_id = room_id
	has_saved_checkpoint = true
	save_game()
	return true

func save_game() -> void:
	var save_data := {
		"checkpoint": {
			"x": last_checkpoint_position.x,
			"y": last_checkpoint_position.y,
			"scene_path": last_checkpoint_scene_path,
			"room_id": last_checkpoint_room_id,
			"has_saved_checkpoint": has_saved_checkpoint
		},
		"first_checkpoints": first_checkpoint_by_scene,
		"room_checkpoints": room_checkpoints_by_scene,
		"inventory": inventory
	}

	var save_file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_warning("Could not open save file for writing: %s" % SAVE_FILE_PATH)
		return

	save_file.store_string(JSON.stringify(save_data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return

	var save_file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if save_file == null:
		push_warning("Could not open save file for reading: %s" % SAVE_FILE_PATH)
		return

	var file_text := save_file.get_as_text()
	var parsed_data: Variant = JSON.parse_string(file_text)
	if typeof(parsed_data) != TYPE_DICTIONARY:
		push_warning("Save file is not valid JSON dictionary.")
		return

	var save_data: Dictionary = parsed_data
	var checkpoint_data: Dictionary = save_data.get("checkpoint", {})

	if checkpoints_enabled and checkpoint_data.get("has_saved_checkpoint", false):
		var x: float = float(checkpoint_data.get("x", 0.0))
		var y: float = float(checkpoint_data.get("y", 0.0))
		last_checkpoint_position = Vector2(x, y)
		last_checkpoint_scene_path = String(checkpoint_data.get("scene_path", ""))
		last_checkpoint_room_id = String(checkpoint_data.get("room_id", ""))
		has_saved_checkpoint = true
	elif not checkpoints_enabled:
		has_saved_checkpoint = false
		last_checkpoint_scene_path = ""
		last_checkpoint_room_id = ""

	var loaded_first_checkpoints: Variant = save_data.get("first_checkpoints", first_checkpoint_by_scene)
	if typeof(loaded_first_checkpoints) == TYPE_DICTIONARY:
		first_checkpoint_by_scene = loaded_first_checkpoints

	var loaded_room_checkpoints: Variant = save_data.get("room_checkpoints", room_checkpoints_by_scene)
	if typeof(loaded_room_checkpoints) == TYPE_DICTIONARY:
		room_checkpoints_by_scene = loaded_room_checkpoints

	var loaded_inventory: Variant = save_data.get("inventory", inventory)
	if typeof(loaded_inventory) == TYPE_ARRAY:
		inventory = loaded_inventory

func _register_first_checkpoint_if_missing(scene_path: String, pos: Vector2, room_id: String = "") -> void:
	if scene_path == "":
		return
	if first_checkpoint_by_scene.has(scene_path):
		return

	first_checkpoint_by_scene[scene_path] = {
		"x": pos.x,
		"y": pos.y,
		"room_id": room_id
	}

func _register_room_checkpoint(scene_path: String, room_id: String, pos: Vector2) -> void:
	if scene_path == "" or room_id == "":
		return

	if not room_checkpoints_by_scene.has(scene_path):
		room_checkpoints_by_scene[scene_path] = {}

	var room_map: Dictionary = room_checkpoints_by_scene.get(scene_path, {})
	room_map[room_id] = {
		"x": pos.x,
		"y": pos.y
	}
	room_checkpoints_by_scene[scene_path] = room_map

func _register_room_checkpoint_if_missing(scene_path: String, room_id: String, pos: Vector2) -> void:
	if scene_path == "" or room_id == "":
		return

	if not room_checkpoints_by_scene.has(scene_path):
		room_checkpoints_by_scene[scene_path] = {}

	var room_map: Dictionary = room_checkpoints_by_scene.get(scene_path, {})
	if room_map.has(room_id):
		return

	room_map[room_id] = {
		"x": pos.x,
		"y": pos.y
	}
	room_checkpoints_by_scene[scene_path] = room_map

func _current_scene_path() -> String:
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene.scene_file_path
	return ""

func _current_room_id() -> String:
	if not get_tree() or get_tree().current_scene == null:
		return ""

	var room_camera := get_tree().current_scene.get_node_or_null("RoomCamera")
	if room_camera and room_camera.has_method("get_current_target"):
		var current_target: Node2D = room_camera.call("get_current_target") as Node2D
		if current_target:
			return current_target.name

	return ""

func _room_id_for_world_position(world_pos: Vector2) -> String:
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


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


#func add_item_to_inventory(item:String):
	#print(inventory)
	#for i in range(min(inventory.size(),max_inventory_size)):
		#if (inventory[i]==null):
		#	inventory[i]=item
			
		#	return
	#if (inventory.size() < max_inventory_size):
	#	inventory.append(item)
	#else:
		#print("Your inventory is full!")
		#		
