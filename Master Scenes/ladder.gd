extends Area2D


#var laddermode: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_body_entered(body: Node2D) -> void:
	if (body is CharacterBody2D):
		Global.laddermode = true
		print("ladder mode true")





func _on_body_exited(body: Node2D) -> void:
	if (body is CharacterBody2D):
		Global.laddermode = false
		print("ladder mode false")
