@tool
extends Node3D

@export var start_pos = Vector3(0,0,0)
@export var end_pos = Vector3(0,0,0)
@export var duration = 1.0
@export var TransitionType = 1
@export var trigger: Area3D
@export_tool_button("Start Pos","PlayStart")
var start_action = func():
	start_pos = self.position
@export_tool_button("Get Start Pos","PlayStart")
var get_start_action = func():
	self.position = start_pos
@export_tool_button("End Pos","TransitionEnd")
var end_action = func():
	end_pos = self.position
@export_tool_button("Get End Pos","TransitionEnd")
var get_end_action = func():
	self.position = end_pos
@export_tool_button("Play","Play")
var play_action = play_

signal on_animation_start
signal on_animation_end

func _ready() -> void :
	self.position = start_pos
	if trigger.has_signal("hit_the_line"):
		trigger.connect("hit_the_line", Callable(self, "play_"))

func play_():
	on_animation_start.emit()
	self.position = start_pos
	var tween = create_tween()
	tween.tween_property(self,"position",end_pos,duration).set_trans(TransitionType)
	tween.tween_callback(func(): on_animation_end.emit())

func _init() -> void:
	start_pos = self.position

func _on_on_animation_end() -> void:
	pass # Replace with function body.
