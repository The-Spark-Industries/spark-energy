extends Control

func _ready() -> void:
	print(Global.inventory)
	#Global.inventory= []
	if (Global.inventory.size() ==0):
		%Icon.visible = false


#Checks if there's anything in the inventory, to add it. Meant for the start of the game.
func _process(delta: float) -> void:

	if (Global.inventory.size() ==0):
		%Icon.visible = false

		
	else:

		%Icon.visible = true
