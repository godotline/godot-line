extends Node
## SetFog - 雾设置组件
## 由父节点 BaseTrigger 触发，用 Tween 过渡场景环境雾设置

@export var fog_settings: FogSettings
@export var duration: float = 2.0
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_LINEAR

signal on_animation_start
signal on_animation_end

## 由父节点 BaseTrigger 调用的入口方法
func trigger(body: Node3D) -> void:
	if body is CharacterBody3D:
		apply_fog()

func apply_fog() -> void:
	if not fog_settings:
		return
	
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return
	var env: Environment = camera.get_environment()
	if not env:
		return

	# duplicate 避免修改原始共享资源
	if not env.resource_local_to_scene:
		env = env.duplicate()
		env.resource_local_to_scene = true
		camera.environment = env

	on_animation_start.emit()
	
	# 设置雾是否启用
	env.fog_enabled = fog_settings.use_fog
	
	if fog_settings.use_fog:
		var tween: Tween = create_tween()
		tween.set_ease(ease_type)
		tween.set_trans(trans_type)
		tween.tween_property(env, "fog_light_color", fog_settings.fog_color, duration)
		tween.parallel().tween_property(env, "fog_light_energy", 1.0, duration)
		tween.parallel().tween_property(env, "fog_aerial_perspective", 0.0, duration)
		# Godot 4.x 的雾密度参数
		tween.tween_callback(func(): on_animation_end.emit())
	else:
		on_animation_end.emit()
