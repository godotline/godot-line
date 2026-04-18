@tool
extends BaseTrigger
## MovingPosMaxTrigger - 序列位置移动触发器
## 当玩家进入时,让目标物体沿路径点序列移动
## 支持设置多个路径点、不同的移动时间和等待时间

@export_group("动画对象设置")
## 要移动的对象(如果不设置则移动自身)
@export var animated_object: Node3D
## 目标位置数组(路径点序列,以global_position表示)
@export var target_positions: Array[Vector3] = []
## 每段移动的时间(对应从起点到第一个终点、第一个到第二个等)
@export var move_durations: Array[float] = []
## 在每个路径点的等待时间
@export var wait_times: Array[float] = []
## 默认移动时间(当 move_durations 为空时使用)
@export var duration: float = 1.0
## 过渡类型
@export var transition_type: Tween.TransitionType = Tween.TransitionType.TRANS_LINEAR

## 自定义触发信号(保留向后兼容)
signal on_animation_start
signal on_animation_end
signal hit_the_line

# ---------- 工具按钮 ----------
@export_tool_button("抓取当前为起点") var set_start_action = func():
	var target = animated_object if animated_object else self
	print("当前起点(节点世界坐标): ", target.global_position)

@export_tool_button("抓取当前为终点") var set_end_action = func():
	var target = animated_object if animated_object else self
	target_positions.append(target.global_position)
	move_durations.append(duration)
	wait_times.append(0.0)
	print("终点已添加: ", target_positions[-1])

@export_tool_button("预览播放") var preview_play_action = func():
	if Engine.is_editor_hint():
		play_sequence()

# ---------- 核心逻辑 ----------

func _ready() -> void:
	# 调用父类的 _ready (处理网格隐藏和信号连接)
	super._ready()
	
	# 编辑器模式下跳过游戏逻辑
	if Engine.is_editor_hint():
		return
	
	# 连接自定义信号
	hit_the_line.connect(play_sequence)

func _on_triggered(_body: Node3D) -> void:
	# 发射自定义信号(供其他脚本监听)
	hit_the_line.emit()

func play_sequence() -> void:
	if target_positions.is_empty():
		push_warning("没有设置路径点!")
		return
	
	on_animation_start.emit()
	var target = animated_object if animated_object else self
	var original_pos = target.global_position
	
	var tween = create_tween()
	
	# 从初始位置出发,依次移动到每个路径点
	for i in range(target_positions.size()):
		var pos = target_positions[i]
		var move_time = duration
		if i < move_durations.size():
			move_time = move_durations[i]
		
		var wait_time = 0.0
		if i < wait_times.size():
			wait_time = wait_times[i]
		
		tween.tween_property(target, "global_position", pos, move_time).set_trans(transition_type)
		if wait_time > 0.0:
			tween.tween_interval(wait_time)
	
	tween.tween_callback(func():
		if Engine.is_editor_hint():
			target.global_position = original_pos
		on_animation_end.emit()
	)
	print("动画开始播放,路径点数: ", target_positions.size())

func play_():
	play_sequence()
