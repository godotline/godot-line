@tool
extends Node
## NoteReader — 从 .osu 谱面文件生成路面和自动触发器
##
## 迁移自 Unity EditorWindow NoteReader.cs
## 原项目: MTPIDM001-Introduction/Assets/Editor/DLFM/NoteReader.cs
##
## 用法:
##   1. 将此脚本挂到场景中的任意节点（或新建一个空节点）
##   2. 在 Inspector 中设置参数
##   3. 勾选「执行生成」复选框
##   4. 生成完成后可删除该节点

## ========== 谱面文件 ==========

@export_file("*.osu") var beatmap_file: String = ""

## ========== 路线配置 ==========

@export_group("路线配置", "route_")
## 线速 (单位/秒)
@export var speed: float = 10.0
## 第一朝向 (世界空间方向向量)
@export var forward1: Vector3 = Vector3(1, 0, 0)
## 第二朝向 (世界空间方向向量)
@export var forward2: Vector3 = Vector3(0, 0, 1)
## 起点位置
@export var start_position: Vector3 = Vector3(2, 0, 0)

## ========== 路面生成 ==========

@export_group("路面生成", "road_")
## 是否生成路面
@export var make_road: bool = true
## 路面宽度
@export var road_width: float = 1.0
## 自定义路面场景 (可选，为空则使用默认长方体)
@export var road_scene: PackedScene = null
## 路面颜色
@export var road_color: Color = Color(0.3, 0.3, 0.35, 1.0)

## ========== 自动播放触发器 ==========

@export_group("自动播放触发器", "auto_")
## 是否生成自动触发器
@export var auto_play: bool = false
## 自定义触发器场景 (可选，为空则使用默认 Area3D)
@export var auto_play_scene: PackedScene = null
## 触发器尺寸
@export var trigger_size: Vector3 = Vector3(2.5, 2.5, 2.5)

## ========== 执行控制 ==========

@export_group("执行控制", "exec_")
## 勾选后立即执行生成 (完成后自动取消勾选)
@export var execute: bool = false:
	get:
		return false  # 始终返回 false，只做触发器用
	set(v):
		if v:
			_run()


func _run() -> void:
	if not Engine.is_editor_hint():
		return

	if beatmap_file.is_empty():
		printerr("[NoteReader] 未选择谱面文件。请在 Inspector 中设置 beatmap_file。")
		return

	# 解析谱面
	var hit_times: Array[float] = []
	var parse_ok := _parse_beatmap(hit_times)
	if not parse_ok:
		return

	if hit_times.is_empty():
		printerr("[NoteReader] 谱面中没有找到 [HitObjects] 数据。")
		return

	# 获取当前编辑的场景根节点
	var scene_root := get_tree().edited_scene_root
	if not scene_root:
		printerr("[NoteReader] 没有打开的场景。请先打开目标场景。")
		return

	# 创建容器节点
	var road_holder: Node3D = null
	var trigger_holder: Node3D = null

	if make_road:
		road_holder = Node3D.new()
		road_holder.name = "Road"
		_add_owned_node(scene_root, road_holder)

	if auto_play:
		trigger_holder = Node3D.new()
		trigger_holder.name = "AutoPlayTriggers"
		_add_owned_node(scene_root, trigger_holder)

	# 沿谱面生成对象 (匹配原始行为: lastTime 初始为 0, 遍历全部 HitObjects)
	var last_position := start_position
	var last_time: float = 0.0
	var current_forward := forward1
	var road_count := 0
	var trigger_count := 0

	for hit_time in hit_times:
		# 跳过与上一拍完全相同的时间 (原始行为)
		if is_equal_approx(hit_time, last_time):
			continue

		var delta_time := (hit_time - last_time) / 1000.0
		var this_position := last_position + current_forward * speed * delta_time

		# 路面生成 — 放置在相邻两点的中点
		if make_road:
			var midpoint := (last_position + this_position) / 2.0
			if road_scene:
				var road_piece := road_scene.instantiate()
				if road_piece is Node3D:
					road_piece.position = midpoint
					_add_owned_node(road_holder, road_piece)
					road_count += 1
			else:
				_create_default_road(road_holder, midpoint, last_position, this_position)
				road_count += 1

		# 自动触发器 — 放置在每一个命中位置
		if auto_play:
			if auto_play_scene:
				var trigger_instance := auto_play_scene.instantiate()
				if trigger_instance is Node3D:
					trigger_instance.position = this_position
					_add_owned_node(trigger_holder, trigger_instance)
					trigger_count += 1
			else:
				_create_default_trigger(trigger_holder, this_position)
				trigger_count += 1

		# 方向交替 (原始行为)
		current_forward = forward2 if current_forward == forward1 else forward1

		last_time = hit_time
		last_position = this_position

	# 路面下沉至 y=-1 (原始行为)
	if road_holder and make_road:
		road_holder.position.y = -1.0

	# 输出结果
	print("[NoteReader] 生成完成:")
	print("  - 路面 (Road): %d 段" % road_count if make_road else "  - 路面: 已禁用")
	print("  - 自动触发器 (AutoPlayTriggers): %d 个" % trigger_count if auto_play else "  - 自动触发器: 已禁用")

	# 彩蛋 (原始彩蛋的移植)
	if randi() % 10 == 0:
		print("[NoteReader] 感谢使用，来支持下子智君呗 https://space.bilibili.com/426181974")


## 解析 .osu 谱面文件的 [HitObjects] 段
func _parse_beatmap(out_times: Array[float]) -> bool:
	var file := FileAccess.open(beatmap_file, FileAccess.READ)
	if file == null:
		printerr("[NoteReader] 无法打开文件: ", beatmap_file)
		return false

	var content := file.get_as_text()
	file.close()

	var reading := false
	for line in content.split("\n"):
		var trimmed := line.strip_edges()

		if trimmed == "[HitObjects]":
			reading = true
			continue
		if not reading:
			continue
		if trimmed.is_empty():
			continue

		# .osu HitObject 格式: x,y,time,type,...
		var parts := trimmed.split(",", false)
		if parts.size() < 3:
			continue

		out_times.append(parts[2].to_float())

	return true


## 创建默认路面 (BoxMesh)
func _create_default_road(holder: Node3D, midpoint: Vector3, a: Vector3, b: Vector3) -> void:
	var road := MeshInstance3D.new()
	road.name = "RoadSegment"
	road.mesh = BoxMesh.new()
	road.position = midpoint

	var dx := absf(a.x - b.x)
	var dz := absf(a.z - b.z)
	road.scale = Vector3(dx + road_width, 1.0, dz + road_width)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = road_color
	road.set_surface_override_material(0, mat)

	_add_owned_node(holder, road)


## 创建默认自动触发器 (Area3D + BoxShape3D)
func _create_default_trigger(holder: Node3D, pos: Vector3) -> void:
	var trigger := Area3D.new()
	trigger.name = "AutoTrigger"
	trigger.position = pos

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = trigger_size
	collision.shape = box_shape
	trigger.add_child(collision)
	collision.owner = get_tree().edited_scene_root

	_add_owned_node(holder, trigger)


## 将节点添加到场景并设置 owner (确保随场景一起保存)
func _add_owned_node(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = get_tree().edited_scene_root
