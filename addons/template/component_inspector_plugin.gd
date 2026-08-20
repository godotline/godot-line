@tool
extends EditorInspectorPlugin

## 通用「添加组件」Inspector 插件：对所有 Node 节点生效，
## 在 Inspector 底部显示 ComponentAddPanel，无需为节点附加脚本。

const COMPONENT_ADD_PANEL_PATH := "res://addons/template/component_add_panel.gd"


func _can_handle(object: Object) -> bool:
	return object is Node


func _parse_begin(object: Object) -> void:
	var host: Node = object as Node
	if host == null:
		return
	var script: GDScript = load(COMPONENT_ADD_PANEL_PATH) as GDScript
	if script == null:
		return
	var panel: Control = script.new() as Control
	if panel == null:
		return
	panel.call("inspect", host)
	add_custom_control(panel)

