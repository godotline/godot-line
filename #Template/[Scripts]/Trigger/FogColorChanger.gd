@tool
extends BaseTrigger
## @deprecated: 推荐使用 FogChangeBehavior 作为 BaseTrigger 的子节点
## FogColorChanger - 雾效颜色变化（向后兼容包装）

@export var target_fog_color = Color(1, 1, 1)
@export var duration = 1.0
@export var TransitionType = 1

signal on_animation_start
signal on_animation_end

func _on_triggered(_body: Node3D) -> void:
	play_()

func play_() -> void:
	var env := get_viewport().get_world_3d().environment
	if not env:
		return

	on_animation_start.emit()
	var tween = create_tween()
	tween.tween_property(env, "fog_light_color", target_fog_color, duration).set_trans(TransitionType)
	tween.tween_callback(func(): on_animation_end.emit())
