@tool
extends Node

## 场景保存哨兵：由 ComponentAddPanel 以无 owner 的内部子节点挂在宿主下，
## 不随场景序列化。场景保存前后收到编辑器通知，转发回调给面板，
## 用于在落盘前清掉编辑期临时 meta（如 __base_node_relative）、保存后恢复。

var onPreSave: Callable = Callable()
var onPostSave: Callable = Callable()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE and onPreSave.is_valid():
		onPreSave.call()
	elif what == NOTIFICATION_EDITOR_POST_SAVE and onPostSave.is_valid():
		onPostSave.call()
