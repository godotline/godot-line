extends BaseTrigger
class_name SetActiveTrigger

## SetActiveTrigger - 激活/禁用触发器
## 触发时激活/禁用指定节点，支持复活时恢复状态

@export_group("激活设置")
@export var active_on_awake: bool = false
@export var actives: Array[Dictionary] = []

var _revive_states: Array[Dictionary] = []
var _checkpoint_index: int = 0
