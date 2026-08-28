@tool
class_name CheckpointCaptureApplier
extends RefCounted

## 把运行期捕获的 Checkpoint 参数快照回填到编辑场景（带撤销）。

const CheckpointCaptureRuntimeClass := preload("res://addons/template/checkpoint_capture_runtime.gd")


static func applySnapshot(snapshot: Dictionary) -> void:
	var editedRoot: Node = EditorInterface.get_edited_scene_root()
	if not editedRoot:
		return
	var scenePath: String = str(snapshot.get("scene_path", ""))
	if editedRoot.scene_file_path != scenePath:
		push_warning("[CheckpointCapture] 当前编辑场景与运行场景不一致，已忽略：%s" % scenePath)
		return
	var nodePath: NodePath = NodePath(str(snapshot.get("node_path", "")))
	var checkpoint: Node = editedRoot.get_node_or_null(nodePath)
	if not checkpoint or not checkpoint is Checkpoint:
		push_warning("[CheckpointCapture] 本地场景未找到 Checkpoint：%s" % nodePath)
		return

	var updates: Dictionary = {}
	var valuesValue: Variant = snapshot.get("values", {})
	if valuesValue is Dictionary:
		var values: Dictionary = valuesValue as Dictionary
		for propertyName: StringName in CheckpointCaptureRuntimeClass.VALUE_PROPERTIES:
			if values.has(propertyName):
				updates[propertyName] = values[propertyName]

	var settingsValue: Variant = snapshot.get("settings", {})
	if settingsValue is Dictionary:
		var settings: Dictionary = settingsValue as Dictionary
		for propertyName: StringName in CheckpointCaptureRuntimeClass.SETTINGS_PROPERTIES:
			var serializedValue: Variant = settings.get(propertyName, null)
			if not serializedValue is Dictionary:
				continue
			var restored: Object = dict_to_inst(serializedValue as Dictionary)
			var resource: Resource = restored as Resource
			if resource:
				resource.resource_local_to_scene = true
				updates[propertyName] = resource

	if updates.is_empty():
		return
	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action(
		"自动复制 Checkpoint 参数",
		UndoRedo.MERGE_DISABLE,
		editedRoot,
	)
	for propertyName: StringName in updates:
		undoRedo.add_do_property(checkpoint, propertyName, updates[propertyName])
		undoRedo.add_undo_property(checkpoint, propertyName, checkpoint.get(propertyName))
	undoRedo.commit_action()
	print("[CheckpointCapture] 已自动复制：%s" % nodePath)