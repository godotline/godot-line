extends Node
class_name AutoPlayController
## AutoPlayController - 自动转向控制器（与 Unity 版一致）
## 运行时在 GuidanceBox 位置自动创建 Box 触发器，默认隐藏

static var Instance: AutoPlayController

@export var enable: bool = false

var _holder: Node3D
var _triggers: Array[Area3D] = []
var _init_in_progress: bool = false
var _initialized: bool = false

func _ready() -> void:
	Instance = self
	# 等场景切换和其他节点的 _ready() 完成后再读取 current_scene。
	call_deferred("_init_triggers")

func _init_triggers() -> void:
	if _init_in_progress or _initialized:
		return
	_init_in_progress = true
	await get_tree().process_frame
	if not is_inside_tree():
		_init_in_progress = false
		return

	var current_scene: Node = get_tree().current_scene
	if not is_instance_valid(current_scene):
		_queue_init_retry()
		return

	var guidance_controller: GuidanceController = GuidanceController.Instance
	if not is_instance_valid(guidance_controller):
		_queue_init_retry()
		return
	var box_holder: Node3D = guidance_controller.box_holder
	if not is_instance_valid(box_holder):
		_queue_init_retry()
		return

	var boxes: Array[Node] = box_holder.get_children()
	if boxes.is_empty():
		_init_in_progress = false
		_initialized = true
		return

	_holder = Node3D.new()
	_holder.name = "AutoPlayHolder"
	current_scene.add_child(_holder)

	# 从第二个 box 开始创建触发器（与 Unity 版一致，跳过第 0 个）
	for i in range(1, boxes.size()):
		var box: Node = boxes[i]
		if not box is Node3D:
			continue
		var trigger: Area3D = _create_trigger(box.global_position, i)
		_triggers.append(trigger)

	_init_in_progress = false
	_initialized = true
	set_holder(enable)

func _queue_init_retry() -> void:
	_init_in_progress = false
	if is_inside_tree():
		call_deferred("_init_triggers")

func _create_trigger(pos: Vector3, index: int) -> Area3D:
	var area: Area3D = Area3D.new()
	area.name = "AutoPlayTrigger %d" % index
	area.collision_mask = 1  # 检测 Player（layer 1），对齐 Unity 的 CompareTag("Player")

	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 4)  # 对齐 Unity CreateTrigger(PrimitiveType.Cube, scale=4)
	collision.shape = box
	area.add_child(collision)

	var script: Script = load("res://#Template/[Scripts]/Auto/AutoPlay.gd")
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
