@tool
extends Node
class_name HideCanvas

## Godot equivalent of the Unity HideCanvas component.
## The script is a behavior child of the Control that owns the animation.

signal hide_complete
signal hide_animation_finished

@export_range(0.0, 10.0, 0.05) var duration: float = 0.5
@export var autoHideOnEnable: bool = true
@export var invokeBeforeAnimation: bool = true
@export var hiddenOffsetY: float = 400.0
@export var hiddenRotationDegrees: float = -15.0
@export_range(0.0, 10.0, 0.05) var fadeDelay: float = 0.3
@export_range(0.0, 10.0, 0.05) var fadeDuration: float = 0.2

var canvas: Control = null
var hideTween: Tween = null
var onComplete: Callable = Callable()
var completionInvoked: bool = false
var isHiding: bool = false
var restOffsetTop: float = 0.0
var restOffsetBottom: float = 0.0

func _ready() -> void:
	canvas = get_parent() as Control
	if canvas == null:
		push_error("HideCanvas requires a Control parent")
		return

	restOffsetTop = canvas.offset_top
	restOffsetBottom = canvas.offset_bottom
	if autoHideOnEnable:
		call_deferred("_apply_auto_hide")

func _apply_auto_hide() -> void:
	if is_instance_valid(canvas):
		BtnHide()

func OnClick() -> void:
	hide_canvas()

func hide_canvas(onComplete: Callable = Callable()) -> void:
	if canvas == null or isHiding:
		return

	StopTweens()

	if canvas.has_method("mark_hidden"):
		canvas.call("mark_hidden")
	elif canvas.has_method("stop_tweens"):
		canvas.call("stop_tweens")

	isHiding = true
	self.onComplete = onComplete
	completionInvoked = false
	if invokeBeforeAnimation:
		_invoke_completion()

	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if duration <= 0.0:
		_set_hidden_state()
		_finish_hide()
		return

	hideTween = create_tween().set_parallel(true)
	hideTween.tween_property(canvas, "offset_top", restOffsetTop + hiddenOffsetY, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	hideTween.tween_property(canvas, "offset_bottom", restOffsetBottom + hiddenOffsetY, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	hideTween.tween_property(canvas, "rotation_degrees", hiddenRotationDegrees, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	hideTween.tween_property(canvas, "modulate:a", 0.0, fadeDuration).set_delay(fadeDelay).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	hideTween.finished.connect(_finish_hide)

func StopTweens() -> void:
	if hideTween != null and hideTween.is_valid():
		hideTween.kill()
	hideTween = null
	isHiding = false

func BtnHide() -> void:
	StopTweens()
	onComplete = Callable()
	completionInvoked = false
	_set_hidden_state()

func _set_hidden_state() -> void:
	if canvas == null:
		return
	canvas.offset_top = restOffsetTop + hiddenOffsetY
	canvas.offset_bottom = restOffsetBottom + hiddenOffsetY
	canvas.rotation_degrees = -hiddenRotationDegrees
	canvas.modulate.a = 0.0
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	isHiding = false

func _finish_hide() -> void:
	hideTween = null
	_set_hidden_state()
	if not invokeBeforeAnimation:
		_invoke_completion()
	hide_animation_finished.emit()

func _invoke_completion() -> void:
	if completionInvoked:
		return
	completionInvoked = true
	var callback: Callable = onComplete
	onComplete = Callable()
	if callback.is_valid():
		callback.call()
	hide_complete.emit()

# Compatibility names for scene/event code ported directly from Unity.
func Hide(onComplete: Callable = Callable()) -> void:
	hide_canvas(onComplete)
