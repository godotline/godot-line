@tool
extends EditorDebuggerPlugin

const CAPTURE_PREFIX: String = "template_checkpoint"
const CAPTURE_MESSAGE: String = "template_checkpoint:captured"

var _snapshot_callback: Callable

func setup(snapshot_callback: Callable) -> void:
	_snapshot_callback = snapshot_callback

func _has_capture(capture: String) -> bool:
	return capture == CAPTURE_PREFIX

func _capture(message: String, data: Array, _session_id: int) -> bool:
	if message != CAPTURE_MESSAGE or data.is_empty() or not data[0] is Dictionary:
		return false
	if _snapshot_callback.is_valid():
		_snapshot_callback.call_deferred(data[0] as Dictionary)
	return true
