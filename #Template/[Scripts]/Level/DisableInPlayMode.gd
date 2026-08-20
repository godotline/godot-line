class_name DisableInPlayMode
extends Node

## DisableInPlayMode - 运行时禁用物体组件
## 挂载在需要运行时禁用的节点下（或挂在自身上），一比一还原 Unity DisableInPlayMode

@export var disableInPlayMode: bool = true

func _ready() -> void:
	if not Engine.is_editor_hint() and disableInPlayMode:
		var parent: Node = get_parent()
		if parent:
			SetActive.SetNodeActive(parent, false)
