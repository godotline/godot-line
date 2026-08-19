class_name PlayerCubes
extends Node3D

var fragments: Array[RigidBody3D] = []

func _ready() -> void:
	for child: Node in get_children():
		var fragment: RigidBody3D = child as RigidBody3D
		if fragment:
			fragments.append(fragment)

func play() -> void:
	for fragment: RigidBody3D in fragments:
		fragment.visible = true
		for child: Node in fragment.get_children():
			var collisionShape: CollisionShape3D = child as CollisionShape3D
			if collisionShape:
				collisionShape.disabled = false
		var scaleRand: float = randf_range(0.6, 1.0)
		fragment.scale = Vector3(scaleRand, scaleRand, scaleRand)
		fragment.rotation = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
		fragment.apply_central_impulse(fragment.rotation_degrees.normalized())