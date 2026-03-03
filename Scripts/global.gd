extends Node

## Last checkpoint position the player touched. Used for respawn on death.
var last_checkpoint_position: Vector2 = Vector2.ZERO

func set_checkpoint(pos: Vector2) -> void:
	last_checkpoint_position = pos
var inventory: Array = []
var max_inventory_size= [100]
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func add_item_to_inventory(item:int):
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
				
