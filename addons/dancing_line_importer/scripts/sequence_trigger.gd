extends Node
class_name SequenceTrigger

## 序列触发器组件（对应 ARPhros TriggerType.Sequence）
## A trigger that calls another trigger in a sequence：
## - Pre-Activate：玩家进入本触发器时立即触发 preTargets
## - Activate：经 delay 秒后触发 mainTargets
## - Post-Activate：玩家离开后经 postDelay 秒触发 postTargets
## 目标是其他触发器（Area3D/BaseTrigger 容器）节点，由导入器后处理填充；
## 触发方式为模拟 BaseTrigger 分发：遍历目标容器的子组件调用 trigger(body)，
## 各组件自身的防重入逻辑（invoked/used）保持有效。

@export_group("序列目标")
@export var preTargets: Array[Node] = []
@export var mainTargets: Array[Node] = []
@export var postTargets: Array[Node] = []

@export_group("时序")
@export var delay: float = 0.0
@export var postDelay: float = 0.0
@export var loop: bool = false
@export var loopDelay: float = 0.0

var _timers: Array[Timer] = []


func trigger(body: Node3D) -> void:
	_fire(preTargets, body)
	if not mainTargets.is_empty():
		_startTimer(delay, mainTargets, body)


func on_exit(body: Node3D) -> void:
	if postTargets.is_empty():
		return
	_startTimer(postDelay, postTargets, body)


func _startTimer(waitTime: float, targets: Array[Node], body: Node3D) -> void:
	if waitTime <= 0.0:
		_fire(targets, body)
		return
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = waitTime
	add_child(timer)
	_timers.append(timer)
	timer.timeout.connect(func() -> void:
		_fire(targets, body)
		timer.queue_free()
	)
	timer.start()


## 模拟 BaseTrigger 分发：调用目标触发器容器下所有组件的 trigger(body)
func _fire(targets: Array[Node], body: Node3D) -> void:
	var validBody := body if is_instance_valid(body) else null
	for root: Node in targets:
		if root == null or not is_instance_valid(root):
			continue
		for child: Node in root.get_children():
			if child != validBody and child.has_method("trigger"):
				child.call("trigger", validBody)
