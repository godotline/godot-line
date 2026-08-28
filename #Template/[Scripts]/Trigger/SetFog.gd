extends Node
## SetFog - 雾设置组件
## 由父节点 BaseTrigger 触发，用 Tween 过渡场景环境雾设置

@export var fog: FogSettings
@export var duration: float = 2.0
@export var ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var transType: Tween.TransitionType = Tween.TRANS_LINEAR

signal on_animation_start
signal on_animation_end

## 由父节点 BaseTrigger 调用的入口方法
func trigger(body: Node3D) -> bool:
	if not body is CharacterBody3D:
		return false
	apply_fog()
	return true

func apply_fog() -> void:
	if not fog:
		return

	var env: Environment = null
	if Player.instance:
		env = Player.instance.get_scene_environment()
	if not env:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			env = camera.get_environment()
	if not env:
		env = get_tree().root.get_world_3d().environment
	if not env:
		return

	# duplicate 避免修改原始共享资源
	if not env.resource_local_to_scene:
		env = env.duplicate()
		env.resource_local_to_scene = true
		var camera: Camera3D = Player.instance.get_scene_camera() if Player.instance else get_viewport().get_camera_3d()
		if camera:
			camera.environment = env

	on_animation_start.emit()

	# 设置雾是否启用
	env.fog_enabled = fog.useFog

	# Unity FogSettings.SetFog 无论 useFog 都同时补间雾颜色/距离/相机背景色
	var tween: Tween = create_tween()
	tween.set_ease(ease)
	tween.set_trans(transType)
	tween.tween_property(env, "fog_light_color", fog.fogColor, duration)
	tween.parallel().tween_property(env, "fog_depth_begin", fog.start, duration)
	tween.parallel().tween_property(env, "fog_depth_end", fog.end, duration)
	tween.parallel().tween_property(env, "background_color", fog.fogColor, duration)
	tween.tween_callback(func() -> void: on_animation_end.emit())
