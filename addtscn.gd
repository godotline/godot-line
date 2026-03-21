extends Node

# 引用场景
var scene_to_add = preload("res://Scenes/trigger.tscn")

@export var create_collisions: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_ready()
			create_collisions = false
func _ready():
	# 遍历当前节点的所有子节点
	for node in get_children():
		# 检查节点名称中是否包含"trigger"
		if "trigger" in str(node.name).to_lower():
			# 确保节点是一个3D节点（例如Spatial、Node3D等）
			if node is Node3D:
				# 实例化场景
				var instance = scene_to_add.instantiate()
				# 设置实例的位置为触发器的位置
				instance.transform.origin = node.global_transform.origin
				# 将实例添加到当前场景
				add_child(instance)
