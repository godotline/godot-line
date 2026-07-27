extends Node
@export var disableInPlayMode: bool = true

func _ready() -> void:
	if not Engine.is_editor_hint() and disableInPlayMode:
		# This script is attached directly to the editor-only object.
		# Calling get_parent() here would hide its containing level group.
		set("visible", false)
