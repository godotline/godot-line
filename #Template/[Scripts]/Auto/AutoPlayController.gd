extends Node
class_name AutoPlayController
## AutoPlayController - 自动转向控制器（与 Unity 版一致）
## 运行时在 GuidanceBox 位置自动创建 Box 触发器，默认隐藏

static var Instance: AutoPlayController

@export var enable: bool = true

var _holder: Node3D
var _triggers: Array[Area3D] = []

func _ready() -> void:
	Instance = self
	# 等场景所有节点 _ready() 完成后再初始化（与 Unity 版一致，确保 GuidanceController 已就绪）
	get_tree().process_frame.connect(_init_triggers, CONNECT_ONE_SHOT)

func _init_triggers() -> void:
	if not GuidanceController.Instance or not GuidanceController.Instance.box_holder:
		push_warning("[AutoPlayController] GuidanceController 或 box_holder 未设置")
		return

	var boxes := GuidanceController.Instance.box_holder.get_children()
	if boxes.is_empty():
		return

	_holder = Node3D.new()
	_holder.name = "AutoPlayHolder"
	get_tree().current_scene.add_child(_holder)

	# 从第二个 box 开始创建触发器（与 Unity 版一致，跳过第 0 个）
	for i in range(1, boxes.size()):
		var box := boxes[i]
		if not box is Node3D:
			continue
		var trigger := _create_trigger(box.global_position, i)
		_triggers.append(trigger)

	set_holder(enable)

func _create_trigger(pos: Vector3, index: int) -> Area3D:
	var area := Area3D.new()
	area.name = "AutoPlayTrigger %d" % index
	area.collision_mask = 1  # 检测 Player（layer 1），对齐 Unity 的 CompareTag("Player")

	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 4)  # 对齐 Unity CreateTrigger(PrimitiveType.Cube, scale=4)
	collision.shape = box
	area.add_child(collision)

	var script := load("res://#Template/[Scripts]/Auto/AutoPlay.gd")
	area.set_script(script)

	_holder.add_child(area)
	area.global_position = pos
	return area

func set_holder(active: bool) -> void:
	if _holder:
		_holder.visible = active
		for trigger in _triggers:
			if trigger is Area3D:
				trigger.set_deferred("monitoring", active)
				trigger.set_deferred("monitorable", active)
