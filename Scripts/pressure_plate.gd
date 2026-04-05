extends Area2D


var readyToPress: bool= false

@onready var pressurePlateStatus: int = 0
#Determines the valve state

@onready var change= $pressurePlateSprites
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# # Changes the sprite to whatever the valve status is.
func _process(delta: float) -> void:
	change.frame=pressurePlateStatus
	
		





func _on_body_entered(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= true
		pressurePlateStatus=1

func _on_body_exited(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= false
		pressurePlateStatus=0
