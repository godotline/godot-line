@tool
extends Node3D
class_name StressTestGenerator

## 压力测试场景生成器
## 用法：添加到场景，设置参数，勾选 execute 生成，完成后删除此节点

@export_group("生成设置")
@export var execute: bool:
	set(value):
		if Engine.is_editor_hint() and value:
			_generate()
	get:
		return false

@export_group("规模")
@export var turn_count: int = 50         ## 转向次数（每个转向=一段路+一个GuidanceBox）
@export var gems_per_segment: int = 2    ## 每段路上的宝石数量
@export var obstacles_per_segment: int = 3  ## 每段路上的障碍物数量
@export var triggers_per_segment: int = 1   ## 每段路上的触发器数量
@export var crowns_interval: int = 10       ## 每隔多少段路放一个Crown
@export var heart_checkpoints_interval: int = 5  ## 每隔多少段路放一个HeartCheckpoint

@export_group("路径")
@export var segment_length: float = 12.0   ## 每段路长度
@export var road_width: float = 3.0         ## 路面宽度
@export var first_direction := Vector3(0, 0, 0)
@export var second_direction := Vector3(0, 90, 0)

var _ground_scene: PackedScene
var _trigger_scene: PackedScene
var _crown_scene: PackedScene
var _heart_checkpoint_scene: PackedScene
var _gem_scene: PackedScene
var _guidance_box_scene: PackedScene
var _obstacle_scene: PackedScene

func _generate() -> void:
	print("[StressTest] 开始生成压力测试场景...")
	print("[StressTest] 转向数: %d, 每段宝石: %d, 每段障碍: %d" % [turn_count, gems_per_segment, obstacles_per_segment])

	# 加载场景
	_ground_scene = load("res://#Template/Ground.tscn")
	_trigger_scene = load("res://#Template/Trigger.tscn")
	_crown_scene = load("res://#Template/CrownCheckPoint.tscn")
	_heart_checkpoint_scene = load("res://#Template/HeartCheckPoint.tscn")
	_gem_scene = load("res://#Template/Gem.tscn")
	_guidance_box_scene = load("res://#Template/[Resources]/GuidanceBox.tscn")
	_obstacle_scene = load("res://#Template/Obstacle.tscn")

	if not _ground_scene or not _trigger_scene or not _crown_scene or not _heart_checkpoint_scene or not _gem_scene or not _guidance_box_scene or not _obstacle_scene:
		push_error("[StressTest] 无法加载所需的场景文件！")
		return

	var root := get_tree().edited_scene_root
	if not root:
		push_error("[StressTest] 没有打开的场景！")
		return

	var scene_group := root.get_node_or_null("Scene_Group")
	if not scene_group:
		scene_group = root.find_child("Scene_Group", false, false)
	if not scene_group:
		push_error("[StressTest] 场景中没有 Scene_Group 节点！")
		return

	var guidance_holder := root.get_node_or_null("GuidanceBoxHolder")
	if not guidance_holder:
		guidance_holder = root.find_child("GuidanceBoxHolder", false, false)
	if not guidance_holder:
		push_error("[StressTest] 场景中没有 GuidanceBoxHolder 节点！")
		return

	# 生成路径
	var current_pos := Vector3.ZERO
	var current_dir_index := 0  # 0 = first, 1 = second
	var directions := [first_direction, second_direction]

	# 起始大地面
	_create_big_ground(scene_group, Vector3.ZERO, 500.0)

	var total_grounds := 0
	var total_triggers := 0
	var total_crowns := 0
	var total_gems := 0
	var total_obstacles := 0
	var total_guidance_boxes := 0
	var total_heart_checkpoints := 0

	for i in turn_count:
		var dir_y: float = directions[current_dir_index].y
		var forward := Vector3.FORWARD if dir_y < 45 else Vector3.RIGHT

		# 计算下一个转向位置
		var next_pos := current_pos + forward * segment_length

		# 段路面
		var midpoint := (current_pos + next_pos) / 2.0
		var ground := _ground_scene.instantiate() as Node3D
		ground.position = midpoint
		var offset := (next_pos - current_pos).abs()
		ground.scale = offset + Vector3(road_width, 1, road_width)
		scene_group.add_child(ground)
		ground.owner = root
		total_grounds += 1

		# GuidanceBox
		var gb := _guidance_box_scene.instantiate() as Node3D
		gb.position = Vector3(next_pos.x, -0.45, next_pos.z)
		gb.rotation_degrees = Vector3(0, directions[1 - current_dir_index].y, 0)
		guidance_holder.add_child(gb)
		gb.owner = root
		total_guidance_boxes += 1

		# Gems
		for g in gems_per_segment:
			var t := (g + 1.0) / (gems_per_segment + 1.0)
			var gem_pos := current_pos.lerp(next_pos, t) + Vector3(0, 0.5, 0)
			# 在路侧面偏移
			var side_offset := Vector3.UP.cross(forward).normalized() * (road_width * 0.3 * (1 if g % 2 == 0 else -1))
			var gem := _gem_scene.instantiate() as Node3D
			gem.global_position = gem_pos + side_offset
			scene_group.add_child(gem)
			gem.owner = root
			total_gems += 1

		# Obstacles（墙壁，在路侧面）
		for o in obstacles_per_segment:
			var t := (o + 1.0) / (obstacles_per_segment + 1.0)
			var obs_pos := current_pos.lerp(next_pos, t) + Vector3(0, 1, 0)
			var side_offset := Vector3.UP.cross(forward).normalized() * (road_width * 0.8 * (1 if o % 2 == 0 else -1))
			var obs := _obstacle_scene.instantiate() as Node3D
			obs.global_position = obs_pos + side_offset
			scene_group.add_child(obs)
			obs.owner = root
			total_obstacles += 1

		# Triggers
		for tr in triggers_per_segment:
			var t := (tr + 1.0) / (triggers_per_segment + 1.0)
			var trig_pos := current_pos.lerp(next_pos, t) + Vector3(0, 0, 0)
			var trigger := _trigger_scene.instantiate() as Node3D
			trigger.global_position = trig_pos
			scene_group.add_child(trigger)
			trigger.owner = root
			total_triggers += 1

		# Crown
		if (i + 1) % crowns_interval == 0:
			var crown := _crown_scene.instantiate() as Node3D
			crown.global_position = next_pos + Vector3(0, 0, 0)
			scene_group.add_child(crown)
			crown.owner = root
			total_crowns += 1

		# HeartCheckpoint
		if (i + 1) % heart_checkpoints_interval == 0 and (i + 1) % crowns_interval != 0:
			var heart := _heart_checkpoint_scene.instantiate() as Node3D
			heart.global_position = next_pos + Vector3(2, 0, 0)
			scene_group.add_child(heart)
			heart.owner = root
			total_heart_checkpoints += 1

		current_pos = next_pos
		current_dir_index = 1 - current_dir_index

	# 末尾大地面
	_create_big_ground(scene_group, current_pos + Vector3(0, -1, segment_length), 100.0)
	total_grounds += 1

	# 设置动画长度（按路程估算）
	var anim_player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player:
		var est_time := float(turn_count) * segment_length / 12.0 * 1.5  # 速度12，估算
		print("[StressTest] 建议设置动画长度为 %.1f 秒" % est_time)

	print("[StressTest] ===== 生成完成 =====")
	print("[StressTest] 路面: %d" % total_grounds)
	print("[StressTest] 触发器: %d" % total_triggers)
	print("[StressTest] 皇冠: %d" % total_crowns)
	print("[StressTest] 宝石: %d" % total_gems)
	print("[StressTest] 障碍物: %d" % total_obstacles)
	print("[StressTest] 引导盒: %d" % total_guidance_boxes)
	print("[StressTest] 心跳检查点: %d" % total_heart_checkpoints)
	print("[StressTest] 总节点数(估): %d" % (total_grounds + total_triggers + total_crowns + total_gems + total_obstacles + total_guidance_boxes + total_heart_checkpoints))

func _create_big_ground(parent: Node3D, pos: Vector3, size: float) -> void:
	var ground := _ground_scene.instantiate() as Node3D
	ground.position = pos
	ground.scale = Vector3(size, 1, size)
	parent.add_child(ground)
	ground.owner = get_tree().edited_scene_root
