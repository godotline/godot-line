@tool
extends Node3D
class_name JumpPredictor
## JumpPredictor - 跳跃轨迹预测器
## 发射模拟玩家显示跳跃轨迹

enum LineDirection {
	Left,
	Right
}

@export_group("预测设置")
@export var speed_x: float = 12.0
@export var direction: LineDirection = LineDirection.Right
@export var reverse: bool = false
@export var show_in_game: bool = true

@export_group("预览控制")
@export var draw_preview: bool = false:
	set(value):
		draw_preview = value
		if value and Engine.is_editor_hint():
			_draw_editor_preview()
@export var clear_preview: bool = false:
	set(value):
		clear_preview = value
		if value:
			_clear()

var _jump_node: Node
var _simulated_player: CharacterBody3D
var _line_mesh: MeshInstance3D
var _trajectory_points: Array[Vector3] = []

func _ready() -> void:
	top_level = true
	
	if not Engine.is_editor_hint() and show_in_game:
		_start_simulation()
	else:
		# 编辑器模式下，延迟连接信号
		call_deferred("_connect_to_jump")

func _check_parent() -> void:
	var parent = get_parent()
	if parent is Area3D:
		var script = parent.get_script()
		if script and script.resource_path.ends_with("Jump.gd"):
			_jump_node = parent
			print("[JumpPredictor] 找到Jump节点: ", parent.name)
			return
	print("[JumpPredictor] 父节点不是Area3D或没有Jump.gd脚本")

func _connect_to_jump() -> void:
	_check_parent()
	if _jump_node and _jump_node.has_signal("height_changed"):
		_jump_node.height_changed.connect(_on_height_changed)

func _on_height_changed(new_height: float) -> void:
	if Engine.is_editor_hint():
		_draw_editor_preview_with_jump(_jump_node)

func _start_simulation() -> void:
	if not _jump_node:
		_check_parent()
		if not _jump_node:
			return
	
	if not is_inside_tree():
		return
	
	_clear()
	
	var parent = get_parent()
	var base_pos = parent.global_position if parent else global_position
	
	var height: float = _jump_node.get("height") if _jump_node else 1.0
	var jump_speed = sqrt(2 * 9.8 * height)
	
	# 创建模拟玩家
	_simulated_player = CharacterBody3D.new()
	_simulated_player.name = "SimulatedPlayer"
	
	# 添加碰撞形状
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.3, 0.3, 0.3)
	collision.shape = shape
	_simulated_player.add_child(collision)
	
	# 添加可视网格
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.3, 0.3, 0.3)
	mesh_instance.mesh = box_mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	_simulated_player.add_child(mesh_instance)
	
	# 添加到场景
	add_child(_simulated_player)
	_simulated_player.global_position = base_pos
	
	# 绘制轨迹线
	_trajectory_points.clear()
	_trajectory_points.append(base_pos)
	_create_line_mesh()
	
	# 设置初始速度
	var vel := Vector3.ZERO
	match direction:
		LineDirection.Left:
			vel = Vector3(0, jump_speed, -speed_x if reverse else speed_x)
		LineDirection.Right:
			vel = Vector3(-speed_x if reverse else speed_x, jump_speed, 0)
	
	_simulated_player.velocity = vel
	
	# 启动模拟协程
	_run_simulation()

func _run_simulation() -> void:
	var gravity = 9.8
	var dt = 1.0 / 60.0
	var max_time = 10.0
	var t = 0.0
	var landed = false
	var land_time = 0.0
	
	while t < max_time and _simulated_player and is_instance_valid(_simulated_player):
		# 应用重力
		_simulated_player.velocity.y -= gravity * dt
		_simulated_player.move_and_slide()
		
		# 记录轨迹点
		_trajectory_points.append(_simulated_player.global_position)
		_update_line_mesh()
		
		# 检测落地
		if _simulated_player.is_on_floor() and not landed:
			landed = true
			land_time = t
			print("[JumpPredictor] 落地时间: ", t)
		
		# 落地后2秒删除
		if landed and (t - land_time) >= 2.0:
			print("[JumpPredictor] 删除模拟玩家")
			_clear()
			return
		
		t += dt
		await get_tree().process_frame
	
	# 超时删除
	_clear()

func _clear() -> void:
	if _simulated_player and is_instance_valid(_simulated_player):
		_simulated_player.queue_free()
		_simulated_player = null
	if _line_mesh and is_instance_valid(_line_mesh):
		_line_mesh.queue_free()
		_line_mesh = null
	_trajectory_points.clear()

func _draw_editor_preview() -> void:
	_check_parent()
	if not _jump_node:
		return
	_draw_editor_preview_with_jump(_jump_node)

func _draw_editor_preview_with_jump(jump_node: Node) -> void:
	_jump_node = jump_node
	
	if not is_inside_tree():
		return
	
	_clear()
	
	var parent = get_parent()
	var base_pos = parent.global_position if parent else global_position
	
	var height: float = _jump_node.get("height") if _jump_node else 1.0
	var jump_speed = sqrt(2 * 9.8 * height)
	
	# 绘制静态轨迹线（编辑器预览）
	_line_mesh = MeshInstance3D.new()
	_line_mesh.name = "TrajectoryLine"
	_line_mesh.top_level = true
	add_child(_line_mesh)
	_line_mesh.global_position = Vector3.ZERO
	
	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	# 模拟轨迹
	var pos: Vector3 = base_pos
	var vel: Vector3 = Vector3.ZERO
	
	match direction:
		LineDirection.Left:
			vel = Vector3(0, jump_speed, -speed_x if reverse else speed_x)
		LineDirection.Right:
			vel = Vector3(-speed_x if reverse else speed_x, jump_speed, 0)
	
	var gravity = 9.8
	var dt = 1.0 / 60.0
	var max_time = 10.0
	var t = 0.0
	
	while t < max_time:
		immediate_mesh.surface_add_vertex(pos)
		vel.y -= gravity * dt
		pos += vel * dt
		if pos.y < base_pos.y and t > 0.1:
			break
		t += dt
	
	immediate_mesh.surface_end()
	_line_mesh.mesh = immediate_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mesh.material_override = material
	
	print("[JumpPredictor] 编辑器预览完成")

func _create_line_mesh() -> void:
	if _line_mesh and is_instance_valid(_line_mesh):
		_line_mesh.queue_free()
	
	_line_mesh = MeshInstance3D.new()
	_line_mesh.name = "TrajectoryLine"
	_line_mesh.top_level = true
	add_child(_line_mesh)
	_line_mesh.global_position = Vector3.ZERO
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mesh.material_override = material
	
	_update_line_mesh()

func _update_line_mesh() -> void:
	if not _line_mesh or not is_instance_valid(_line_mesh):
		return
	if _trajectory_points.size() < 2:
		return
	
	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	for point in _trajectory_points:
		immediate_mesh.surface_add_vertex(point)
	
	immediate_mesh.surface_end()
	_line_mesh.mesh = immediate_mesh
