@tool # 必须放在首行，启用编辑器模式
extends Area3D

# 可以手动指定粒子系统，如果为空且开启auto_collect则自动收集所有子节点
@export var particle_systems: Array[Node] = []
# 是否自动收集子节点下的所有粒子系统（GPUParticles3D 和 CPUParticles3D）
@export var auto_collect: bool = true
# 进入时是否重启粒子（重新发射），如果为false则只是确保emitting=true
@export var restart_on_enter: bool = true
@export var one_shot: bool = false

var used: bool = false

signal hit_the_line

# ==================== 编辑器按钮 ====================
@export var 发射粒子: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_emit_particles()
			# 自动复位，表现得像按钮
			await get_tree().create_timer(0.1).timeout
			发射粒子 = false

@export var 停止发射: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_stop_particles()
			await get_tree().create_timer(0.1).timeout
			停止发射 = false

# ==================== 核心逻辑 ====================

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	used = false
	_stop_particles()
	
	# 连接信号
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# 自动收集粒子系统
	if auto_collect and particle_systems.is_empty():
		_collect_particle_systems()
	
	# 隐藏碰撞网格（如果存在）
	if has_node("MeshInstance3D"):
		$MeshInstance3D.visible = false

func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	
	# 检测物理体进入
	if not (body is CharacterBody3D or body is RigidBody3D or body is StaticBody3D):
		return
	
	if one_shot and used:
		return
	
	hit_the_line.emit()
	_emit_particles()
	
	if one_shot:
		used = true

func _collect_particle_systems() -> void:
	particle_systems.clear()
	_collect_particles_recursive(self)

func _collect_particles_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is GPUParticles3D or child is CPUParticles3D:
			particle_systems.append(child)
		# 递归收集子节点的子节点
		_collect_particles_recursive(child)

func _emit_particles() -> void:
	# 如果手动列表为空且开启了自动收集，先收集
	if particle_systems.is_empty() and auto_collect:
		_collect_particle_systems()
	
	for particle in particle_systems:
		if not is_instance_valid(particle):
			continue
		
		if particle is GPUParticles3D:
			var gpu_particles := particle as GPUParticles3D
			if restart_on_enter:
				gpu_particles.restart()
			else:
				gpu_particles.emitting = true
			
			if Engine.is_editor_hint():
				print("编辑器发射 GPUParticles3D: ", particle.name)
				
		elif particle is CPUParticles3D:
			var cpu_particles := particle as CPUParticles3D
			if restart_on_enter:
				cpu_particles.restart()
			else:
				cpu_particles.emitting = true
			
			if Engine.is_editor_hint():
				print("编辑器发射 CPUParticles3D: ", particle.name)

func _stop_particles() -> void:
	for particle in particle_systems:
		if not is_instance_valid(particle):
			continue
		
		if particle is GPUParticles3D or particle is CPUParticles3D:
			particle.emitting = false

# 可选：在编辑器中显示收集到的粒子数量作为警告提示
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	if auto_collect:
		var temp_systems: Array[Node] = []
		_find_particles_in_children(self, temp_systems)
		if temp_systems.is_empty():
			warnings.append("未找到子节点中的粒子系统（GPUParticles3D 或 CPUParticles3D）")
		else:
			warnings.append("已找到 %d 个粒子系统子节点" % temp_systems.size())
	elif particle_systems.is_empty():
		warnings.append("particle_systems 为空且 auto_collect 为 false，请手动指定粒子系统")
	
	return warnings

func _find_particles_in_children(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if child is GPUParticles3D or child is CPUParticles3D:
			result.append(child)
		_find_particles_in_children(child, result)
