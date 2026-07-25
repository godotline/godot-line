extends Node
@export var disableInPlayMode: bool = true
func _ready():
	if not Engine.is_editor_hint() and disableInPlayMode:
		self.visible = false
