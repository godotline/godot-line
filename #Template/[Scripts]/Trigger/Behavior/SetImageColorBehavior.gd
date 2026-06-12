@tool
extends TriggerBehavior
class_name SetImageColorBehavior

## SetImageColorBehavior - UI 图像颜色变化行为组件
## 当父 BaseTrigger 被触发时改变 CanvasItem 的 modulate 颜色

@export_group("目标设置")
## 目标 CanvasItem 节点路径（Control、TextureRect 等）
@export var target: NodePath

@export_group("颜色设置")
@export var target_color: Color = Color.WHITE

@export_group("补间动画")
@export var duration: float = 1.0
@export var transition_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

var _original_modulate: Color
var _saved: bool = false

func _on_triggered(_body: Node3D) -> void:
	if not target:
		return

	var canvas := get_node_or_null(target) as CanvasItem
	if not is_instance_valid(canvas):
		return

	if not _saved:
		_original_modulate = canvas.modulate
		_saved = true

	if duration > 0.0:
		var tween := create_tween()
		tween.set_ease(ease_type)
		tween.set_trans(transition_type)
		tween.tween_property(canvas, "modulate", target_color, duration)
	else:
		canvas.modulate = target_color

	_register_revive()

func _on_revive() -> void:
	if not _saved:
		return
	var canvas := get_node_or_null(target) as CanvasItem
	if is_instance_valid(canvas):
		canvas.modulate = _original_modulate
