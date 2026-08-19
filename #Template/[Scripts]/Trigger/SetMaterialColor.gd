@tool
extends Node

@export var colors: Array[SingleColor] = []
@export var duration: float = 2.0
@export var transType: int = 0
@export var ease: int = 0
## 目标网格，如果不指定则尝试从 body 上找
@export var targetMesh: MeshInstance3D


func trigger(body: Node3D) -> void:
	for sc in colors:
		_apply_color(sc, body)


## 对单个 SingleColor 应用颜色变化，通过 material_override + duplicate 避免污染原始 .tres 资源
func _apply_color(sc: SingleColor, body: Node3D) -> void:
	if not sc.material:
		return

	# 确定目标网格
	var mesh: MeshInstance3D = targetMesh
	if not mesh:
		mesh = body.find_child("MeshInstance3D", true, false) as MeshInstance3D
	if not mesh:
		return

	# 复制材质，确保不修改原始磁盘资源
	var mat: Material = sc.material
	if not mat.resource_local_to_scene:
		mat = mat.duplicate()
		mat.resource_local_to_scene = true

	# 通过 material_override 临时覆盖（不会写入 .tres 文件）
	mesh.material_override = mat

	# 补间动画
	var tween: Tween = create_tween()
	tween.set_ease(ease)
	tween.set_trans(transType)
	tween.tween_property(mat, "albedo_color", sc.color, duration)
	if sc.has_emission and mat is StandardMaterial3D:
		mat.emission_enabled = true
		tween.tween_property(mat, "emission", sc.color, duration)
		tween.parallel().tween_property(mat, "emission_energy_multiplier", sc.intensity, duration)