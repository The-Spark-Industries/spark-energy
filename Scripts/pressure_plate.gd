extends Area2D


var readyToPress: bool= false

@onready var pressurePlateStatus: int = 0


@onready var platformMode: bool= false

@export_group("Solved Platform Motion")
@export var moving_platform_path: NodePath
@export var platform_move_distance: float = 100.0
@export var platform_move_duration: float = 2.3


@onready var change= $pressurePlateSprites
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass



# # Changes the sprite to whatever the valve status is.
func _process(delta: float) -> void:
	change.frame=pressurePlateStatus
	
		




func _on_body_entered(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= true
		pressurePlateStatus=1
		var platform := get_node_or_null(moving_platform_path) as Node2D
		if platform == null:
			return
			
		var start_y := platform.position.y
		var tween := create_tween()
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(platform, "position:y", start_y + platform_move_distance, platform_move_duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(platform, "position:y", start_y - platform_move_distance, platform_move_duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

func _on_body_exited(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= false
		pressurePlateStatus=0
	
		
