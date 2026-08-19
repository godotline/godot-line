@tool
extends EditorInspectorPlugin

## 通用「添加组件」Inspector 插件：对所有 Node 节点生效，
## 在 Inspector 底部显示 ComponentAddPanel，无需为节点附加脚本。

const ComponentAddPanelClass := preload("res://addons/template/component_add_panel.gd")


func _can_handle(object: Object) -> bool:
	return object is Node


func _parse_begin(object: Object) -> void:
	var host: Node = object as Node
	if host == null:
		return
	var panel: Control = ComponentAddPanelClass.new()
	panel.call("inspect", host)
	add_custom_control(panel)