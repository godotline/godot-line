@tool
extends Node3D
## MovingPosMaxTrigger - 序列位置移动触发器
## 当玩家进入时,让目标物体沿路径点序列移动
## 支持设置多个路径点、不同的移动时间和等待时间

@export_group("动画对象设置")
## 要移动的对象(如果不设置则移动自身)
@export var animatedObject: Node3D
## 目标位置数组(路径点序列,以global_position表示)
@export var targetPositions: Array[Vector3] = []
## 每段移动的时间(对应从起点到第一个终点、第一个到第二个等)
@export var moveDurations: Array[float] = []
## 在每个路径点的等待时间
@export var waitTimes: Array[float] = []
## 默认移动时间(当 moveDurations 为空时使用)
@export var duration: float = 1.0
## 过渡类型
@export var transitionType: Tween.TransitionType = Tween.TransitionType.TRANS_LINEAR

## 自定义触发信号(保留向后兼容)
signal on_animation_start
signal on_animation_end

@export_tool_button("抓取路径点") var setEndAction: Callable = func() -> void:
	_grab_waypoint()

@export_tool_button("预览播放") var previewPlayAction: Callable = func() -> void:
	if Engine.is_editor_hint():
		play_sequence()

func _grab_waypoint() -> void:
	var target: Node3D = animatedObject if animatedObject else self
	var newPos: Vector3 = target.global_position
	var oldPositions: Array[Vector3] = targetPositions.duplicate()
	var oldDurations: Array[float] = moveDurations.duplicate()
	var oldWaits: Array[float] = waitTimes.duplicate()
	var newPositions: Array[Vector3] = oldPositions.duplicate()
	var newDurations: Array[float] = oldDurations.duplicate()
	var newWaits: Array[float] = oldWaits.duplicate()

	newPositions.append(newPos)
	newDurations.append(duration)
	newWaits.append(0.0)

	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action("抓取路径点")
	undoRedo.add_do_property(self, "targetPositions", newPositions)
	undoRedo.add_do_property(self, "moveDurations", newDurations)
	undoRedo.add_do_property(self, "waitTimes", newWaits)
	undoRedo.add_undo_property(self, "targetPositions", oldPositions)
	undoRedo.add_undo_property(self, "moveDurations", oldDurations)
	undoRedo.add_undo_property(self, "waitTimes", oldWaits)
	undoRedo.commit_action()

	print("目标位置: ", newPos)
	print("当前路径点数组: ", targetPositions)
	notify_property_list_changed()

func _remove_last_waypoint() -> void:
	if not targetPositions.is_empty():
		targetPositions = targetPositions.slice(0, -1)   # 或 .duplicate() 后 pop
		moveDurations = moveDurations.slice(0, -1)
		waitTimes = waitTimes.slice(0, -1)
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
	if targetPositions.is_empty():
		push_warning("没有设置路径点!")
		return
	
	on_animation_start.emit()
	var target: Node3D = animatedObject if animatedObject else self
	var originalPos: Vector3 = target.global_position
	
	var tween: Tween = create_tween()
	
	# 从初始位置出发,依次移动到每个路径点
	for i in range(targetPositions.size()):
		var pos: Vector3 = targetPositions[i]
		var moveTime: float = duration
		if i < moveDurations.size():
			moveTime = moveDurations[i]
		
		var waitTime: float = 0.0
		if i < waitTimes.size():
			waitTime = waitTimes[i]
		
		tween.tween_property(target, "global_position", pos, moveTime).set_trans(transitionType)
		if waitTime > 0.0:
			tween.tween_interval(waitTime)
	
	tween.tween_callback(func():
		if Engine.is_editor_hint():
			target.global_position = originalPos
		on_animation_end.emit()
	)
	print("动画开始播放,路径点数: ", targetPositions.size())

func play_() -> void:
	play_sequence()
