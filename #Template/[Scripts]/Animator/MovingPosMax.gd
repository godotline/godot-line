@tool
extends BaseTrigger
## MovingPosMaxTrigger - 序列位置移动触发器
## 当玩家进入时,让目标物体沿路径点序列移动
## 支持设置多个路径点、不同的移动时间和等待时间

@export_group("动画对象设置")
## 要移动的对象(如果不设置则移动自身)
@export var animated_object: Node3D
## 目标位置数组(第一个元素为起点)
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
	if target_positions.is_empty():
		target_positions.append(Vector3.ZERO)
	var target = animated_object if animated_object else self
	target_positions[0] = target.position
	print("起点已设置: ", target_positions[0])

@export_tool_button("抓取当前为终点") var set_end_action = func():
	var target = animated_object if animated_object else self
	target_positions.append(target.position)
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
	
	var target = animated_object if animated_object else self
	
	# 初始化到起点
	if !target_positions.is_empty():
		target.position = target_positions[0]
	
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
	
	# 确保从起点开始
	target.position = target_positions[0]
	
	var tween = create_tween()
	
	# 单点情况:从当前位置移动到该点(或等待)
	if target_positions.size() == 1:
		# 如果已经在该位置,做个微小移动或只是等待
		tween.tween_property(target, "position", target_positions[0], duration).set_trans(transition_type)
	else:
		# 多点序列:从索引1开始(0是起点)
		for i in range(1, target_positions.size()):
			var pos = target_positions[i]
			# 注意:move_durations 应该对应第 i 段移动,所以用 i-1 或当前的 i
			# 取决于你的数据结构设计,这里假设 move_durations[0] 对应 0->1 的移动
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
	print("动画开始播放,路径点数: ", target_positions.size())

func play_():
	play_sequence()
