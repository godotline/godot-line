@tool
extends EditorPlugin

const WELCOME_URL := "https://www.cnblogs.com/mmme/p/-/tutorial"
const MARKER_PATH := "user://.first_run_welcome_done"

const TEMPLATE_DEFAULT := "res://#Template/[Scenes]/DefaultScene/Default.tscn"
const TEMPLATE_SAMPLE := "res://#Template/[Scenes]/Sample/Sample.tscn"
const LEVELS_ROOT := "res://[Scenes]/"
const DirectionGizmoPlugin := preload("res://addons/template/direction_gizmo_plugin.gd")
const PluginStoreDialogClass := preload("res://addons/template/plugin_store_dialog.gd")
const EventTriggerInspectorPluginClass := preload("res://addons/template/event_trigger_inspector_plugin.gd")
const ComponentInspectorPluginClass := preload("res://addons/template/component_inspector_plugin.gd")
const CheckpointCaptureRuntimeClass := preload("res://addons/template/checkpoint_capture_runtime.gd")
const CheckpointCaptureDebuggerPluginClass := preload("res://addons/template/checkpoint_capture_debugger.gd")
const NoteReaderClass := preload("res://addons/template/NoteReader.gd")

var _menu_button: MenuButton
var _new_level_dialog: ConfirmationDialog
var _store_dialog: ConfirmationDialog
var _direction_gizmo_plugin: EditorNode3DGizmoPlugin
var _event_trigger_inspector_plugin: Object
var _component_inspector_plugin: Object
var _checkpoint_capture_debugger_plugin: EditorDebuggerPlugin


func _enter_tree() -> void:
	PluginStoreDialogClass.cleanup_quarantine()
	_check_first_run()
	_direction_gizmo_plugin = DirectionGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_direction_gizmo_plugin)
	_event_trigger_inspector_plugin = EventTriggerInspectorPluginClass.new()
	add_inspector_plugin(_event_trigger_inspector_plugin)
	_component_inspector_plugin = ComponentInspectorPluginClass.new()
	add_inspector_plugin(_component_inspector_plugin)
	_checkpoint_capture_debugger_plugin = CheckpointCaptureDebuggerPluginClass.new()
	_checkpoint_capture_debugger_plugin.call("setup", Callable(self, "_apply_checkpoint_snapshot"))
	add_debugger_plugin(_checkpoint_capture_debugger_plugin)

	_menu_button = MenuButton.new()
	var templateVersion: String = PluginRegistry.get_template_version()
	_menu_button.text = "模板 %s" % (templateVersion if not templateVersion.is_empty() else "未知版本")
	_menu_button.tooltip_text = "Template 相关资源"
	_menu_button.switch_on_hover = true

	var popup: PopupMenu = _menu_button.get_popup()
	popup.add_item("模板手册", 0)
	popup.add_item("新建关卡", 1)
	popup.add_item("排序 GuidanceBox", 3)
	popup.add_item("NoteReader", 4)
	popup.add_separator()
	popup.add_item("插件商城", 2)
	popup.id_pressed.connect(_on_menu_item_pressed)

	add_control_to_container(CONTAINER_TOOLBAR, _menu_button)


func _exit_tree() -> void:
	if _checkpoint_capture_debugger_plugin:
		remove_debugger_plugin(_checkpoint_capture_debugger_plugin)
		_checkpoint_capture_debugger_plugin = null
	if _direction_gizmo_plugin:
		remove_node_3d_gizmo_plugin(_direction_gizmo_plugin)
		_direction_gizmo_plugin = null
	if _event_trigger_inspector_plugin:
		remove_inspector_plugin(_event_trigger_inspector_plugin)
		_event_trigger_inspector_plugin = null
	if _component_inspector_plugin:
		remove_inspector_plugin(_component_inspector_plugin)
		_component_inspector_plugin = null
	if _menu_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _menu_button)
		_menu_button.queue_free()
		_menu_button = null
	if _new_level_dialog and is_instance_valid(_new_level_dialog):
		_new_level_dialog.queue_free()
		_new_level_dialog = null
	if _store_dialog and is_instance_valid(_store_dialog):
		_store_dialog.queue_free()
		_store_dialog = null


func _check_first_run() -> void:
	if FileAccess.file_exists(MARKER_PATH):
		return
	var f := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	if f:
		f.store_string("done")
		f.close()
	await get_tree().process_frame
	OS.shell_open(WELCOME_URL)
	print("[FirstRunWelcome] 已打开项目主页: %s" % WELCOME_URL)


func _on_menu_item_pressed(id: int) -> void:
	match id:
		0:
			OS.shell_open(WELCOME_URL)
		1:
			_show_new_level_dialog()
		3:
			_sort_guidance_boxes_in_current_scene()
		4:
			_spawn_note_reader()
		2:
			_show_store_dialog()


# ===================== NoteReader 谱面生成 =====================

func _spawn_note_reader() -> void:
	var sceneRoot: Node = get_editor_interface().get_edited_scene_root()
	if not sceneRoot:
		_push_error("当前没有打开的场景")
		return

	var existing: Node = sceneRoot.get_node_or_null("NoteReader")
	if existing:
		get_editor_interface().edit_node(existing)
		return

	var reader: Node = NoteReaderClass.new()
	reader.name = "NoteReader"
	sceneRoot.add_child(reader)
	reader.owner = sceneRoot

	get_editor_interface().edit_node(reader)
	get_editor_interface().mark_scene_as_unsaved()
	print("[NoteReader] 已在场景中添加 NoteReader 节点，请在 Inspector 中配置参数（场景字段可直接拖拽 .tscn）并勾选「执行生成」")


# ===================== GuidanceBox 排序 =====================

func _sort_guidance_boxes_in_current_scene() -> void:
	var sceneRoot: Node = get_editor_interface().get_edited_scene_root()
	if not sceneRoot:
		_push_error("当前没有打开的场景")
		return

	var holders: Array[Node] = []
	_collect_guidance_holders(sceneRoot, holders)
	if holders.is_empty():
		_push_error("当前场景没有找到 GuidanceBoxHolder")
		return
	var player: Player = _find_player_in_scene(sceneRoot)
	var playerDirection: Vector3 = Vector3.FORWARD
	var alternateDirection: Vector3 = Vector3.RIGHT
	if player:
		playerDirection = _direction_from_degrees(player.currentDirection)
		alternateDirection = _direction_from_degrees(
			player.secondDirection if player.currentDirection == player.firstDirection else player.firstDirection
		)

	var changedCount: int = 0
	var undoRedo: EditorUndoRedoManager = get_undo_redo()
	undoRedo.create_action("排序 GuidanceBox")
	for holder: Node in holders:
		var ordered: Array[Node] = _sort_holder_boxes(holder, playerDirection, alternateDirection)
		if ordered.is_empty():
			continue
		var original: Array[Node] = []
		for child: Node in holder.get_children():
			if _is_guidance_box_root(child):
				original.append(child)
		if _same_node_order(original, ordered):
			continue
		undoRedo.add_do_method(self, "_apply_guidance_box_order", holder, ordered)
		undoRedo.add_undo_method(self, "_apply_guidance_box_order", holder, original)
		changedCount += 1
	if changedCount == 0:
		undoRedo.commit_action(false)
		print("[GuidanceSort] 当前 GuidanceBox 已经是路径顺序")
		return
	undoRedo.commit_action()
	get_editor_interface().mark_scene_as_unsaved()
	print("[GuidanceSort] 已排序 %d 个 GuidanceBoxHolder" % changedCount)


func _collect_guidance_holders(node: Node, holders: Array[Node]) -> void:
	if node.name == "GuidanceBoxHolder":
		holders.append(node)
	for child: Node in node.get_children():
		_collect_guidance_holders(child, holders)


func _sort_holder_boxes(holder: Node, playerDirection: Vector3, alternateDirection: Vector3) -> Array[Node]:
	var remaining: Array[Node] = []
	for child: Node in holder.get_children():
		if _is_guidance_box_root(child):
			remaining.append(child)
	if remaining.size() < 2:
		return remaining

	var ordered: Array[Node] = []
	var current: Node = null
	for candidate: Node in remaining:
		if candidate.name == "OriginalGuidanceBox":
			current = candidate
			break
	if current == null:
		current = remaining[0]
	ordered.append(current)
	remaining.erase(current)

	while not remaining.is_empty():
		var direction: Vector3 = playerDirection if ordered.size() % 2 == 1 else alternateDirection
		var next: Node = _find_next_guidance_box(current, remaining, direction)
		ordered.append(next)
		remaining.erase(next)
		current = next
	return ordered


func _direction_from_degrees(rotation_degrees: Vector3) -> Vector3:
	var rotationRadians: Vector3 = rotation_degrees * (PI / 180.0)
	var direction: Vector3 = Basis.from_euler(rotationRadians) * Vector3.FORWARD
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		return direction.normalized()
	return Vector3.FORWARD


func _find_next_guidance_box(current: Node, candidates: Array[Node], playerDirection: Vector3) -> Node:
	var current_3d: Node3D = current as Node3D
	var direction: Vector3 = playerDirection

	var best: Node = candidates[0]
	var bestDistance: float = INF
	var bestProjection: float = INF
	var bestIsAhead: bool = false
	for candidate: Node in candidates:
		var candidate_3d: Node3D = candidate as Node3D
		if not candidate_3d or not current_3d:
			continue
		var offset: Vector3 = candidate_3d.global_position - current_3d.global_position
		var projection: float = offset.dot(direction)
		var distance: float = offset.length_squared()
		var isAhead: bool = projection > 0.001
		var shouldReplace: bool = false
		if isAhead and not bestIsAhead:
			shouldReplace = true
		elif isAhead == bestIsAhead:
			if isAhead:
				shouldReplace = projection < bestProjection or (is_equal_approx(projection, bestProjection) and distance < bestDistance)
			else:
				shouldReplace = distance < bestDistance
		if shouldReplace:
			best = candidate
			bestDistance = distance
			bestProjection = projection
			bestIsAhead = isAhead
	return best


func _find_player_in_scene(node: Node) -> Player:
	if node is Player:
		return node as Player
	for child: Node in node.get_children():
		var found: Player = _find_player_in_scene(child)
		if found:
			return found
	return null


func _is_guidance_box_root(node: Node) -> bool:
	if node is GuidanceBox:
		return true
	for child: Node in node.get_children():
		if _is_guidance_box_root(child):
			return true
	return false


func _same_node_order(first: Array[Node], second: Array[Node]) -> bool:
	if first.size() != second.size():
		return false
	for i: int in range(first.size()):
		if first[i] != second[i]:
			return false
	return true


func _apply_guidance_box_order(holder: Node, ordered: Array[Node]) -> void:
	var boxIndex: int = 0
	for child: Node in holder.get_children():
		if not _is_guidance_box_root(child):
			continue
		var target: Node = ordered[boxIndex]
		var targetIndex: int = holder.get_children().find(target)
		if targetIndex != -1:
			holder.move_child(target, targetIndex)
		boxIndex += 1


# ===================== 插件商城 =====================

func _show_store_dialog() -> void:
	if _store_dialog and is_instance_valid(_store_dialog):
		_store_dialog.queue_free()
		_store_dialog = null

	_store_dialog = PluginStoreDialogClass.new()
	_store_dialog.unresizable = false
	add_child(_store_dialog)
	_store_dialog.popup_centered(Vector2i(720, 520))


# ===================== 新建关卡 =====================

func _show_new_level_dialog() -> void:
	if _new_level_dialog and is_instance_valid(_new_level_dialog):
		_new_level_dialog.queue_free()
		_new_level_dialog = null

	var dialog := ConfirmationDialog.new()
	dialog.title = "新建关卡"
	dialog.min_size = Vector2i(380, 240)
	dialog.unresizable = false
	dialog.ok_button_text = "创建"
	_new_level_dialog = dialog

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)

	# 关卡名称
	var nameRow := HBoxContainer.new()
	vbox.add_child(nameRow)
	var nameLbl := Label.new()
	nameLbl.text = "关卡名称："
	nameLbl.custom_minimum_size = Vector2(100, 0)
	nameRow.add_child(nameLbl)
	var nameEdit := LineEdit.new()
	nameEdit.placeholder_text = "MyLevel"
	nameEdit.custom_minimum_size = Vector2(250, 0)
	nameRow.add_child(nameEdit)

	# 模板场景
	var tplRow := HBoxContainer.new()
	vbox.add_child(tplRow)
	var tplLbl := Label.new()
	tplLbl.text = "模板场景："
	tplLbl.custom_minimum_size = Vector2(100, 0)
	tplRow.add_child(tplLbl)
	var tplOpts := OptionButton.new()
	tplOpts.add_item("DefaultScene", 0)
	tplOpts.add_item("Sample", 1)
	tplOpts.custom_minimum_size = Vector2(250, 0)
	tplRow.add_child(tplOpts)

	# 关卡 ID
	var idRow := HBoxContainer.new()
	vbox.add_child(idRow)
	var idLbl := Label.new()
	idLbl.text = "关卡ID："
	idLbl.custom_minimum_size = Vector2(100, 0)
	idRow.add_child(idLbl)
	var idEdit := LineEdit.new()
	idEdit.placeholder_text = "1"
	idEdit.custom_minimum_size = Vector2(250, 0)
	idEdit.text = "1"
	idRow.add_child(idEdit)

	# 提示
	var hint := Label.new()
	hint.text = "将在 [Scenes]/<关卡名>/ 下创建场景与唯一的 LevelData 资源"
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font", 12)
	vbox.add_child(hint)

	add_child(dialog)

	dialog.confirmed.connect(func():
		var levelName := nameEdit.text.strip_edges()
		var templatePath: String
		match tplOpts.get_selected_id():
			0:
				templatePath = TEMPLATE_DEFAULT
			_:
				templatePath = TEMPLATE_SAMPLE
		var levelIdText := idEdit.text.strip_edges()
		var levelId := 1
		if levelIdText.is_valid_int():
			levelId = levelIdText.to_int()
		if levelName.is_empty():
			_push_error("关卡名称不能为空")
			return
		var err := _create_new_level(levelName, templatePath, levelId)
		if err == OK:
			print("[NewLevel] 关卡创建成功：%s (id=%d, 模板=%s)" % [levelName, levelId, templatePath])
			dialog.hide()
	)

	dialog.popup_centered()
	await get_tree().process_frame
	nameEdit.call_deferred("grab_focus")


## 新建关卡：基于模板场景实例化、替换 LevelData 为唯一副本、重新打包保存
func _create_new_level(levelName: String, templatePath: String, levelId: int) -> int:
	var safeName := _sanitize_name(levelName)
	if safeName.is_empty():
		_push_error("无效的关卡名称：%s" % levelName)
		return ERR_INVALID_PARAMETER

	var levelDir := LEVELS_ROOT + safeName + "/"
	var scenePath := levelDir + safeName + ".tscn"
	var tresPath := levelDir + safeName + ".tres"

	if FileAccess.file_exists(scenePath) or FileAccess.file_exists(tresPath):
		_push_error("关卡已存在：%s" % levelDir)
		return ERR_ALREADY_EXISTS

	var templateScene := load(templatePath) as PackedScene
	if not templateScene:
		_push_error("无法加载模板场景：%s" % templatePath)
		return ERR_CANT_OPEN

	# 使用 GEN_EDIT_STATE_MAIN 实例化，保留节点所有权（owner=root），保证 pack() 能正确打包
	var root := templateScene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if not root:
		_push_error("实例化模板场景失败：%s" % templatePath)
		return ERR_CANT_CREATE

	# 查找 Player 节点
	var player := root.get_node_or_null("BasicOBJ_Group/Player") as Player
	if not player:
		_push_error("模板场景 %s 未找到 BasicOBJ_Group/Player 节点" % templatePath)
		root.queue_free()
		return ERR_INVALID_DATA

	if not player.levelData:
		_push_error("模板场景 %s 的 Player 节点未设置 levelData" % templatePath)
		root.queue_free()
		return ERR_INVALID_DATA

	# 创建目录
	DirAccess.make_dir_recursive_absolute(levelDir)

	# 深拷贝 LevelData 资源，设新字段（唯一化）
	var newData := (player.levelData as Resource).duplicate(true) as LevelData
	if not newData:
		_push_error("复制 LevelData 资源失败")
		root.queue_free()
		return ERR_CANT_CREATE
	newData.saveID = levelId
	newData.levelTitle = levelName
	# levelTitleKey 保持模板原值，仅当为空时用 safeName
	if newData.levelTitleKey.is_empty():
		newData.levelTitleKey = safeName

	# 保存 LevelData 资源（ResourceSaver 会自动分配 UID）
	var saveErr := ResourceSaver.save(newData, tresPath)
	if saveErr != OK:
		_push_error("LevelData 资源保存失败：%s (err=%d)" % [tresPath, saveErr])
		root.queue_free()
		return saveErr
	print("[NewLevel] 已生成 LevelData 资源：%s" % tresPath)

	# 重新加载刚保存的资源，拿到带 UID 的引用
	var savedData := load(tresPath) as LevelData
	if not savedData:
		_push_error("无法重新加载刚保存的 LevelData：%s" % tresPath)
		root.queue_free()
		return ERR_CANT_OPEN

	# 将 Player 的 levelData 指向唯一副本
	player.levelData = savedData

	# 打包并保存场景
	var newScene := PackedScene.new()
	var packErr := newScene.pack(root)
	root.queue_free()
	if packErr != OK:
		_push_error("打包场景失败 (err=%d)" % packErr)
		return packErr

	var sceneSaveErr := ResourceSaver.save(newScene, scenePath)
	if sceneSaveErr != OK:
		_push_error("场景保存失败：%s (err=%d)" % [scenePath, sceneSaveErr])
		return sceneSaveErr
	print("[NewLevel] 已生成场景文件：%s" % scenePath)

	# 刷新文件系统
	EditorInterface.get_resource_filesystem().scan()

	# 在编辑器中打开新场景
	EditorInterface.open_scene_from_path(scenePath)

	return OK


func _sanitize_name(name: String) -> String:
	var out := ""
	for ch in name:
		var code := ch.unicode_at(0)
		# 允许：字母 (A-Z,a-z)、数字 (0-9)、下划线、连字符
		if (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or (code >= 48 and code <= 57) \
			or code == 95 or code == 45:
			out += ch
	return out


func _push_error(msg: String) -> void:
	push_error("[Template 插件] " + msg)
	printerr("[Template 插件] " + msg)


func _apply_checkpoint_snapshot(snapshot: Dictionary) -> void:
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
		for property_name: StringName in CheckpointCaptureRuntimeClass.VALUE_PROPERTIES:
			if values.has(property_name):
				updates[property_name] = values[property_name]

	var settingsValue: Variant = snapshot.get("settings", {})
	if settingsValue is Dictionary:
		var settings: Dictionary = settingsValue as Dictionary
		for property_name: StringName in CheckpointCaptureRuntimeClass.SETTINGS_PROPERTIES:
			var serializedValue: Variant = settings.get(property_name, null)
			if not serializedValue is Dictionary:
				continue
			var restored: Object = dict_to_inst(serializedValue as Dictionary)
			var resource: Resource = restored as Resource
			if resource:
				resource.resource_local_to_scene = true
				updates[property_name] = resource

	if updates.is_empty():
		return
	var undoRedo: EditorUndoRedoManager = get_undo_redo()
	undoRedo.create_action(
		"自动复制 Checkpoint 参数",
		UndoRedo.MERGE_DISABLE,
		editedRoot,
	)
	for property_name: StringName in updates:
		undoRedo.add_do_property(checkpoint, property_name, updates[property_name])
		undoRedo.add_undo_property(checkpoint, property_name, checkpoint.get(property_name))
	undoRedo.commit_action()
	print("[CheckpointCapture] 已自动复制：%s" % nodePath)
