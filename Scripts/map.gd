extends Area2D



func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.get_meta("tag", "") != "player":

		return

	

	Global.add_item_to_inventory("Map")
	queue_free()
