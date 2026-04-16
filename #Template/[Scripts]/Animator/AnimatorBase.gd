# animator_base.gd
@tool
extends Node3D
class_name AnimatorBase

enum TransformType { New, Add }

@export var transform_type: TransformType = TransformType.New
@export var start_value = Vector3(0,0,0)
@export var end_offset = Vector3(0,0,0)
@export var duration = 1.0
@export var TransitionType: Tween.TransitionType = Tween.TRANS_SINE
@export var EaseType: Tween.EaseType = Tween.EASE_IN_OUT
@export var trigger: Area3D

var _is_playing = false
var _initialized = false

signal on_animation_start
signal on_animation_end

@export_tool_button("Get Original Value")
var get_start_action = func():
	if transform_type == TransformType.Add:
		start_value = _get_value()

@export_tool_button("Set Original Value")
var set_start_action = func():
	_set_value(start_value)

@export_tool_button("Get New Value")
var get_end_action = func():
	match transform_type:
		TransformType.New:
			end_offset = _get_value()
		TransformType.Add:
			end_offset = _get_value() - start_value

@export_tool_button("Set New Value")
var set_end_action = func():
	match transform_type:
		TransformType.New:
			_set_value(end_offset)
		TransformType.Add:
			_set_value(start_value + end_offset)

@export_tool_button("Play")
var play_action = play_

func _init() -> void:
	# 脚本实例化时（添加脚本到节点时）记录当前值
	if Engine.is_editor_hint():
		if transform_type == TransformType.Add:
			start_value = _get_value()

func _ready() -> void:
	_initialized = true

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and not _is_playing and _initialized:
		pass

func play_():
	if _is_playing:
		print("动画正在播放中")
		return
	_is_playing = true
	on_animation_start.emit()
	_set_value(start_value)
	var tween = create_tween()
	var target_value = end_offset
	if transform_type == TransformType.Add:
		target_value = start_value + end_offset
	tween.tween_property(self, _get_property_name(), target_value, duration).set_trans(TransitionType).set_ease(EaseType)
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
