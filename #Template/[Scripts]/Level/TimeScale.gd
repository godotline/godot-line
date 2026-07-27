extends Node

@export var toggle_key: Key = KEY_T
@export_range(0.0, 3.0, 0.01) var enabled_value: float = 1.25
@export_range(0.0, 3.0, 0.01) var disabled_value: float = 1.0

var _enabled: bool = false

func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or LevelManager.GameState != LevelManager.GameStatus.Playing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		_enabled = not _enabled
		var value: float = enabled_value if _enabled else disabled_value
		Engine.time_scale = value
		AudioManager.pitch = value
