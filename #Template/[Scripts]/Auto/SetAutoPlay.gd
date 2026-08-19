extends Node
## SetAutoPlay - 自动播放开关（与 Unity 版一致）
## 外部调用 SetAuto() 切换自动转向模式

var _active: bool = false
var _user_set: bool = false

func _ready() -> void:
	await get_tree().process_frame
	if not _user_set and AutoPlayController.Instance:
		if AutoPlayController.Instance.has_method("get_requested_active"):
			_active = AutoPlayController.Instance.get_requested_active()
		else:
			_active = AutoPlayController.Instance.enable

func get_auto() -> bool:
	return _active

func SetAuto(desired: bool = !_active) -> void:
	_user_set = true
	_active = desired
	if AutoPlayController.Instance:
		AutoPlayController.Instance.SetHolder(_active)
	if Player.instance:
		Player.instance.disallowInput = _active
