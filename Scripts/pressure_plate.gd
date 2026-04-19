extends Area2D


var readyToPress: bool= false

@onready var pressurePlateStatus: int = 0


@onready var platformMode: bool= false

@export_group("pplate Actions")
@export var waterfall_path: NodePath
@export var lift_target_path: NodePath
@export var wheel_target_path: NodePath
@export var lift_pixels: float = 96.0
@export_range(0.1, 50.0, 0.1) var lift_duration: float = 2.4
var _lift_tween: Tween = null
var i: int =0

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
		
		
		if not String(lift_target_path).is_empty() and not is_zero_approx(lift_pixels):
			var lift_target := get_node_or_null(lift_target_path) as Node2D
			if lift_target:
				if _lift_tween and _lift_tween.is_valid():
					_lift_tween.kill()
				_lift_tween = create_tween()
				_lift_tween.tween_property(lift_target, "position:y", lift_target.position.y - lift_pixels, lift_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			while (body is CharacterBody2D) and (lift_target.get_meta("tag", "") != "risingWater") and (i<=lift_duration*5):
		
				lift_target.scale.y+=0.223
				await get_tree().create_timer(0.08).timeout
				i+=1
				print(i)
			
				

				
func _on_body_exited(body: Node2D) -> void:
	if (body is CharacterBody2D):
		readyToPress= false
		pressurePlateStatus=0
		if not String(lift_target_path).is_empty() and not is_zero_approx(lift_pixels):
			self.set_process(false)
