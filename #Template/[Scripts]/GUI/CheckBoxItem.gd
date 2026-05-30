@tool
extends HBoxContainer
class_name CheckBoxItem

signal toggled(is_on: bool)

var checkbox: CheckBox
var label: Label

func _init(p_title: String = ""):
	_init_ui(p_title)

func _init_ui(p_title: String) -> void:
	checkbox = CheckBox.new()
	checkbox.flat = true
	add_child(checkbox)
	checkbox.toggled.connect(toggled.emit)

	label = Label.new()
	label.text = p_title
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)

func set_title(p_text: String) -> void:
	label.text = text

func set_is_on(value: bool) -> void:
	checkbox.button_pressed = value

func get_is_on() -> bool:
	return checkbox.button_pressed
