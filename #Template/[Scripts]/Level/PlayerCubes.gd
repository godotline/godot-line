class_name PlayerCubes
extends Node3D

## Unity PlayerCubes.cs + Remain.prefab 的 Godot 移植。
## 死亡碎块容器：子节点为 RigidBody3D 碎片（默认隐藏 + 冻结），
## play() 遍历碎片：激活 + 随机缩放 0.6~1.0 + 随机旋转 + 旋转欧拉角归一化方向冲量。

## 冲量系数（乘以玩家速度）。Unity 原版为固定单位冲量（mass=100 → 约 0.01 m/s），
## 本项目用玩家速度放大以得到可见的散布。
@export var impulse_multiplier: float = 0.4

## 把玩家当前 mesh/material 应用到每个碎片（对齐 Godot 玩家可变身的需求）
func setup(player_mesh: Mesh, player_material: Material) -> void:
	for fragment: RigidBody3D in _get_fragments():
		var mesh_instance: MeshInstance3D = fragment.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh_instance:
			mesh_instance.mesh = player_mesh
			mesh_instance.material_override = player_material

## 对齐 Unity PlayerCubes.Play()：激活碎片 + 随机缩放 + 随机旋转 + 欧拉角归一化方向冲量
func play(impulse_speed: float) -> void:
	for fragment: RigidBody3D in _get_fragments():
		fragment.visible = true
		fragment.freeze = false
		var scale_factor: float = randf_range(0.6, 1.0)
		fragment.scale = Vector3(scale_factor, scale_factor, scale_factor)
		var random_rot: Vector3 = _random_rotation()
		fragment.rotation = random_rot
		var direction: Vector3 = random_rot.normalized()
		fragment.apply_central_impulse(direction * impulse_speed * impulse_multiplier)

func _get_fragments() -> Array[RigidBody3D]:
	var fragments: Array[RigidBody3D] = []
	for child: Node in get_children():
		var fragment: RigidBody3D = child as RigidBody3D
		if fragment:
			fragments.append(fragment)
	return fragments

func _random_rotation() -> Vector3:
	return Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
