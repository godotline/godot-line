@tool
extends Node3D
## FogColorChanger - 雾色变化组件
## 由父节点 BaseTrigger 触发，用 Tween 过渡场景环境雾色

@export var target_fog_color = Color(1,1,1)
@export var duration = 1.0
@export var TransitionType = 1

signal on_animation_start
signal on_animation_end

## 由父节点 BaseTrigger 调用的入口方法
func trigger(body: Node3D) -> void:
	if body is CharacterBody3D:
		play_()

func play_():
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var env := camera.get_environment()
	if not env:
		return

	# duplicate 避免修改原始共享资源
	if not env.resource_local_to_scene:
		env = env.duplicate()
		env.resource_local_to_scene = true
		camera.environment = env

	on_animation_start.emit()
	var tween = create_tween()
	tween.tween_property(env, "fog_light_color", target_fog_color, duration).set_trans(TransitionType)
	tween.tween_callback(func(): on_animation_end.emit())
