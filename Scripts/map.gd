extends Area2D



func _ready() -> void:
	body_entered.connect(_on_body_entered)
	%notif.hide()


func _on_body_entered(body: Node2D) -> void:
	if body.get_meta("tag", "") != "player":

		return

	
	Global.add_item_to_inventory("Map")
	%notif.show()
	%notif.visible=true
	get_tree().paused= true
	%CollisionShape2D.queue_free()
	%Sprite2D.queue_free()


func _on_ok_pressed() -> void:
	get_tree().paused= false
	%notif.hide()
