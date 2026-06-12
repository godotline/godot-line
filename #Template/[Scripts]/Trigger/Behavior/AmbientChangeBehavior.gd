@tool
extends TriggerBehavior
class_name AmbientChangeBehavior

## AmbientChangeBehavior - 环境光变化行为组件
## 当父 BaseTrigger 被触发时改变环境光参数

enum LightingType {
	Skybox,   ## 天空盒
	Color,    ## 单色
	Gradient  ## 渐变
}

@export_group("环境光设置")
@export var lighting_type: LightingType = LightingType.Skybox
## 单色模式下的环境颜色
@export var ambient_color: Color = Color.WHITE
## 环境光强度
@export var intensity: float = 1.0

@export_group("渐变模式颜色")
@export var sky_color: Color = Color.WHITE
@export var equator_color: Color = Color.WHITE
@export var ground_color: Color = Color.WHITE

@export_group("补间动画")
@export var duration: float = 1.0
@export var transition_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

var _saved: bool = false
var _original_source: int
var _original_intensity: float
var _original_color: Color
var _original_sky_color: Color
var _original_equator_color: Color
var _original_ground_color: Color

func _on_triggered(_body: Node3D) -> void:
	var env := get_viewport().get_world_3d().environment
	if not env:
		return

	# 保存原始值
	if not _saved:
		_original_source = env.ambient_light_source
		_original_intensity = env.ambient_light_energy
		_original_color = env.ambient_light_color
		_original_sky_color = env.ambient_light_sky_color
		_original_equator_color = env.ambient_light_horizon_color
		_original_ground_color = env.ambient_light_ground_color
		_saved = true

	# 应用新环境光
	match lighting_type:
		LightingType.Skybox:
			if duration > 0.0:
				var tween := create_tween()
				tween.set_ease(ease_type)
				tween.set_trans(transition_type)
				tween.tween_property(env, "ambient_light_energy", intensity, duration)
			else:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
				env.ambient_light_energy = intensity
		LightingType.Color:
			if duration > 0.0:
				var tween := create_tween()
				tween.set_ease(ease_type)
				tween.set_trans(transition_type)
				tween.tween_property(env, "ambient_light_color", ambient_color, duration)
				tween.parallel().tween_property(env, "ambient_light_energy", intensity, duration)
			else:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_color = ambient_color
				env.ambient_light_energy = intensity
		LightingType.Gradient:
			if duration > 0.0:
				var tween := create_tween()
				tween.set_ease(ease_type)
				tween.set_trans(transition_type)
				tween.tween_property(env, "ambient_light_sky_color", sky_color, duration)
				tween.parallel().tween_property(env, "ambient_light_horizon_color", equator_color, duration)
				tween.parallel().tween_property(env, "ambient_light_ground_color", ground_color, duration)
				tween.parallel().tween_property(env, "ambient_light_energy", intensity, duration)
			else:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_sky_color = sky_color
				env.ambient_light_horizon_color = equator_color
				env.ambient_light_ground_color = ground_color
				env.ambient_light_energy = intensity

	_register_revive()

func _on_revive() -> void:
	if not _saved:
		return
	var env := get_viewport().get_world_3d().environment
	if not env:
		return
	env.ambient_light_source = _original_source
	env.ambient_light_energy = _original_intensity
	env.ambient_light_color = _original_color
	env.ambient_light_sky_color = _original_sky_color
	env.ambient_light_horizon_color = _original_equator_color
	env.ambient_light_ground_color = _original_ground_color
