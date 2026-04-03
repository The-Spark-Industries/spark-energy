extends Area2D


var readyToPress: bool= false
#Checks if the player is near the valve
@onready var valvestatus: int = 0
#Determines the valve state

@onready var change= $valveSprites
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# # Changes the sprite to whatever the valve status is.
func _process(delta: float) -> void:
	change.frame=valvestatus
	
		


func _input(event: InputEvent) -> void:
	if (Input.is_action_just_pressed("interact")) and (readyToPress==true) and (valvestatus<4):
		valvestatus+=1
		print(valvestatus)


func _on_body_entered(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= true

func _on_body_exited(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= false
