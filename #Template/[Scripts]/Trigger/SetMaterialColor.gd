@tool
extends BaseTrigger
## @deprecated: 推荐使用 MaterialColorBehavior 作为 BaseTrigger 的子节点
## SetMaterialColor - 材质颜色变化触发器（向后兼容包装）
class_name SetMaterialColor


@export var colors: Array[SingleColor] = []
@export var duration: float = 2.0
@export var trans_type: int = 0
@export var ease_type: int = 0
## 目标网格，如果不指定则尝试从 body 上找
@export var target_mesh: MeshInstance3D


func _on_triggered(_body: Node3D) -> void:
	for sc in colors:
		_apply_color(sc, _body)


## 对单个 SingleColor 应用颜色变化，通过 material_override + duplicate 避免污染原始 .tres 资源
func _apply_color(sc: SingleColor, _body: Node3D) -> void:
	if not sc.material:
		return

	# 确定目标网格
	var mesh = target_mesh
	if not mesh:
		mesh = _body.find_child("MeshInstance3D", true, false) as MeshInstance3D
	if not mesh:
		return

	# 复制材质，确保不修改原始磁盘资源
	var mat = sc.material
	if not mat.resource_local_to_scene:
		mat = mat.duplicate()
		mat.resource_local_to_scene = true

	# 通过 material_override 临时覆盖（不会写入 .tres 文件）
	mesh.material_override = mat

	# 补间动画
	var tween := create_tween()
	tween.set_ease(ease_type)
	tween.set_trans(trans_type)
	tween.tween_property(mat, "albedo_color", sc.color, duration)
	if sc.has_emission and mat is StandardMaterial3D:
		mat.emission_enabled = true
		tween.tween_property(mat, "emission", sc.color, duration)
		tween.parallel().tween_property(mat, "emission_energy_multiplier", sc.intensity, duration)
