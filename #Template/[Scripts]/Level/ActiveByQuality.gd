extends Node

@export var showInLow: bool = true
@export var showInMedium: bool = true
@export var showInHigh: bool = true

func _ready() -> void:
	add_to_group("active_by_quality")
	apply_quality(GraphicsQuality.qualityLevel)

func _exit_tree() -> void:
	remove_from_group("active_by_quality")

func apply_quality(qualityLevel: int) -> void:
	var enabled: bool
	match qualityLevel:
		0:
			enabled = showInLow
		1:
			enabled = showInMedium
		_:
			enabled = showInHigh
	var target: Node = get_parent()
	if target is CanvasItem:
		target.visible = enabled
	elif target is Node3D:
		target.visible = enabled
	else:
		target.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
