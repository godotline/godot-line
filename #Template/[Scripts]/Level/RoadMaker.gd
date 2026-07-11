extends Node3D

@export var base_floor:PackedScene
@export var road_width := 3.0

@onready var main_line:Node3D = get_parent()
@onready var past_translation := main_line.position

var road:StaticBody3D
var roads := Node3D.new()

## 每段路面的视觉/碰撞分离缓存
## _road_visuals[road] = MeshInstance3D  — 视觉部分，每帧缩放（不触发物理重建）
## _road_collisions[road] = CollisionShape3D — 碰撞部分，仅在路线完成时更新
var _road_visuals: Dictionary = {}
var _road_collisions: Dictionary = {}
var _road_done: Dictionary = {}  # 标记路面是否已完成（停止更新）

func _ready() -> void:
	if main_line:
		if main_line.has_signal("new_line1"):
			main_line.connect("new_line1", Callable(self, "new_road"))
		if main_line.has_signal("on_sky"):
			main_line.connect("on_sky", Callable(self, "on_sky"))
	roads.name = "Roads"
	roads.position = to_global(position)
	get_tree().current_scene.call_deferred("add_child",roads)

func new_road():
	# 在创建新路段前，完成上一段路面的碰撞体（一次性设置）
	_finalize_previous_road()

	road = base_floor.instantiate()
	road.position = main_line.position
	past_translation = main_line.position
	roads.add_child(road)
	road.owner = roads

	# 分离视觉和碰撞：查找 MeshInstance3D 和 CollisionShape3D
	# 视觉部分将替代 road 整体缩放，碰撞部分延迟更新
	var mesh_child := _find_child_of_type(road, MeshInstance3D) as MeshInstance3D
	var collision_child := _find_child_of_type(road, CollisionShape3D) as CollisionShape3D

	if mesh_child and collision_child:
		if mesh_child.mesh:
			mesh_child.mesh = mesh_child.mesh.duplicate() as Mesh
		if collision_child.shape:
			collision_child.shape = collision_child.shape.duplicate() as Shape3D
		_road_visuals[road] = mesh_child
		_road_collisions[road] = collision_child
		# 碰撞体禁用直到路面完成（减少中间态的物理重建开销）
		collision_child.set_deferred("disabled", true)
	road.rotation = main_line.rotation

func _find_child_of_type(parent: Node, child_type) -> Node:
	for child in parent.get_children():
		if is_instance_of(child, child_type):
			return child
	return null

func _get_road_size() -> Vector3:
	var offset := main_line.position - past_translation
	var distance := offset.length()
	return Vector3(road_width, 1.0, distance + road_width)

## 完成上一段路面：一次性设置碰撞体尺寸，启用碰撞
func _finalize_previous_road() -> void:
	if road and road in _road_collisions and not _road_done.get(road, false):
		var collision := _road_collisions[road] as CollisionShape3D
		if collision and collision.shape:
			# 计算最终尺寸
			var final_size := _get_road_size()
			# 直接设置 shape 的 size（BoxShape3D），而非缩放 CollisionShape3D
			# 这避免了缩放 StaticBody3D 带来的物理重建
			if collision.shape is BoxShape3D:
				var box := collision.shape as BoxShape3D
				box.size = final_size
				# 如果 MeshInstance3D 的 mesh 也是 BoxMesh，设置其 size 保持一致
				var visual := _road_visuals.get(road) as MeshInstance3D
				if visual and visual.mesh is BoxMesh:
					(visual.mesh as BoxMesh).size = final_size
					visual.scale = Vector3.ONE
			# 启用碰撞
			collision.set_deferred("disabled", false)
		_road_done[road] = true

func _physics_process(_delta: float) -> void:
	if road:
		var offset := main_line.position - past_translation
		road.position = offset / 2 + past_translation
		var new_scale := _get_road_size()

		# 分离策略：只缩放视觉部分，不触发物理重建
		if road in _road_visuals:
			(_road_visuals[road] as MeshInstance3D).scale = new_scale
		else:
			# 兜底：如果没有找到视觉/碰撞分离结构，回退到原始行为
			road.scale = new_scale

func on_sky():
	# 离开地面时，完成当前路段
	_finalize_previous_road()
	road = null
