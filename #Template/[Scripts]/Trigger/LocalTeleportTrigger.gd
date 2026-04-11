extends BaseTrigger

@export var tp_x := 0.0
@export var tp_y := 0.0
@export var tp_z := 0.0

@export var target:NodePath
@onready var target_node:Node3D = get_node(target) if target else null

func _ready():
	super._ready()

func _on_triggered(body) -> void:
	if body is CharacterBody3D:
		body.position += Vector3(tp_x,tp_y,tp_z)
		body.new_line()
		if target_node: 
			target_node.position = Vector3(tp_x,tp_y,tp_z)
