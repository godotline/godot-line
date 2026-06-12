@tool
extends TriggerBehavior
class_name FogChangeBehavior

## FogChangeBehavior - 雾效变化行为组件
## 当父 BaseTrigger 被触发时改变雾效参数

@export var target_fog_color: Color = Color(1, 1, 1)
@export var duration: float = 1.0
@export var transition_type: Tween.TransitionType = Tween.TRANS_LINEAR

## 是否启用雾
@export var enable_fog: bool = true
## 雾起始距离
@export var fog_start: float = 10.0
## 雾结束距离
@export var fog_end: float = 100.0

var _original_fog_color: Color
var _original_fog_enabled: bool
var _original_fog_start: float
var _original_fog_end: float

func _on_triggered(_body: Node3D) -> void:
	var env := get_viewport().get_world_3d().environment
	if not env:
		return
	
	# 保存原始值
	_original_fog_color = env.fog_light_color
	_original_fog_enabled = env.fog_enabled
	_original_fog_start = env.fog_depth_begin
	_original_fog_end = env.fog_depth_end
	
	# 应用新雾效
	env.fog_enabled = enable_fog
	
	var tween := create_tween()
	tween.set_trans(transition_type)
	tween.tween_property(env, "fog_light_color", target_fog_color, duration)
	tween.parallel().tween_property(env, "fog_depth_begin", fog_start, duration)
	tween.parallel().tween_property(env, "fog_depth_end", fog_end, duration)
	
	_register_revive()

func _on_revive() -> void:
	var env := get_viewport().get_world_3d().environment
	if not env:
		return
	env.fog_enabled = _original_fog_enabled
	env.fog_light_color = _original_fog_color
	env.fog_depth_begin = _original_fog_start
	env.fog_depth_end = _original_fog_end
