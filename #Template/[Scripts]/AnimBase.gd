# animator_base.gd
@tool
extends Node3D
class_name AnimatorBase

@export var start_value = Vector3(0,0,0)
@export var end_offset = Vector3(0,0,0)
@export var duration = 1.0
@export var TransitionType: Tween.TransitionType = Tween.TRANS_SINE
@export var EaseType: Tween.EaseType = Tween.EASE_IN_OUT
@export var trigger: Area3D
@export var is_setting_start = false
@export var is_setting_end = false

var _is_playing = false
var _initialized = false

signal on_animation_start
signal on_animation_end

@export_tool_button("Set Start","PlayStart")
var get_start_action = func():
	is_setting_start = true
	is_setting_end = false
	_set_value(start_value)

@export_tool_button("Set End Offset","TransitionEnd")
var get_end_action = func():
	is_setting_start = false
	is_setting_end = true
	_set_value(end_offset + start_value)

@export_tool_button("Play","Play")
var play_action = play_

func _ready() -> void:
	_initialized = true
	
	# 编辑器模式：自动记录当前值作为起始值
	if Engine.is_editor_hint() and is_setting_start:
		start_value = _get_value()
	else:
		# 运行时：应用起始值
		_set_value(start_value)
		if trigger and trigger.has_signal("hit_the_line"):
			trigger.connect("hit_the_line", Callable(self, "play_"))

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not _is_playing and _initialized:
		if is_setting_start:
			start_value = _get_value()
		if is_setting_end:
			end_offset = _get_value() - start_value

func play_():
	if _is_playing:
		print("动画正在播放中")
		return
	_is_playing = true
	is_setting_start = false
	is_setting_end = false
	on_animation_start.emit()
	_set_value(start_value)
	var tween = create_tween()
	tween.tween_property(self, _get_property_name(), end_offset + start_value, duration).set_trans(TransitionType).set_ease(EaseType)
	tween.tween_callback(func():
		on_animation_end.emit()
		_is_playing = false
		if Engine.is_editor_hint():
			_set_value(start_value)
	)

# 虚方法
func _get_value() -> Vector3:
	return Vector3.ZERO

func _set_value(_value: Vector3) -> void:
	pass

func _get_property_name() -> String:
	return ""
