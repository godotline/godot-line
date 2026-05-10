extends Node
## SetAutoPlay - 自动播放开关（与 Unity 版一致）
## 外部调用 toggle() 切换自动转向模式

var _active: bool = false

func toggle() -> void:
	_active = !_active
	if not AutoPlayController.Instance:
		return
	AutoPlayController.Instance.set_holder(_active)
	if Player.instance:
		Player.instance.disallow_input = _active
