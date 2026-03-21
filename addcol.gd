@tool
extends Node3D

# 配置变量 - 只处理名称包含这些关键字的节点
@export var name_filters = []
@export var layer = 2

@export var create_collisions: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			create_static_bodies_for_meshes()
			create_collisions = false

@export var remove_collisions: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			remove_all_static_bodies()
			remove_collisions = false

func create_static_bodies_for_meshes():
	var mesh_instances = get_all_mesh_instances(self)
	var count = 0
	
	for mesh_instance in mesh_instances:
		# 检查是否匹配任何名称过滤器
		if not matches_any_filter(mesh_instance.name):
			continue
		
		# 跳过已经有 StaticBody3D 子节点的
		if has_static_body_child(mesh_instance):
			continue
		
		# 检查是否有有效的 mesh
		if not mesh_instance.mesh:
			print("警告: ", mesh_instance.name, " 没有 mesh")
			continue
		
		# 创建 StaticBody3D
		var static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		static_body.collision_layer = layer
		
		# 创建 CollisionShape3D
		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		
		# 创建单一凸形碰撞体
		var convex_shape = mesh_instance.mesh.create_convex_shape()
		collision_shape.shape = convex_shape
		
		# 添加 collision_shape 到 static_body
		static_body.add_child(collision_shape)
		
		# 添加 static_body 到 mesh_instance
		mesh_instance.add_child(static_body)
		
		# 设置所有权 - 在添加到场景树之后
		if Engine.is_editor_hint():
			var scene_root = get_tree().edited_scene_root
			static_body.owner = scene_root
			collision_shape.owner = scene_root
		
		count += 1
		print("✓ 为 ", mesh_instance.name, " 创建了凸形碰撞体")
	
	print("完成！共创建 ", count, " 个静态碰撞体")

func remove_all_static_bodies():
	var static_bodies = get_all_static_bodies(self)
	var count = 0
	
	for static_body in static_bodies:
		# 检查是否匹配任何名称过滤器
		if not matches_any_filter(static_body.get_parent().name):
			continue
		
		# 删除 StaticBody3D
		static_body.queue_free()
		count += 1
	
	print("✓ 移除了 ", count, " 个静态碰撞体")

# 检查节点是否有 StaticBody3D 子节点
func has_static_body_child(node: Node) -> bool:
	for child in node.get_children():
		if child is StaticBody3D:
			return true
	return false

# 检查名称是否匹配任何过滤器
func matches_any_filter(_name: String) -> bool:
	var lower_name = name.to_lower()
	for filter in name_filters:
		if filter.to_lower() in lower_name:
			return true
	return false

# 递归获取所有 MeshInstance3D 节点
func get_all_mesh_instances(node: Node) -> Array:
	var mesh_instances = []
	
	for child in node.get_children():
		if child is MeshInstance3D:
			mesh_instances.append(child)
		# 递归查找子节点
		mesh_instances += get_all_mesh_instances(child)
	
	return mesh_instances

# 递归获取所有 StaticBody3D 节点
func get_all_static_bodies(node: Node) -> Array:
	var static_bodies = []
	
	for child in node.get_children():
		if child is StaticBody3D:
			static_bodies.append(child)
		# 递归查找子节点
		static_bodies += get_all_static_bodies(child)
	
	return static_bodies
