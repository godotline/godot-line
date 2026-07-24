@tool
extends Node3D
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

@export_tool_button("抓取路径点") var set_end_action: Callable = func() -> void:
	_grab_waypoint()

@export_tool_button("预览播放") var preview_play_action: Callable = func() -> void:
	if Engine.is_editor_hint():
		play_sequence()

func _grab_waypoint() -> void:
	var target: Node3D = animated_object if animated_object else self
	var new_pos: Vector3 = target.global_position
	var old_positions: Array[Vector3] = target_positions.duplicate()
	var old_durations: Array[float] = move_durations.duplicate()
	var old_waits: Array[float] = wait_times.duplicate()
	var new_positions: Array[Vector3] = old_positions.duplicate()
	var new_durations: Array[float] = old_durations.duplicate()
	var new_waits: Array[float] = old_waits.duplicate()

	new_positions.append(new_pos)
	new_durations.append(duration)
	new_waits.append(0.0)

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("抓取路径点")
	undo_redo.add_do_property(self, "target_positions", new_positions)
	undo_redo.add_do_property(self, "move_durations", new_durations)
	undo_redo.add_do_property(self, "wait_times", new_waits)
	undo_redo.add_undo_property(self, "target_positions", old_positions)
	undo_redo.add_undo_property(self, "move_durations", old_durations)
	undo_redo.add_undo_property(self, "wait_times", old_waits)
	undo_redo.commit_action()

	print("目标位置: ", new_pos)
	print("当前路径点数组: ", target_positions)
	notify_property_list_changed()

func _remove_last_waypoint() -> void:
	if not target_positions.is_empty():
		target_positions = target_positions.slice(0, -1)   # 或 .duplicate() 后 pop
		move_durations = move_durations.slice(0, -1)
		wait_times = wait_times.slice(0, -1)
		print("已撤销最后一个路径点")
		notify_property_list_changed()

# ---------- 核心逻辑 ----------

func _ready() -> void:
	if Engine.is_editor_hint():
		return

## 由父节点 BaseTrigger 调用的入口方法
func trigger(_body: Node3D) -> void:
	play_sequence()

func play_sequence() -> void:
	if target_positions.is_empty():
		push_warning("没有设置路径点!")
		return
	
	on_animation_start.emit()
	var target: Node3D = animated_object if animated_object else self
	var original_pos: Vector3 = target.global_position
	
	var tween: Tween = create_tween()
	
	# 从初始位置出发,依次移动到每个路径点
	for i in range(target_positions.size()):
		var pos: Vector3 = target_positions[i]
		var move_time: float = duration
		if i < move_durations.size():
			move_time = move_durations[i]
		
		var wait_time: float = 0.0
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

func play_() -> void:
	play_sequence()
