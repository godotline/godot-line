extends Node

const Setactive = preload("res://#Template/[Scripts]/Trigger/SetActive.gd")

@export var showInLow: bool = true
@export var showInMedium: bool = true
@export var showInHigh: bool = true

func _ready() -> void:
	add_to_group("active_by_quality")
	apply_quality(GraphicsQuality.level)

func _exit_tree() -> void:
	remove_from_group("active_by_quality")

func apply_quality(quality_level: int) -> void:
	var enabled: bool
	match quality_level:
		0:
			enabled = showInLow
		1:
			enabled = showInMedium
		_:
			enabled = showInHigh
	Setactive.setActive(get_parent(), enabled)
