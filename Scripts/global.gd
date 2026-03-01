extends Node

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
				
