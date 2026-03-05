extends Control

@onready var maptexture= preload("res://1_Main Character Assets/Spark Assets/Spark Sprites/spark2.png")
@onready var shoestexture= preload("res://icon.svg")
var inventorycounter: int= 0


#var icons_dictionary: Dictionary = {
	#0 : maptexture,
	#1: shoestexture
	#}
	#
@onready var icons_array: Array= [maptexture, shoestexture]


func _ready() -> void:
	print(Global.inventory)
	#Global.inventory= []
	if (Global.inventory.size() ==0):
		%Icon.visible = false


#Checks if there's anything in the inventory, to add it. Meant for the start of the game.
func _process(delta: float) -> void:



	if Input.is_action_just_released("inventoryright"):
		inventorycounter+=1
		if (inventorycounter>=Global.inventory.size()):
			inventorycounter=0
		print(inventorycounter)
	if Input.is_action_just_released("inventoryleft"):
		inventorycounter-=1
		if (inventorycounter<0):
			inventorycounter=Global.inventory.size()-1
		print(inventorycounter)

	if (Global.inventory.size() ==0):
		%Icon.visible = false
		
	else :
		%Icon.visible = true
		%Icon.texture = icons_array[inventorycounter]
		#%Icon.texture =load("res://1_Main Character Assets/Spark Assets/Spark Sprites/spark2.png")
