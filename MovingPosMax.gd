@tool extends Area3D

@export var animated_object: Node3D
@export var target_positions: Array[Vector3] = []
@export var move_durations: Array[float] = []
@export var wait_times: Array[float] = []
@export var duration: float = 1.0
@export var transition_type: Tween.TransitionType = Tween.TransitionType.TRANS_LINEAR

# 新增：是否只触发一次
@export var one_shot: bool = false
var triggered: bool = false

signal on_animation_start
signal on_animation_end
signal hit_the_line  # 自定义触发信号

# ---------- 工具按钮 ----------
@export_tool_button("抓取当前为起点") var set_start_action = func():
	if target_positions.is_empty():
		target_positions.append(Vector3.ZERO)
	target_positions[0] = animated_object.position if animated_object else self.position
	print("起点已设置: ", target_positions[0])

@export_tool_button("抓取当前为终点") var set_end_action = func():
	target_positions.append(animated_object.position if animated_object else self.position)
	move_durations.append(duration)
	wait_times.append(0.0)
	print("终点已添加: ", target_positions[-1])

@export_tool_button("预览播放") var preview_play_action = func():
	if Engine.is_editor_hint():
		play_sequence()

# ---------- 核心逻辑 ----------
func _ready() -> void:
	$MeshInstance3D.visible = false
	var target = animated_object if animated_object else self
	
	# 初始化到起点
	if !target_positions.is_empty():
		target.position = target_positions[0]
	
	# 连接自定义信号
	hit_the_line.connect(play_sequence)

func _on_body_entered(body: Node3D) -> void:
	# 检查是否是玩家/角色（根据你的需求调整）
	if body is CharacterBody3D or body.is_in_group("player"):
		print("触发物体: ", body.name)
		
		# 发射自定义信号（如果你其他脚本需要监听）
		emit_signal("hit_the_line")
		
		# 或者直接播放（如果不需信号中转）
		# play_sequence()
		
		# 一次性触发逻辑
		if one_shot and triggered:
			return
		triggered = true

func play_sequence() -> void:
	if target_positions.is_empty():
		push_warning("没有设置路径点！")
		return
	
	# 如果正在播放，先停止（可选）
	# if tween and tween.is_running(): tween.kill()
	
	on_animation_start.emit()
	var target = animated_object if animated_object else self
	
	# 确保从起点开始
	target.position = target_positions[0]
	
	var tween = create_tween()
	
	# 单点情况：从当前位置移动到该点（或等待）
	if target_positions.size() == 1:
		# 如果已经在该位置，做个微小移动或只是等待
		tween.tween_property(target, "position", target_positions[0], duration).set_trans(transition_type)
	else:
		# 多点序列：从索引1开始（0是起点）
		for i in range(1, target_positions.size()):
			var pos = target_positions[i]
			# 注意：move_durations 应该对应第 i 段移动，所以用 i-1 或当前的 i
			# 取决于你的数据结构设计，这里假设 move_durations[0] 对应 0->1 的移动
			var move_time = duration
			if i - 1 < move_durations.size():
				move_time = move_durations[i - 1]
			
			var wait_time = 0.0
			if i - 1 < wait_times.size():
				wait_time = wait_times[i - 1]
			
			tween.tween_property(target, "position", pos, move_time).set_trans(transition_type)
			if wait_time > 0.0:
				tween.tween_interval(wait_time)
	
	tween.tween_callback(func(): on_animation_end.emit())
	print("动画开始播放，路径点数: ", target_positions.size())

func play_():
	play_sequence()
