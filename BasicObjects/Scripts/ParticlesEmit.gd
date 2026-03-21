@tool
extends Area3D

@export var particles: Array[Node3D] = []  # 支持 GPUParticles3D 和 CPUParticles3D
@export var one_shot: bool = false
var used: bool = false

signal hit_the_line


@export var 预览粒子: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_toggle_particles()
			await get_tree().create_timer(0.1).timeout
			预览粒子 = false

@export var 停止粒子: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_stop_particles()
			await get_tree().create_timer(0.1).timeout
			停止粒子 = false


func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if not (body is CharacterBody3D):
		return
	if one_shot and used:
		return
	
	hit_the_line.emit()
	_toggle_particles()
	
	if one_shot:
		used = true


func _toggle_particles() -> void:
	for node in particles:
		if not is_instance_valid(node):
			continue
		
		# 切换发射状态 (GPUParticles3D / CPUParticles3D)
		if node is GPUParticles3D:
			node.emitting = !node.emitting
		elif node is CPUParticles3D:
			node.emitting = !node.emitting


func _stop_particles() -> void:
	for node in particles:
		if not is_instance_valid(node):
			continue
			
		if node is GPUParticles3D:
			node.emitting = false
		elif node is CPUParticles3D:
			node.emitting = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	used = false
	_stop_particles()
	
	if has_node("MeshInstance3D"):
		$MeshInstance3D.visible = false
