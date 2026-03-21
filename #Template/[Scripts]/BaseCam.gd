extends Node3D

@export var target:NodePath
@export var speed := 1.0
@onready var target_node:Node3D = get_node(target) if target else null

#摄像机移动
func _ready() -> void:
	if target_node: position = target_node.position

func _process(delta: float) -> void:
	if target_node and State.is_end == false:
		position = position.lerp(target_node.position, delta * speed)
