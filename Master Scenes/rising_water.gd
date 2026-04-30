extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	print (Global.maze_decider,Global.maze_resetter)
	if (Global.maze_resetter==1):
		self.scale.y=1.0
		self.position.x=-320
		self.position.y=154
