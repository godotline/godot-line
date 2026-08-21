@tool
extends EditorPlugin

var dock: Control = null


func _enter_tree() -> void:
	var dockScene: PackedScene = preload("res://addons/dancing_line_importer/json_import_dock.tscn")
	if dockScene:
		dock = dockScene.instantiate() as Control
		add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)


func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.free()
		dock = null


func _get_plugin_name() -> String:
	return "ARPhros Importer"


func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/dancing_line_importer/icons/plugin_icon.svg")
