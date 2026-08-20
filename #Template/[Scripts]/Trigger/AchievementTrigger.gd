extends Node

## Projects may connect this signal to their platform-specific achievement service.
signal achievement_requested(achievementKey: String)

@export var achievementKey: String = ""
var triggered: bool = false

func trigger(body: Node3D) -> void:
	if body is Player and not triggered:
		triggered = true
		achievement_requested.emit(achievementKey)
