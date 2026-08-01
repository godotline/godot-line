extends Node
## SetAutoPlay - 自动播放开关（与 Unity 版一致）
## 外部调用 SetAuto() 切换自动转向模式

var _active: bool = false

func _ready() -> void:
	await get_tree().process_frame
	if AutoPlayController.Instance:
		_active = AutoPlayController.Instance.enable

func get_auto() -> bool:
	return _active

func SetAuto(desired: bool = !_active) -> void:
	_active = desired
	if not AutoPlayController.Instance:
		return
	AutoPlayController.Instance.set_holder(_active)
	if Player.instance:
		Player.instance.disallow_input = _active
