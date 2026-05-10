@tool
extends Node
## BeatmapReader — 从 .osu 谱面文件生成 GuidanceBox 序列
##
## 迁移自 Unity MonoBehaviour BeatmapReader.cs
## 原项目: Max/Assets/#Template/[Scripts]/Guideline/BeatmapReader.cs
##
## 用法:
##   1. 将此脚本挂到场景中的任意节点
##   2. 在 Inspector 中设置谱面文件路径
##   3. 勾选「执行生成」复选框
##   4. 生成完成后可删除该节点
##
## 生成物: GuidelineTapHolder-BeatmapCreated (Node3D)
##         内含 GuidanceBox 实例，沿谱面路径排列

## ========== 谱面输入 ==========

@export_file("*.osu") var beatmap_file: String = ""

## ========== 路线参数 ==========

@export_group("路线参数", "route_")
## 时间偏移 offset (秒)
@export var offset: float = 0.0

## ========== 场景引用 ==========

@export_group("场景引用", "scene_")
## GuidanceBox 预制体 (默认使用 Template 中的 GuidanceBox.tscn)
@export var guidance_box_scene: PackedScene = null

## ========== Player 覆盖 ==========
## 留空则自动从场景中查找 Player 节点

@export_group("Player 覆盖 (留空则自动查找)", "player_")
@export var player_override: NodePath = NodePath("")
## 覆盖线速 speed (0 = 从 Player/LevelData 读取)
@export var speed_override: float = 0.0
## 覆盖第一朝向 firstDirection (rotation_degrees, Y=0 表示全局 +Z 方向)
@export var first_direction_override: Vector3 = Vector3(0, 0, 0)
## 覆盖第二朝向 secondDirection (Y=90 表示全局 +X 方向)
@export var second_direction_override: Vector3 = Vector3(0, 90, 0)
## 覆盖起点位置 startPosition (0,0,0 表示从 Player 读取)
@export var start_position_override: Vector3 = Vector3.ZERO
## 使用覆盖值 (勾选后忽略场景中 Player 的设置)
@export var use_overrides: bool = false

## ========== 执行控制 ==========

@export_group("执行控制", "exec_")
## 勾选后立即执行生成 (完成后自动取消勾选)
@export var execute: bool = false:
	get:
		return false
	set(v):
		if v:
			_create_guideline_taps()


const DEFAULT_BOX_SCENE := "res://#Template/[Resources]/GuidanceBox.tscn"
const HIT_PARENT_NAME := "GuidelineTapHolder-BeatmapCreated"

## 本项目的局部前进方向 (Player 使用 +Z 作为 forward)
const LOCAL_FORWARD := Vector3(0, 0, 1)


func _create_guideline_taps() -> void:
	if not Engine.is_editor_hint():
		return

	# ReadBeatmap() — 解析谱面
	_read_beatmap()
	if hit_time.is_empty():
		printerr("[BeatmapReader] 谱面中没有找到 [HitObjects] 数据。")
		return

	# 获取场景与 Player 参数
	var scene_root := get_tree().edited_scene_root
	if not scene_root:
		printerr("[BeatmapReader] 没有打开的场景。")
		return

	var start_pos: Vector3
	var first_dir: Vector3
	var second_dir: Vector3
	var speed: float

	if use_overrides:
		start_pos = start_position_override if start_position_override != Vector3.ZERO else Vector3(0, 0, 0)
		first_dir = first_direction_override
		second_dir = second_direction_override
		speed = speed_override if speed_override > 0.0 else 12.0
	else:
		var player: Player = _find_player(scene_root)
		if player:
			start_pos = player.global_position
			first_dir = player.firstDirection
			second_dir = player.secondDirection
			speed = player.speed if player.speed > 0.0 else 12.0
		else:
			printerr("[BeatmapReader] 场景中未找到 Player 节点，请使用「Player 覆盖」手动设置。")
			return

	# 加载 GuidanceBox 预制体
	var box_prefab: PackedScene = guidance_box_scene
	if not box_prefab:
		if ResourceLoader.exists(DEFAULT_BOX_SCENE):
			box_prefab = load(DEFAULT_BOX_SCENE)
		else:
			printerr("[BeatmapReader] 找不到 GuidanceBox 场景: ", DEFAULT_BOX_SCENE)
			return

	# 创建容器 hitParent
	var hit_parent := Node3D.new()
	hit_parent.name = HIT_PARENT_NAME
	_add_owned_node(scene_root, hit_parent)

	var count := 1
	var boxes: Array[Node3D] = []

	# 第一个 box — pre-triggered, 放在 startPos - (0, 0.4, 0)
	# 对应 Unity: Quaternion.Euler(90, firstDir.y, 0)
	var first_box := _instantiate_box(box_prefab, hit_parent)
	first_box.position = start_pos - Vector3(0, 0.4, 0)
	first_box.rotation_degrees = Vector3(0, first_dir.y, 0)
	_set_triggered(first_box, true)
	boxes.append(first_box)

	# 生成后续 box
	for i in range(hit_time.size()):
		var focused_box := _instantiate_box(box_prefab, hit_parent)
		# focusedBox.transform.position = boxes[^1].transform.position
		focused_box.position = boxes[count - 1].position

		# focusedBox.transform.eulerAngles = (count % 2) switch { ... }
		var dir_y: float = first_dir.y if count % 2 == 1 else second_dir.y
		focused_box.rotation_degrees = Vector3(0, dir_y, 0)

		# Translate(...) Space.Self — 沿局部前进方向移动
		var delta_time: float
		if i == 0:
			delta_time = hit_time[i]
		else:
			delta_time = hit_time[i] - hit_time[i - 1]

		focused_box.translate(LOCAL_FORWARD * speed * delta_time)

		# box.triggerTime / box.displayTime — GuidanceBox 无此字段，跳过
		# (原始行为: box.triggerTime = hitTime[i];
		#            box.displayTime = hitTime[i] - 2.5f < 0f ? 0f : hitTime[i] - 2.5f)

		boxes.append(focused_box)
		count += 1

	# 第二遍修正所有 box 的朝向
	# boxes[i].transform.eulerAngles = ((i + 1) % 2) switch { ... }
	for i in range(boxes.size()):
		var dir_y: float = first_dir.y if (i + 1) % 2 == 1 else second_dir.y
		boxes[i].rotation_degrees = Vector3(0, dir_y, 0)

	print("[BeatmapReader] 生成完成: %d 个 GuidanceBox (含起始预触发)" % boxes.size())


# ============================================================
# ReadBeatmap() — 解析 .osu 谱面
# ============================================================

var hit1: Array[String] = []
var hit2: Array[PackedStringArray] = []
var hit_time: Array[float] = []

func _read_beatmap() -> void:
	hit1.clear()
	hit2.clear()
	hit_time.clear()

	if beatmap_file.is_empty():
		printerr("[BeatmapReader] 未选择谱面数据文件。")
		return

	var file := FileAccess.open(beatmap_file, FileAccess.READ)
	if file == null:
		printerr("[BeatmapReader] 无法打开文件: ", beatmap_file)
		return

	# hit1 = beatmap.text.Split('\n') → Trim
	for line in file.get_as_text().split("\n"):
		hit1.append(line.strip_edges())
	file.close()

	# var index = hit1.IndexOf("[HitObjects]")
	# hit1.RemoveRange(0, index + 1)
	# hit1.RemoveAll(text => text == string.Empty)
	var index := hit1.find("[HitObjects]")
	if index == -1:
		printerr("[BeatmapReader] 谱面中未找到 [HitObjects] 段。")
		return
	hit1 = hit1.slice(index + 1)
	hit1 = hit1.filter(func(t): return not t.is_empty())

	# hit2 = hit1 → Split(',')
	for line_text in hit1:
		hit2.append(line_text.split(",", false))

	# hitTime = hit2 → int.Parse(VARIABLE[2]) / 1000f + offset
	for parts in hit2:
		if parts.size() < 3:
			continue
		var t := parts[2].to_float() / 1000.0 + offset
		hit_time.append(t)


# ============================================================
# 辅助方法
# ============================================================

## 在场景树中递归查找 Player 节点
func _find_player(root: Node) -> Player:
	if root is Player:
		return root
	for child in root.get_children():
		var found := _find_player(child)
		if found:
			return found
	return null


## 实例化 GuidanceBox 并添加到容器
func _instantiate_box(scene: PackedScene, parent_node: Node3D) -> Node3D:
	var box := scene.instantiate() as Node3D
	_add_owned_node(parent_node, box)
	box.name = "%s_%d" % [box.name, parent_node.get_child_count()]
	return box


## 将 GuidanceBox 设为预触发状态
## GuidanceBox 脚本附在 Area3D 子节点上，用 duck typing 访问
func _set_triggered(node: Node3D, triggered: bool) -> void:
	var area := node.get_node_or_null("Area3D")
	if not area:
		return
	# 等效于: firstBox.GetComponent<GuidelineTap>().triggered = true
	area.can_be_triggered = not triggered
	area._triggered = triggered
	if triggered:
		area._displayed = true
		area._trigger_ready = true


## 添加节点并设置 owner (确保随场景保存)
func _add_owned_node(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = get_tree().edited_scene_root
