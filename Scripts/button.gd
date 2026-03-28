extends Area2D


var readyToPress: bool= false
#Checks if the player is near the button
@onready var buttonstatus: int = 0
#Determines the on/off state 

@onready var buttonchange= $buttonSprites
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# # Changes the sprite to whatever the button status is.
func _process(delta: float) -> void:
	buttonchange.frame=buttonstatus
	
		


func _input(event: InputEvent) -> void:
	if (Input.is_action_just_pressed("interact")) and (readyToPress==true):
		buttonstatus=1
		await get_tree().create_timer(0.5).timeout
		buttonstatus=0


func _on_body_entered(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= true

func _on_body_exited(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= false
