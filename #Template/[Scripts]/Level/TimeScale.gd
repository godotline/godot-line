extends Node

@export var key: Key = KEY_T
@export_range(0.0, 3.0, 0.01) var enabledValue: float = 1.25
@export_range(0.0, 3.0, 0.01) var disabledValue: float = 1.0

var enabled: bool = false

func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == key:
		enabled = not enabled
		var value: float = enabledValue if enabled else disabledValue
		Engine.time_scale = value
		AudioManager.Pitch = value
