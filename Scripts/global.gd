extends Node

const SAVE_FILE_PATH := "user://savegame.json"

## Last checkpoint position the player touched.
var last_checkpoint_position: Vector2 = Vector2.ZERO
## Scene path where the last checkpoint was touched.
var last_checkpoint_scene_path: String = ""
## True when there is a checkpoint loaded or set
var has_saved_checkpoint: bool = false

var inventory: Array = []
var max_inventory_size= 100

func _ready() -> void:
	load_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func set_checkpoint(pos: Vector2, scene_path: String = "") -> void:
	last_checkpoint_position = pos
	if scene_path != "":
		last_checkpoint_scene_path = scene_path
	has_saved_checkpoint = true
	save_game()

func has_checkpoint_for_scene(scene_path: String) -> bool:
	if not has_saved_checkpoint:
		return false
	return last_checkpoint_scene_path == scene_path

func save_game() -> void:
	var save_data := {
		"checkpoint": {
			"x": last_checkpoint_position.x,
			"y": last_checkpoint_position.y,
			"scene_path": last_checkpoint_scene_path,
			"has_saved_checkpoint": has_saved_checkpoint
		},
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

	if checkpoint_data.get("has_saved_checkpoint", false):
		var x: float = float(checkpoint_data.get("x", 0.0))
		var y: float = float(checkpoint_data.get("y", 0.0))
		last_checkpoint_position = Vector2(x, y)
		last_checkpoint_scene_path = String(checkpoint_data.get("scene_path", ""))
		has_saved_checkpoint = true

	var loaded_inventory: Variant = save_data.get("inventory", inventory)
	if typeof(loaded_inventory) == TYPE_ARRAY:
		inventory = loaded_inventory


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func add_item_to_inventory(item:String):
	print(inventory)
	for i in range(min(inventory.size(),max_inventory_size)):
		if (inventory[i]==null):
			inventory[i]=item
			
			return
	if (inventory.size() < max_inventory_size):
		inventory.append(item)
		print(inventory)
	else:
		print("Your inventory is full!")
				
