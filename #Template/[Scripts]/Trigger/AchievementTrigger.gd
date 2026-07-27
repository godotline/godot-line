extends Node3D

## Projects may connect this signal to their platform-specific achievement service.
signal achievement_requested(achievement_key: String)

@export var achievement_key: String = ""
var _triggered: bool = false

func trigger(body: Node3D) -> void:
	if body is Player and not _triggered:
		_triggered = true
		achievement_requested.emit(achievement_key)
