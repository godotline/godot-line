@tool
extends Node
## NoteReader — 从 .osu 谱面文件生成路面和自动触发器
##
## 迁移自 Unity EditorWindow NoteReader.cs
## 原项目: MTPIDM001-Introduction/Assets/Editor/DLFM/NoteReader.cs
## 插件脚本: addons/template/NoteReader.gd
##
## 用法:
##   1. 将此脚本挂到场景中的任意节点（或新建一个空节点）
##   2. 在 Inspector 中设置参数（场景字段可直接拖拽 .tscn）
##   3. 点击「执行生成」按钮
##   4. 生成完成后可删除该节点

## ========== 谱面文件 ==========

@export_file("*.osu") var file: String = ""

## ========== Make Road ==========

@export_group("Make Road")
## 是否生成路面
@export var makeRoad: bool = false
## 路面宽度
@export var roadWidth: float = 1.0
## 路面场景 (默认 Ground.tscn)
@export var road: PackedScene
@export_group("")

## ========== Auto Play ==========

@export_group("Auto Play")
## 是否生成自动触发器
@export var autoPlay: bool = false
## 触发器场景 (默认 GuidanceBox.tscn)
@export var autoPlayTrigger: PackedScene
@export_group("")

## ========== 路线配置 ==========

@export_group("路线配置")
## 线速 (单位/秒)
@export var speed: float = 10.0
## 第一朝向 (世界空间方向向量)
@export var forward1: Vector3 = Vector3(1, 0, 0)
## 第二朝向 (世界空间方向向量)
@export var forward2: Vector3 = Vector3(0, 0, 1)

## ========== 执行控制 ==========

@export_group("执行控制")
## 点击按钮立即执行生成
@export_tool_button("执行生成", "Play")
var execute: Callable = _run


func _run() -> void:
	if not Engine.is_editor_hint():
		return

	if file.is_empty():
		printerr("[NoteReader] 未选择谱面文件。请在 Inspector 中设置 file。")
		return

	# 解析谱面
	var hitTimes: Array[float] = []
	var parseOk: bool = _parse_beatmap(hitTimes)
	if not parseOk:
		return

	if hitTimes.is_empty():
		printerr("[NoteReader] 谱面中没有找到 [HitObjects] 数据。")
		return

	# 获取当前编辑的场景根节点
	var sceneRoot: Node = _get_edited_scene_root()
	if not sceneRoot:
		printerr("[NoteReader] 没有打开的场景。请先打开目标场景。")
		return

	# 创建容器节点
	var roadPar: Node3D = null
	var autoPlayPar: Node3D = null

	if makeRoad:
		roadPar = Node3D.new()
		roadPar.name = "Road"
		_add_owned_node(sceneRoot, roadPar)

	if autoPlay:
		autoPlayPar = Node3D.new()
		autoPlayPar.name = "Auto Play Triggers"
		_add_owned_node(sceneRoot, autoPlayPar)

	# 沿谱面生成对象 (匹配原始行为: lastTime 初始为 0, 遍历全部 HitObjects)
	var lastPostion: Vector3 = Vector3(2, 0, 0)
	var lastTime: float = 0.0
	var thisForward: Vector3 = forward1
	var roadCount: int = 0
	var triggerCount: int = 0

	for hitTime in hitTimes:
		# 跳过与上一拍完全相同的时间 (原始行为)
		if is_equal_approx(hitTime, lastTime):
			continue

		var deltaTime: float = (hitTime - lastTime) / 1000.0
		var thisPostion: Vector3 = lastPostion + thisForward * speed * deltaTime

		# 路面生成 — 放置在相邻两点的中点
		if makeRoad:
			var midpoint: Vector3 = (lastPostion + thisPostion) / 2.0
			if road:
				var roadCr: Node = road.instantiate()
				if roadCr is Node3D:
					roadCr.position = midpoint
					roadCr.scale = Vector3(
						absf(lastPostion.x - thisPostion.x) + roadWidth,
						1.0,
						absf(lastPostion.z - thisPostion.z) + roadWidth
					)
					_add_owned_node(roadPar, roadCr)
					roadCount += 1
			else:
				_create_default_road(roadPar, midpoint, lastPostion, thisPostion)
				roadCount += 1

		# 自动触发器 — 放置在每一个命中位置
		if autoPlay:
			if autoPlayTrigger:
				var Tri: Node = autoPlayTrigger.instantiate()
				if Tri is Node3D:
					Tri.position = thisPostion
					_add_owned_node(autoPlayPar, Tri)
					triggerCount += 1
			else:
				_create_default_trigger(autoPlayPar, thisPostion)
				triggerCount += 1

		# 方向交替 (原始行为)
		thisForward = forward2 if thisForward == forward1 else forward1

		lastTime = hitTime
		lastPostion = thisPostion

	# 路面下沉至 y=-1 (原始行为)
	if roadPar and makeRoad:
		roadPar.position.y = -1.0

	# 输出结果
	print("[NoteReader] 生成完成:")
	print("  - 路面 (Road): %d 段" % roadCount if makeRoad else "  - 路面: 已禁用")
	print("  - 自动触发器 (Auto Play Triggers): %d 个" % triggerCount if autoPlay else "  - 自动触发器: 已禁用")

	# 彩蛋 (原始彩蛋的移植)
	if randi() % 10 == 0:
		print("[NoteReader] 感谢使用，来支持下子智君呗 https://space.bilibili.com/426181974")


## 解析 .osu 谱面文件的 [HitObjects] 段
func _parse_beatmap(outTimes: Array[float]) -> bool:
	var stream: FileAccess = FileAccess.open(file, FileAccess.READ)
	if stream == null:
		printerr("[NoteReader] 无法打开文件: ", file)
		return false

	var content: String = stream.get_as_text()
	stream.close()

	var reading: bool = false
	for line in content.split("\n"):
		var trimmed: String = line.strip_edges()

		if trimmed == "[HitObjects]":
			reading = true
			continue
		if not reading:
			continue
		if trimmed.is_empty():
			continue

		# .osu HitObject 格式: x,y,time,type,...
		var array: PackedStringArray = trimmed.split(",", false)
		if array.size() < 3:
			continue

		outTimes.append(array[2].to_float())

	return true


## 创建默认路面 (BoxMesh)
func _create_default_road(holder: Node3D, midpoint: Vector3, a: Vector3, b: Vector3) -> void:
	var roadPiece: MeshInstance3D = MeshInstance3D.new()
	roadPiece.name = "RoadSegment"
	roadPiece.mesh = BoxMesh.new()
	roadPiece.position = midpoint

	var dx: float = absf(a.x - b.x)
	var dz: float = absf(a.z - b.z)
	roadPiece.scale = Vector3(dx + roadWidth, 1.0, dz + roadWidth)

	_add_owned_node(holder, roadPiece)


## 创建默认自动触发器 (Area3D + BoxShape3D)
func _create_default_trigger(holder: Node3D, pos: Vector3) -> void:
	var triggerArea: Area3D = Area3D.new()
	triggerArea.name = "AutoTrigger"
	triggerArea.position = pos

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = BoxShape3D.new()
	triggerArea.add_child(collision)
	collision.owner = _get_edited_scene_root()

	_add_owned_node(holder, triggerArea)


## 将节点添加到场景并设置 owner (确保随场景一起保存)
func _add_owned_node(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = _get_edited_scene_root()
## 在插件临时实例和场景脚本实例两种调用方式下取得当前编辑场景根节点。
func _get_edited_scene_root() -> Node:
	var tree: SceneTree = get_tree()
	if tree and tree.edited_scene_root:
		return tree.edited_scene_root
	return EditorInterface.get_edited_scene_root()
