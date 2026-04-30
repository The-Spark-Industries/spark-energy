extends CanvasLayer

## Tutorial overlay that displays control instructions.
## Automatically dismisses on any input and tracks viewed state in Global.

signal dismissed

var _tutorial_type: String = ""  # "pipe_terminal" or "wire_terminal"
var _instruction_text: String = ""
var _can_dismiss: bool = false

@onready var _backdrop = $Backdrop
@onready var _panel = $PanelContainer
@onready var _instruction_label = $PanelContainer/VBoxContainer/InstructionLabel
@onready var _dismiss_label = $PanelContainer/VBoxContainer/DismissLabel

func _ready() -> void:
	_can_dismiss = false
	# Defer to next frame to allow animation/visibility setup
	await get_tree().process_frame
	_can_dismiss = true
	
func _process(delta: float) -> void:
	if (Global.fontChoice==0):
		$PanelContainer.theme=load("res://Assets/Visual/Lingua.tres")
	if (Global.fontChoice==1):
		$PanelContainer.theme=load("res://Assets/Visual/lingualight.tres")
	if (Global.fontChoice==2):
		$PanelContainer.theme=load("res://Assets/Visual/Receipt.tres")

func _input(event: InputEvent) -> void:
	if not _can_dismiss:
		return
	
	# Dismiss on any key press or action that would typically be used in a puzzle
	if event is InputEventKey and event.pressed:
		_dismiss()
		get_tree().root.set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_dismiss()
		get_tree().root.set_input_as_handled()

func set_tutorial(tutorial_type: String, instruction_text: String) -> void:
	_tutorial_type = tutorial_type
	_instruction_text = instruction_text
	if _instruction_label:
		_instruction_label.text = instruction_text

func _dismiss() -> void:
	if _tutorial_type != "" and _tutorial_type in Global.tutorials:
		Global.tutorials[_tutorial_type] = true
	
	dismissed.emit()
	queue_free()
	
