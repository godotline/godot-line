extends Area3D

@export var tp_x := 0.0
@export var tp_y := 0.0
@export var tp_z := 0.0

@export var target:NodePath
@onready var target_node:Node3D = get_node(target) if target else null

func _ready():
	monitoring = true

func _on_body_entered(body: PhysicsBody3D) -> void:
	if body is CharacterBody3D:
		var character := body as CharacterBody3D
		character.position += Vector3(tp_x,tp_y,tp_z)
		if target_node: 
			target_node.position = Vector3(tp_x,tp_y,tp_z)
