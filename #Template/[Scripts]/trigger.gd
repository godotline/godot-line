extends Area3D

@export var one_shot: bool = false
var used: bool = true

signal hit_the_line

func _on_body_entered(body: Node3D) -> void :
	if body is CharacterBody3D:
		emit_signal("hit_the_line")
		if one_shot:
			used = true

func _ready() -> void:
	$MeshInstance3D.visible = false
