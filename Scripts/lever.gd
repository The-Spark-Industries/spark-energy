extends Area2D

var readyToPress: bool= false
#Checks if the player is near the lever
@onready var leverstatus: int = 0
#Determines the on/off state 

@onready var change= $leverSprites
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# # Changes the sprite to whatever the lever status is.
func _process(delta: float) -> void:
	change.frame=leverstatus
	
		


func _input(event: InputEvent) -> void:
	if (Input.is_action_just_pressed("interact")) and (readyToPress==true):
		if (leverstatus==0):
			leverstatus=1
		elif (leverstatus==1):
			leverstatus=0
		


func _on_body_entered(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= true

func _on_body_exited(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= false
