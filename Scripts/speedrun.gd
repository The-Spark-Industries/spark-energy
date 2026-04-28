extends CanvasLayer
 
var time = Global.speedrun_time
var minutecounter= 0
 
func _physics_process(delta):
	time = float(time) + delta
	update_ui()
	if (Global.speedrunshow==true):
		self.show()
	if (Global.speedrunshow==false):
		self.hide()
	
	
func update_ui():
	var formatted_time
	

	
	if (minutecounter==0):
		formatted_time = str(time)
		if (time<10):
			formatted_time = "0"+str(time)
	elif (minutecounter>=1):
		formatted_time= str(minutecounter)+ ":"+str(time)
		if (time<10):
			formatted_time = str(minutecounter)+ ":"+"0"+str(time)
	var decimal_index = formatted_time.find(".")
	
	if decimal_index > 0:
		formatted_time = formatted_time.left(decimal_index + 3)  # Take only two decimal places
	if (time>59.99):
		time=00.00
		minutecounter+=1
	Global.speedrun_time = formatted_time
		
	$Label.text = formatted_time

func _process(delta: float) -> void:
	if (Global.fontChoice==0):
		$Label.theme=load("res://Assets/Visual/Lingua.tres")
	if (Global.fontChoice==1):
		$Label.theme=load("res://Assets/Visual/lingualight.tres")
	if (Global.fontChoice==2):
		$Label.theme=load("res://Assets/Visual/Receipt.tres")
