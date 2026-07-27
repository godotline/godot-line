extends Node

@export var show_in_low: bool = true
@export var show_in_medium: bool = true
@export var show_in_high: bool = true

func _ready() -> void:
	add_to_group("active_by_quality")
	apply_quality(GraphicsQuality.level)

func _exit_tree() -> void:
	remove_from_group("active_by_quality")

func apply_quality(quality_level: int) -> void:
	var enabled: bool
	match quality_level:
		0:
			enabled = show_in_low
		1:
			enabled = show_in_medium
		_:
			enabled = show_in_high
	var target: Node = get_parent()
	if target is CanvasItem:
		target.visible = enabled
	elif target is Node3D:
		target.visible = enabled
	else:
		target.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
