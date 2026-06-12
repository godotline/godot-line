extends Checkpoint
## @deprecated: 推荐使用 CheckpointBehavior + 自定义旋转效果作为 BaseTrigger 的子节点
## HeartCheckpoint - 爱心检查点（向后兼容包装）

@export var rotator: Node3D

var _frame: Node3D
var _core: Node3D

func _ready() -> void:
	super._ready()
	if not rotator:
		rotator = get_node_or_null("Rotator")
	if rotator:
		_frame = rotator.get_node_or_null("Frame")
		_core = rotator.get_node_or_null("Core")

func _process(delta: float) -> void:
	if _frame:
		_frame.rotate_y(delta * deg_to_rad(-18.0))
	if _core:
		_core.rotate_y(delta * deg_to_rad(60.0))

## 覆盖 _on_triggered，先执行旋转动画再调用超类的检查点逻辑
func _on_triggered(body: Node3D) -> void:
	if used:
		return
	if rotator:
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(rotator, "scale", Vector3.ONE, 0.5)
	super._on_triggered(body)
