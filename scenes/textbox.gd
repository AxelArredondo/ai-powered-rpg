extends CanvasLayer

@onready var textbox_container = $TextboxContainer
@onready var start_label = $TextboxContainer/MarginContainer/HBoxContainer/Start
@onready var main_label = $TextboxContainer/MarginContainer/HBoxContainer/Label
@onready var end_label = $TextboxContainer/MarginContainer/HBoxContainer/End

var dialogue_visible := false
var player_near := false

func _ready():
	textbox_container.hide()
	add_to_group("dialogue_ui")

func _process(_delta):
	if player_near and Input.is_action_just_pressed("ui_accept"):
		toggle_dialogue()

func toggle_dialogue():
	dialogue_visible = !dialogue_visible
	
	if dialogue_visible:
		show_dialogue("*", "Hello Adventurer, My name is Blob. Nice to meet you!", ">")
	else:
		textbox_container.hide()

func show_dialogue(start_text: String, main_text: String, end_text: String):
	start_label.text = start_text
	main_label.text = main_text
	end_label.text = end_text
	
	textbox_container.show()

func set_player_near(value: bool):
	player_near = value
