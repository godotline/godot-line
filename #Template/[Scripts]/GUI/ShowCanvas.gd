@tool
extends Control
class_name ShowCanvas

## Godot equivalent of the Unity ShowCanvas component.
## The script is attached to the Control that owns the animation.

signal show_complete

@export_range(0.0, 10.0, 0.05) var duration: float = 0.5
@export var invoke_before_animation: bool = true
@export var auto_hide_on_ready: bool = true
@export var hidden_offset_y: float = 400.0
@export var hidden_rotation_degrees: float = 15.0

var _show_tween: Tween = null
var _completion: Callable = Callable()
var _completion_invoked: bool = false
var _is_showing: bool = false
var _is_visible: bool = false
var _rest_offset_top: float = 0.0
var _rest_offset_bottom: float = 0.0
var _rest_rotation_degrees: float = 0.0

func _ready() -> void:
	_rest_offset_top = offset_top
	_rest_offset_bottom = offset_bottom
	_rest_rotation_degrees = rotation_degrees
	if auto_hide_on_ready:
		_set_hidden_state()

func on_click() -> void:
	show_canvas()

func show_canvas(on_complete: Callable = Callable()) -> void:
	if _is_showing or _is_visible:
		return

	_is_showing = true
	_is_visible = true
	_completion = on_complete
	_completion_invoked = false
	stop_tweens()
	mouse_filter = Control.MOUSE_FILTER_STOP

	if invoke_before_animation:
		_invoke_completion()

	if duration <= 0.0:
		_set_shown_state()
		_finish_show()
		return

	_show_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	_show_tween.tween_property(self, "offset_top", _rest_offset_top, duration)
	_show_tween.tween_property(self, "offset_bottom", _rest_offset_bottom, duration)
	_show_tween.tween_property(self, "rotation_degrees", _rest_rotation_degrees, duration)
	_show_tween.tween_property(self, "modulate:a", 1.0, duration)
	_show_tween.finished.connect(_finish_show)

func stop_tweens() -> void:
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
		_show_tween = null
	var hide_canvas: Node = get_node_or_null("HideCanvas")
	if hide_canvas != null and hide_canvas.has_method("stop_tweens"):
		hide_canvas.call("stop_tweens")

## Called by the owner before starting its hide animation.
func mark_hidden() -> void:
	stop_tweens()
	_is_showing = false
	_is_visible = false
	_completion = Callable()
	_completion_invoked = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func btn_show() -> void:
	stop_tweens()
	_is_showing = false
	_is_visible = true
	_completion = Callable()
	_completion_invoked = false
	_set_shown_state()

func _set_hidden_state() -> void:
	offset_top = _rest_offset_top + hidden_offset_y
	offset_bottom = _rest_offset_bottom + hidden_offset_y
	rotation_degrees = hidden_rotation_degrees
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_showing = false
	_is_visible = false

func _set_shown_state() -> void:
	offset_top = _rest_offset_top
	offset_bottom = _rest_offset_bottom
	rotation_degrees = _rest_rotation_degrees
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

func _finish_show() -> void:
	_show_tween = null
	_is_showing = false
	_set_shown_state()
	if not invoke_before_animation:
		_invoke_completion()

func _invoke_completion() -> void:
	if _completion_invoked:
		return
	_completion_invoked = true
	var callback: Callable = _completion
	_completion = Callable()
	if callback.is_valid():
		callback.call()
	show_complete.emit()

# Compatibility names for scene/event code ported directly from Unity.
func OnClick() -> void:
	on_click()

func Show(on_complete: Callable = Callable()) -> void:
	show_canvas(on_complete)

func StopTweens() -> void:
	stop_tweens()

func BtnShow() -> void:
	btn_show()
