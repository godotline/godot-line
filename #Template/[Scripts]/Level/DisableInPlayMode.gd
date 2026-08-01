extends Node
@export var disableInPlayMode: bool = true

func _ready() -> void:
	if not Engine.is_editor_hint() and disableInPlayMode:
		self.queue_free()
