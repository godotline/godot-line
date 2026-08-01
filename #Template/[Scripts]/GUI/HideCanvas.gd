@tool
extends Node
class_name HideCanvas

## Godot equivalent of the Unity HideCanvas component.
## The script is a behavior child of the Control that owns the animation.

signal hide_complete
signal hide_animation_finished

@export_range(0.0, 10.0, 0.05) var duration: float = 0.5
@export var auto_hide_on_ready: bool = true
@export var invoke_before_animation: bool = true
@export var hidden_offset_y: float = 400.0
@export var hidden_rotation_degrees: float = -15.0
@export_range(0.0, 10.0, 0.05) var fade_delay: float = 0.3
@export_range(0.0, 10.0, 0.05) var fade_duration: float = 0.2

var _canvas: Control = null
var _hide_tween: Tween = null
var _completion: Callable = Callable()
var _completion_invoked: bool = false
var _is_hiding: bool = false
var _rest_offset_top: float = 0.0
var _rest_offset_bottom: float = 0.0

func _ready() -> void:
	_canvas = get_parent() as Control
	if _canvas == null:
		push_error("HideCanvas requires a Control parent")
		return

	_rest_offset_top = _canvas.offset_top
	_rest_offset_bottom = _canvas.offset_bottom
	if auto_hide_on_ready:
		call_deferred("_apply_auto_hide")

func _apply_auto_hide() -> void:
	if is_instance_valid(_canvas):
		btn_hide()

func on_click() -> void:
	hide_canvas()

func hide_canvas(on_complete: Callable = Callable()) -> void:
	if _canvas == null or _is_hiding:
		return

	stop_tweens()

	if _canvas.has_method("mark_hidden"):
		_canvas.call("mark_hidden")
	elif _canvas.has_method("stop_tweens"):
		_canvas.call("stop_tweens")

	_is_hiding = true
	_completion = on_complete
	_completion_invoked = false
	if invoke_before_animation:
		_invoke_completion()

	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if duration <= 0.0:
		_set_hidden_state()
		_finish_hide()
		return

	_hide_tween = create_tween().set_parallel(true)
	_hide_tween.tween_property(_canvas, "offset_top", _rest_offset_top + hidden_offset_y, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_hide_tween.tween_property(_canvas, "offset_bottom", _rest_offset_bottom + hidden_offset_y, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_hide_tween.tween_property(_canvas, "rotation_degrees", hidden_rotation_degrees, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_hide_tween.tween_property(_canvas, "modulate:a", 0.0, fade_duration).set_delay(fade_delay).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	_hide_tween.finished.connect(_finish_hide)

func stop_tweens() -> void:
	if _hide_tween != null and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = null
	_is_hiding = false

func btn_hide() -> void:
	stop_tweens()
	_completion = Callable()
	_completion_invoked = false
	_set_hidden_state()

func _set_hidden_state() -> void:
	if _canvas == null:
		return
	_canvas.offset_top = _rest_offset_top + hidden_offset_y
	_canvas.offset_bottom = _rest_offset_bottom + hidden_offset_y
	_canvas.rotation_degrees = -hidden_rotation_degrees
	_canvas.modulate.a = 0.0
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_hiding = false

func _finish_hide() -> void:
	_hide_tween = null
	_set_hidden_state()
	if not invoke_before_animation:
		_invoke_completion()
	hide_animation_finished.emit()

func _invoke_completion() -> void:
	if _completion_invoked:
		return
	_completion_invoked = true
	var callback: Callable = _completion
	_completion = Callable()
	if callback.is_valid():
		callback.call()
	hide_complete.emit()

# Compatibility names for scene/event code ported directly from Unity.
func OnClick() -> void:
	on_click()

func Hide(on_complete: Callable = Callable()) -> void:
	hide_canvas(on_complete)

func StopTweens() -> void:
	stop_tweens()

func BtnHide() -> void:
	btn_hide()
