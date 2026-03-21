@tool class_name BeatmapReader extends Node3D

@export var player: Node3D
@export var beatmap_path: String = ""
@export var offset: float = 0.0
@export var hit_time: Array[float] = []
@export var box_prefab: PackedScene

@export var _create_guideline_taps: bool = false : set = _on_create_taps
@export var _reload_hit_time: bool = false : set = _on_reload

func _on_create_taps(value: bool) -> void:
	if not value: return
	_create_guideline_taps = false
	create_guideline_taps()

func _on_reload(value: bool) -> void:
	if not value: return
	_reload_hit_time = false
	read_beatmap()

func read_beatmap() -> void:
	hit_time.clear()
	
	if beatmap_path.is_empty():
		push_error("未设置谱面文件路径")
		return
		
	if not FileAccess.file_exists(beatmap_path):
		push_error("谱面文件不存在: " + beatmap_path)
		return
		
	var file := FileAccess.open(beatmap_path, FileAccess.READ)
	if file == null:
		push_error("无法打开文件")
		return
		
	var text := file.get_as_text()
	file.close()
	
	# 处理不同系统的换行符，并分割成行
	var lines := text.split("\n")
	
	var idx := -1
	# 查找 [HitObjects]，同时去除 \r 和首尾空格
	for i in range(lines.size()):
		var line := lines[i].replace("\r", "").strip_edges()
		if line == "[HitObjects]":
			idx = i
			break
	
	if idx == -1:
		push_error("谱面格式错误：未找到[HitObjects]，请确认文件格式正确")
		# 调试：打印文件前20行内容，帮助你检查
		push_warning("文件前20行内容预览：")
		for i in range(min(20, lines.size())):
			push_warning("行 " + str(i) + ": [" + lines[i] + "]")
		return
		
	for i in range(idx + 1, lines.size()):
		var line := lines[i].replace("\r", "").strip_edges()
		if line.is_empty():
			continue
			
		var parts := line.split(",")
		if parts.size() > 2:
			hit_time.append(int(parts[2]) / 1000.0 + offset)

func create_guideline_taps() -> void:
	read_beatmap()
	if hit_time.is_empty():
		push_warning("未读取到打击时间")
		return
	if box_prefab == null:
		push_error("未设置预制体")
		return
	if player == null:
		push_error("未设置Player")
		return
	
	# 从 Player 获取参数
	var spd: float = player.speed
	var rot_deg: float = player.rot
	var is_turn_state: bool = player.is_turn
	
	# 使用 Player 当前的 Transform 作为起点
	var current_transform: Transform3D = player.global_transform
	var current_pos: Vector3 = current_transform.origin
	var current_basis: Basis = current_transform.basis
	# Player 沿本地 -Z 移动（见 turn() 中的 to_global(Vector3(0,0,-1))）
	var forward: Vector3 = -current_basis.z.normalized()
	
	var hit_parent := Node3D.new()
	hit_parent.name = "GuidelineTapHolder-BeatmapCreated"
	add_child(hit_parent)
	if Engine.is_editor_hint():
		hit_parent.owner = get_tree().edited_scene_root
	
	for i in range(hit_time.size()):
		# 计算与上一段的时间差
		var delta_t: float = hit_time[i] - (hit_time[i-1] if i > 0 else 0.0)
		var move_dist := delta_t * spd
		
		# 沿当前 forward 方向移动到 hit 点
		current_pos += forward * move_dist
		
		# 创建盒子
		var box := box_prefab.instantiate() as Node3D
		box.position = current_pos
		
		# 设置朝向：让盒子的 -Z 指向 forward（与 Player 移动方向一致）
		# 这样盒子会"面向"行进方向
		box.basis = Basis.looking_at(forward, Vector3.UP)
		
		hit_parent.add_child(box)
		if Engine.is_editor_hint():
			box.owner = get_tree().edited_scene_root
		
		# 模拟 Player.turn() 的旋转逻辑
		# Player: rotation_degrees += Vector3(0,1,0) * rot if is_turn else Vector3.DOWN * rot
		# Vector3.DOWN * rot = (0, -1, 0) * (-90) = (0, 90, 0)  -> 左转 90°
		# Vector3.UP * rot = (0, 1, 0) * (-90) = (0, -90, 0) -> 右转 90°
		var turn_angle: float = rot_deg if is_turn_state else -rot_deg
		
		# 应用旋转（绕 Y 轴）
		current_basis = current_basis.rotated(Vector3.UP, deg_to_rad(turn_angle))
		forward = -current_basis.z.normalized()
		
		# 切换 turn 状态
		is_turn_state = not is_turn_state
	
	print("成功创建 ", hit_time.size(), " 个指引点")
