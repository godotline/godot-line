class_name ActiveByQuality
extends Node

@export var showInLow: bool = false
@export var showInMedium: bool = false
@export var showInHigh: bool = false

func _ready() -> void:
	add_to_group("active_by_quality")
	applyQuality(GraphicsQuality.qualityLevel)

func _exit_tree() -> void:
	remove_from_group("active_by_quality")

func applyQuality(qualityLevel: int) -> void:
	var enabled: bool
	match qualityLevel:
		0:
			enabled = showInLow
		1:
			enabled = showInMedium
		_:
			enabled = showInHigh
	var target: Node = get_parent()
	if target:
		SetActive.SetNodeActive(target, enabled)

# 兼容旧调用
func apply_quality(qualityLevel: int) -> void:
	applyQuality(qualityLevel)
