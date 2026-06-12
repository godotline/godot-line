@tool
extends TriggerBehavior
class_name LightChangeBehavior

## LightChangeBehavior - 定向光变化行为组件
## 当父 BaseTrigger 被触发时改变场景定向光（DirectionalLight3D）参数

@export_group("光照设置")
## 目标旋转角度
@export var light_rotation: Vector3 = Vector3.ZERO
## 目标颜色
@export var light_color: Color = Color.WHITE
## 目标强度
@export var light_intensity: float = 1.0

@export_group("补间动画")
## 过渡持续时间
@export var duration: float = 1.0
## 过渡类型
@export var transition_type: Tween.TransitionType = Tween.TRANS_LINEAR
## 缓动类型
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

var _original_rotation: Vector3
var _original_color: Color
var _original_intensity: float
var _saved: bool = false

func _on_triggered(_body: Node3D) -> void:
	var main_line := Player.instance
	if not main_line:
		return

	var scene_light := main_line.get_tree().get_first_node_in_group("scene_light") as DirectionalLight3D
	if not scene_light:
		return

	# 保存原始值
	if not _saved:
		_original_rotation = scene_light.rotation_degrees
		_original_color = scene_light.light_color
		_original_intensity = scene_light.light_energy
		_saved = true

	# 应用新光照参数
	if duration > 0.0:
		var tween := create_tween()
		tween.set_ease(ease_type)
		tween.set_trans(transition_type)
		tween.tween_property(scene_light, "rotation_degrees", light_rotation, duration)
		tween.parallel().tween_property(scene_light, "light_color", light_color, duration)
		tween.parallel().tween_property(scene_light, "light_energy", light_intensity, duration)
	else:
		scene_light.rotation_degrees = light_rotation
		scene_light.light_color = light_color
		scene_light.light_energy = light_intensity

	_register_revive()

func _on_revive() -> void:
	if not _saved:
		return
	var main_line := Player.instance
	if main_line:
		var scene_light := main_line.get_tree().get_first_node_in_group("scene_light") as DirectionalLight3D
		if scene_light:
			scene_light.rotation_degrees = _original_rotation
			scene_light.light_color = _original_color
			scene_light.light_energy = _original_intensity
