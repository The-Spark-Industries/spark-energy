extends StaticBody2D


@export var sink_distance: float = 128

var original_position: Vector2
var activated: bool = false
var sink_cycle_running: bool = false

@onready var trigger_area: Area2D = $Area2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	original_position = position
	trigger_area.monitoring = true
	trigger_area.monitorable = true
	if not trigger_area.body_entered.is_connected(_on_area_2d_body_entered):
		trigger_area.body_entered.connect(_on_area_2d_body_entered)


func _physics_process(_delta: float) -> void:
	if activated or sink_cycle_running:
		return

	for body in trigger_area.get_overlapping_bodies():
		if body is CharacterBody2D:
			_start_sink_cycle()
			break


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_start_sink_cycle()


func _start_sink_cycle() -> void:
	if activated or sink_cycle_running:
		return

	sink_cycle_running = true
	activated = true
	await get_tree().create_timer(0.4).timeout
	position = original_position + Vector2(0.0, sink_distance)
	self.hide()
	await get_tree().create_timer(3).timeout
	self.show()
	position = original_position
	activated = false
	sink_cycle_running = false
