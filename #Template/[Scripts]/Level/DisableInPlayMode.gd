extends Node

const Setactive = preload("res://#Template/[Scripts]/Trigger/SetActive.gd")

@export var disableInPlayMode: bool = true

func _ready() -> void:
	if not Engine.is_editor_hint() and disableInPlayMode:
		Setactive.setActive(self, false)
