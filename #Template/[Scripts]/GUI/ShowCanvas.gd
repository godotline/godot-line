@tool
extends Control
class_name ShowCanvas

## Godot equivalent of the Unity ShowCanvas component.
## The script is attached to the Control that owns the animation.

signal show_complete

@export_range(0.0, 10.0, 0.05) var duration: float = 0.5
@export var invokeBeforeAnimation: bool = true
@export var autoHideOnReady: bool = true
@export var hiddenOffsetY: float = 400.0
@export var hiddenRotationDegrees: float = 15.0

var showTween: Tween = null
var onComplete: Callable = Callable()
var completionInvoked: bool = false
var isShowing: bool = false
var isVisible: bool = false
var restOffsetTop: float = 0.0
var restOffsetBottom: float = 0.0
var restRotationDegrees: float = 0.0

func _ready() -> void:
	restOffsetTop = offset_top
	restOffsetBottom = offset_bottom
	restRotationDegrees = rotation_degrees
	if autoHideOnReady:
		_set_hidden_state()

func OnClick() -> void:
	show_canvas()

func show_canvas(onComplete: Callable = Callable()) -> void:
	if isShowing or isVisible:
		return

	isShowing = true
	isVisible = true
	self.onComplete = onComplete
	completionInvoked = false
	StopTweens()
	mouse_filter = Control.MOUSE_FILTER_STOP

	if invokeBeforeAnimation:
		_invoke_completion()

	if duration <= 0.0:
		_set_shown_state()
		_finish_show()
		return

	showTween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	showTween.tween_property(self, "offset_top", restOffsetTop, duration)
	showTween.tween_property(self, "offset_bottom", restOffsetBottom, duration)
	showTween.tween_property(self, "rotation_degrees", restRotationDegrees, duration)
	showTween.tween_property(self, "modulate:a", 1.0, duration)
	showTween.finished.connect(_finish_show)

func StopTweens() -> void:
	if showTween != null and showTween.is_valid():
		showTween.kill()
		showTween = null
	var hideCanvas: Node = get_node_or_null("HideCanvas")
	if hideCanvas != null and hideCanvas.has_method("stop_tweens"):
		hideCanvas.call("stop_tweens")

## Called by the owner before starting its hide animation.
func mark_hidden() -> void:
	StopTweens()
	isShowing = false
	isVisible = false
	onComplete = Callable()
	completionInvoked = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func BtnShow() -> void:
	StopTweens()
	isShowing = false
	isVisible = true
	onComplete = Callable()
	completionInvoked = false
	_set_shown_state()

func _set_hidden_state() -> void:
	offset_top = restOffsetTop + hiddenOffsetY
	offset_bottom = restOffsetBottom + hiddenOffsetY
	rotation_degrees = hiddenRotationDegrees
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	isShowing = false
	isVisible = false

func _set_shown_state() -> void:
	offset_top = restOffsetTop
	offset_bottom = restOffsetBottom
	rotation_degrees = restRotationDegrees
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

func _finish_show() -> void:
	showTween = null
	isShowing = false
	_set_shown_state()
	if not invokeBeforeAnimation:
		_invoke_completion()

func _invoke_completion() -> void:
	if completionInvoked:
		return
	completionInvoked = true
	var callback: Callable = onComplete
	onComplete = Callable()
	if callback.is_valid():
		callback.call()
	show_complete.emit()

# Compatibility names for scene/event code ported directly from Unity.
func Show(onComplete: Callable = Callable()) -> void:
	show_canvas(onComplete)
