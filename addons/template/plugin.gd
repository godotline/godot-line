@tool
extends EditorPlugin

const WELCOME_URL := "https://www.cnblogs.com/mmme/p/-/tutorial"
const MARKER_PATH := "user://.first_run_welcome_done"

const TEMPLATE_DEFAULT := "res://[Scenes]/DefaultScene/Default.tscn"
const TEMPLATE_DEFAULT3 := "res://[Scenes]/DefaultScene3/Default.tscn"
const TEMPLATE_SAMPLE := "res://[Scenes]/Sample/Sample.tscn"
const LEVELS_ROOT := "res://[Scenes]/"
const DirectionGizmoPlugin := preload("res://addons/template/direction_gizmo_plugin.gd")
const PluginStoreDialogClass := preload("res://addons/template/plugin_store_dialog.gd")
const EventTriggerInspectorPluginClass := preload("res://addons/template/event_trigger_inspector_plugin.gd")
const CheckpointCaptureRuntimeClass := preload("res://addons/template/checkpoint_capture_runtime.gd")
const CheckpointCaptureDebuggerPluginClass := preload("res://addons/template/checkpoint_capture_debugger.gd")
const NoteReaderClass := preload("res://addons/template/note_reader.gd")
const BeatmapReaderClass := preload("res://addons/template/beatmap_reader.gd")
const DEFAULT_AUTO_PLAY_SCENE_PATH: String = "res://addons/template/default_auto_play_trigger.tscn"

var _menu_button: MenuButton
var _new_level_dialog: ConfirmationDialog
var _store_dialog: ConfirmationDialog
var _note_reader_dialog: ConfirmationDialog
var _note_reader_file_dialog: FileDialog
var _beatmap_reader_dialog: ConfirmationDialog
var _direction_gizmo_plugin: EditorNode3DGizmoPlugin
var _event_trigger_inspector_plugin: Object
var _checkpoint_capture_debugger_plugin: EditorDebuggerPlugin


func _enter_tree() -> void:
	PluginStoreDialogClass.cleanup_quarantine()
	_check_first_run()
	_direction_gizmo_plugin = DirectionGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_direction_gizmo_plugin)
	_event_trigger_inspector_plugin = EventTriggerInspectorPluginClass.new()
	add_inspector_plugin(_event_trigger_inspector_plugin)
	_checkpoint_capture_debugger_plugin = CheckpointCaptureDebuggerPluginClass.new()
	_checkpoint_capture_debugger_plugin.call("setup", Callable(self, "_apply_checkpoint_snapshot"))
	add_debugger_plugin(_checkpoint_capture_debugger_plugin)

	_menu_button = MenuButton.new()
	var template_version: String = PluginRegistry.get_template_version()
	_menu_button.text = "模板 %s" % (template_version if not template_version.is_empty() else "未知版本")
	_menu_button.tooltip_text = "Template 相关资源"
	_menu_button.switch_on_hover = true

	var popup: PopupMenu = _menu_button.get_popup()
	popup.add_item("模板手册", 0)
	popup.add_item("新建关卡", 1)
	popup.add_item("排序 GuidanceBox", 3)
	popup.add_item("NoteReader", 4)
	popup.add_item("BeatmapReaderz", 5)
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
	if _note_reader_file_dialog and is_instance_valid(_note_reader_file_dialog):
		_note_reader_file_dialog.queue_free()
		_note_reader_file_dialog = null
	if _note_reader_dialog and is_instance_valid(_note_reader_dialog):
		_note_reader_dialog.queue_free()
		_note_reader_dialog = null
	if _beatmap_reader_dialog and is_instance_valid(_beatmap_reader_dialog):
		_beatmap_reader_dialog.queue_free()
		_beatmap_reader_dialog = null


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
			_show_note_reader_dialog()
		5:
			_show_beatmap_reader_dialog()
		2:
			_show_store_dialog()


# ===================== NoteReader 谱面生成 =====================

func _show_note_reader_dialog() -> void:
	if _note_reader_dialog and is_instance_valid(_note_reader_dialog):
		_note_reader_dialog.queue_free()
		_note_reader_dialog = null

	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "NoteReader"
	dialog.min_size = Vector2i(720, 520)
	dialog.size = Vector2i(720, 520)
	dialog.unresizable = false
	dialog.ok_button_text = "生成对象"
	_note_reader_dialog = dialog
	add_child(dialog)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var beatmap_edit: LineEdit = _add_note_reader_path_row(content, "谱面文件", "*.osu")
	var road_scene_edit: LineEdit = _add_note_reader_path_row(content, "路面场景", "*.tscn")

	var make_road: CheckBox = CheckBox.new()
	make_road.text = "生成路面"
	make_road.button_pressed = true
	content.add_child(make_road)
	var road_width: SpinBox = _add_note_reader_number_row(content, "路面宽度", 1.0, 0.01, 100.0, 0.1)

	var auto_play: CheckBox = CheckBox.new()
	auto_play.text = "生成自动播放触发器"
	content.add_child(auto_play)

	var speed: SpinBox = _add_note_reader_number_row(content, "线速", 10.0, 0.01, 1000.0, 0.5)
	var forward1_inputs: Array[SpinBox] = _add_note_reader_vector_row(content, "Forward 1", Vector3(1, 0, 0))
	var forward2_inputs: Array[SpinBox] = _add_note_reader_vector_row(content, "Forward 2", Vector3(0, 0, 1))
	var start_inputs: Array[SpinBox] = _add_note_reader_vector_row(content, "起点位置", Vector3(2, 0, 0))

	var hint: Label = Label.new()
	hint.text = "生成结果会添加到当前编辑场景；自动触发器使用插件默认场景。"
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)

	dialog.confirmed.connect(func() -> void:
		_run_note_reader_from_dialog(
			beatmap_edit.text.strip_edges(),
			road_scene_edit.text.strip_edges(),
			make_road.button_pressed,
			road_width.value,
			auto_play.button_pressed,
			speed.value,
			_vector_from_note_reader_inputs(forward1_inputs),
			_vector_from_note_reader_inputs(forward2_inputs),
			_vector_from_note_reader_inputs(start_inputs),
		)
	)
	dialog.popup_centered(Vector2i(720, 520))


func _add_note_reader_path_row(parent: VBoxContainer, label_text: String, filter: String) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = label_text + "："
	label.custom_minimum_size = Vector2(180, 0)
	label.clip_text = true
	row.add_child(label)
	var edit: LineEdit = LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var browse: Button = Button.new()
	browse.text = "浏览"
	browse.pressed.connect(func() -> void:
		_open_note_reader_file_dialog(edit, filter)
	)
	row.add_child(browse)
	return edit


func _add_note_reader_vector_row(parent: VBoxContainer, label_text: String, value: Vector3) -> Array[SpinBox]:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = label_text + "："
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	var inputs: Array[SpinBox] = []
	var values: Array[float] = [value.x, value.y, value.z]
	var prefixes: Array[String] = ["X: ", "Y: ", "Z: "]
	for i: int in range(3):
		var spin: SpinBox = SpinBox.new()
		spin.value = values[i]
		spin.min_value = -100000.0
		spin.max_value = 100000.0
		spin.step = 0.01
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.prefix = prefixes[i]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spin)
		inputs.append(spin)
	return inputs


func _vector_from_note_reader_inputs(inputs: Array[SpinBox]) -> Vector3:
	if inputs.size() < 3:
		return Vector3.ZERO
	return Vector3(inputs[0].value, inputs[1].value, inputs[2].value)


func _add_note_reader_number_row(parent: VBoxContainer, label_text: String, value: float,
		minimum: float, maximum: float, step: float) -> SpinBox:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = label_text + "："
	label.custom_minimum_size = Vector2(180, 0)
	label.clip_text = true
	row.add_child(label)
	var spin: SpinBox = SpinBox.new()
	spin.value = value
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return spin


func _open_note_reader_file_dialog(target: LineEdit, filter: String) -> void:
	if _note_reader_file_dialog and is_instance_valid(_note_reader_file_dialog):
		_note_reader_file_dialog.queue_free()
	_note_reader_file_dialog = FileDialog.new()
	_note_reader_file_dialog.unresizable = false
	_note_reader_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_note_reader_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_note_reader_file_dialog.filters = PackedStringArray([filter])
	add_child(_note_reader_file_dialog)
	_note_reader_file_dialog.file_selected.connect(func(path: String) -> void:
		target.text = path
	)
	_note_reader_file_dialog.popup_centered(Vector2i(760, 520))


func _run_note_reader_from_dialog(beatmap_path: String, road_scene_path: String,
		make_road: bool, road_width: float, auto_play: bool,
		speed: float, forward1: Vector3, forward2: Vector3, start_position: Vector3) -> void:
	if beatmap_path.is_empty():
		_push_error("请先选择 .osu 谱面文件")
		return
	var scene_root: Node = get_editor_interface().get_edited_scene_root()
	if not scene_root:
		_push_error("当前没有打开的场景")
		return

	var reader: Node = NoteReaderClass.new()
	add_child(reader)
	reader.set("beatmap_file", beatmap_path)
	reader.set("make_road", make_road)
	reader.set("road_width", road_width)
	reader.set("auto_play", auto_play)
	reader.set("speed", speed)
	reader.set("forward1", forward1)
	reader.set("forward2", forward2)
	reader.set("start_position", start_position)
	var localized_road_scene_path: String = ProjectSettings.localize_path(road_scene_path)
	if not localized_road_scene_path.is_empty() and ResourceLoader.exists(localized_road_scene_path):
		reader.set("road_scene", load(localized_road_scene_path) as PackedScene)
	if auto_play and ResourceLoader.exists(DEFAULT_AUTO_PLAY_SCENE_PATH):
		reader.set("auto_play_scene", load(DEFAULT_AUTO_PLAY_SCENE_PATH) as PackedScene)
	reader.call("_run")
	get_editor_interface().mark_scene_as_unsaved()
	reader.queue_free()
	print("[NoteReader] 插件生成完成")


# ===================== BeatmapReader 指引生成 =====================

func _show_beatmap_reader_dialog() -> void:
	if _beatmap_reader_dialog and is_instance_valid(_beatmap_reader_dialog):
		_beatmap_reader_dialog.queue_free()
		_beatmap_reader_dialog = null

	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "BeatmapReader"
	dialog.min_size = Vector2i(720, 520)
	dialog.size = Vector2i(720, 520)
	dialog.unresizable = false
	dialog.ok_button_text = "生成 GuidanceBox"
	_beatmap_reader_dialog = dialog
	add_child(dialog)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var beatmap_edit: LineEdit = _add_note_reader_path_row(content, "谱面文件", "*.osu")
	var box_scene_edit: LineEdit = _add_note_reader_path_row(content, "GuidanceBox 场景", "*.tscn")
	var offset: SpinBox = _add_note_reader_number_row(content, "时间偏移 (秒)", 0.0, -10000.0, 10000.0, 0.01)
	var use_overrides: CheckBox = CheckBox.new()
	use_overrides.text = "使用下面的 Player 覆盖参数"
	content.add_child(use_overrides)
	var speed: SpinBox = _add_note_reader_number_row(content, "线速", 12.0, 0.01, 1000.0, 0.5)
	var first_direction: Array[SpinBox] = _add_note_reader_vector_row(content, "第一方向角度", Vector3.ZERO)
	var second_direction: Array[SpinBox] = _add_note_reader_vector_row(content, "第二方向角度", Vector3(0, 90, 0))
	var start_position: Array[SpinBox] = _add_note_reader_vector_row(content, "起点位置", Vector3.ZERO)

	var hint: Label = Label.new()
	hint.text = "未启用覆盖时自动读取当前场景 Player；生成物为 GuidelineTapHolder-BeatmapCreated。"
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)

	dialog.confirmed.connect(func() -> void:
		_run_beatmap_reader_from_dialog(
			beatmap_edit.text.strip_edges(),
			box_scene_edit.text.strip_edges(),
			offset.value,
			use_overrides.button_pressed,
			speed.value,
			_vector_from_note_reader_inputs(first_direction),
			_vector_from_note_reader_inputs(second_direction),
			_vector_from_note_reader_inputs(start_position),
		)
	)
	dialog.popup_centered(Vector2i(720, 520))


func _run_beatmap_reader_from_dialog(beatmap_path: String, box_scene_path: String,
		offset: float, use_overrides: bool, speed: float, first_direction: Vector3,
		second_direction: Vector3, start_position: Vector3) -> void:
	if beatmap_path.is_empty():
		_push_error("请先选择 .osu 谱面文件")
		return
	var scene_root: Node = get_editor_interface().get_edited_scene_root()
	if not scene_root:
		_push_error("当前没有打开的场景")
		return

	var reader: Node = BeatmapReaderClass.new()
	add_child(reader)
	reader.set("beatmap_file", beatmap_path)
	reader.set("offset", offset)
	reader.set("use_overrides", use_overrides)
	reader.set("speed_override", speed)
	reader.set("first_direction_override", first_direction)
	reader.set("second_direction_override", second_direction)
	reader.set("start_position_override", start_position)
	var localized_box_scene_path: String = ProjectSettings.localize_path(box_scene_path)
	if not localized_box_scene_path.is_empty() and ResourceLoader.exists(localized_box_scene_path):
		reader.set("guidance_box_scene", load(localized_box_scene_path) as PackedScene)
	reader.call("_create_guideline_taps")
	get_editor_interface().mark_scene_as_unsaved()
	reader.queue_free()
	print("[BeatmapReader] 插件生成完成")


# ===================== GuidanceBox 排序 =====================

func _sort_guidance_boxes_in_current_scene() -> void:
	var scene_root: Node = get_editor_interface().get_edited_scene_root()
	if not scene_root:
		_push_error("当前没有打开的场景")
		return

	var holders: Array[Node] = []
	_collect_guidance_holders(scene_root, holders)
	if holders.is_empty():
		_push_error("当前场景没有找到 GuidanceBoxHolder")
		return
	var player: Player = _find_player_in_scene(scene_root)
	var player_direction: Vector3 = Vector3.FORWARD
	var alternate_direction: Vector3 = Vector3.RIGHT
	if player:
		player_direction = _direction_from_degrees(player.current_direction)
		alternate_direction = _direction_from_degrees(
			player.secondDirection if player.current_direction == player.firstDirection else player.firstDirection
		)

	var changed_count: int = 0
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("排序 GuidanceBox")
	for holder: Node in holders:
		var ordered: Array[Node] = _sort_holder_boxes(holder, player_direction, alternate_direction)
		if ordered.is_empty():
			continue
		var original: Array[Node] = []
		for child: Node in holder.get_children():
			if _is_guidance_box_root(child):
				original.append(child)
		if _same_node_order(original, ordered):
			continue
		undo_redo.add_do_method(self, "_apply_guidance_box_order", holder, ordered)
		undo_redo.add_undo_method(self, "_apply_guidance_box_order", holder, original)
		changed_count += 1
	if changed_count == 0:
		undo_redo.commit_action(false)
		print("[GuidanceSort] 当前 GuidanceBox 已经是路径顺序")
		return
	undo_redo.commit_action()
	get_editor_interface().mark_scene_as_unsaved()
	print("[GuidanceSort] 已排序 %d 个 GuidanceBoxHolder" % changed_count)


func _collect_guidance_holders(node: Node, holders: Array[Node]) -> void:
	if node.name == "GuidanceBoxHolder":
		holders.append(node)
	for child: Node in node.get_children():
		_collect_guidance_holders(child, holders)


func _sort_holder_boxes(holder: Node, player_direction: Vector3, alternate_direction: Vector3) -> Array[Node]:
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
		var direction: Vector3 = player_direction if ordered.size() % 2 == 1 else alternate_direction
		var next: Node = _find_next_guidance_box(current, remaining, direction)
		ordered.append(next)
		remaining.erase(next)
		current = next
	return ordered


func _direction_from_degrees(rotation_degrees: Vector3) -> Vector3:
	var rotation_radians: Vector3 = rotation_degrees * (PI / 180.0)
	var direction: Vector3 = Basis.from_euler(rotation_radians) * Vector3.FORWARD
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		return direction.normalized()
	return Vector3.FORWARD


func _find_next_guidance_box(current: Node, candidates: Array[Node], player_direction: Vector3) -> Node:
	var current_3d: Node3D = current as Node3D
	var direction: Vector3 = player_direction

	var best: Node = candidates[0]
	var best_distance: float = INF
	var best_projection: float = INF
	var best_is_ahead: bool = false
	for candidate: Node in candidates:
		var candidate_3d: Node3D = candidate as Node3D
		if not candidate_3d or not current_3d:
			continue
		var offset: Vector3 = candidate_3d.global_position - current_3d.global_position
		var projection: float = offset.dot(direction)
		var distance: float = offset.length_squared()
		var is_ahead: bool = projection > 0.001
		var should_replace: bool = false
		if is_ahead and not best_is_ahead:
			should_replace = true
		elif is_ahead == best_is_ahead:
			if is_ahead:
				should_replace = projection < best_projection or (is_equal_approx(projection, best_projection) and distance < best_distance)
			else:
				should_replace = distance < best_distance
		if should_replace:
			best = candidate
			best_distance = distance
			best_projection = projection
			best_is_ahead = is_ahead
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
	var box_index: int = 0
	for child: Node in holder.get_children():
		if not _is_guidance_box_root(child):
			continue
		var target: Node = ordered[box_index]
		var target_index: int = holder.get_children().find(target)
		if target_index != -1:
			holder.move_child(target, target_index)
		box_index += 1


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
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "关卡名称："
	name_lbl.custom_minimum_size = Vector2(100, 0)
	name_row.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "MyLevel"
	name_edit.custom_minimum_size = Vector2(250, 0)
	name_row.add_child(name_edit)

	# 模板场景
	var tpl_row := HBoxContainer.new()
	vbox.add_child(tpl_row)
	var tpl_lbl := Label.new()
	tpl_lbl.text = "模板场景："
	tpl_lbl.custom_minimum_size = Vector2(100, 0)
	tpl_row.add_child(tpl_lbl)
	var tpl_opts := OptionButton.new()
	tpl_opts.add_item("DefaultScene", 0)
	tpl_opts.add_item("DefaultScene3", 1)
	tpl_opts.add_item("Sample", 2)
	tpl_opts.custom_minimum_size = Vector2(250, 0)
	tpl_row.add_child(tpl_opts)

	# 关卡 ID
	var id_row := HBoxContainer.new()
	vbox.add_child(id_row)
	var id_lbl := Label.new()
	id_lbl.text = "关卡ID："
	id_lbl.custom_minimum_size = Vector2(100, 0)
	id_row.add_child(id_lbl)
	var id_edit := LineEdit.new()
	id_edit.placeholder_text = "1"
	id_edit.custom_minimum_size = Vector2(250, 0)
	id_edit.text = "1"
	id_row.add_child(id_edit)

	# 提示
	var hint := Label.new()
	hint.text = "将在 [Scenes]/<关卡名>/ 下创建场景与唯一的 LevelData 资源"
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font", 12)
	vbox.add_child(hint)

	add_child(dialog)

	dialog.confirmed.connect(func():
		var level_name := name_edit.text.strip_edges()
		var template_path: String
		match tpl_opts.get_selected_id():
			0:
				template_path = TEMPLATE_DEFAULT
			1:
				template_path = TEMPLATE_DEFAULT3
			_:
				template_path = TEMPLATE_SAMPLE
		var level_id_text := id_edit.text.strip_edges()
		var level_id := 1
		if level_id_text.is_valid_int():
			level_id = level_id_text.to_int()
		if level_name.is_empty():
			_push_error("关卡名称不能为空")
			return
		var err := _create_new_level(level_name, template_path, level_id)
		if err == OK:
			print("[NewLevel] 关卡创建成功：%s (id=%d, 模板=%s)" % [level_name, level_id, template_path])
			dialog.hide()
	)

	dialog.popup_centered()
	await get_tree().process_frame
	name_edit.call_deferred("grab_focus")


## 新建关卡：基于模板场景实例化、替换 LevelData 为唯一副本、重新打包保存
func _create_new_level(level_name: String, template_path: String, level_id: int) -> int:
	var safe_name := _sanitize_name(level_name)
	if safe_name.is_empty():
		_push_error("无效的关卡名称：%s" % level_name)
		return ERR_INVALID_PARAMETER

	var level_dir := LEVELS_ROOT + safe_name + "/"
	var scene_path := level_dir + safe_name + ".tscn"
	var tres_path := level_dir + safe_name + ".tres"

	if FileAccess.file_exists(scene_path) or FileAccess.file_exists(tres_path):
		_push_error("关卡已存在：%s" % level_dir)
		return ERR_ALREADY_EXISTS

	var template_scene := load(template_path) as PackedScene
	if not template_scene:
		_push_error("无法加载模板场景：%s" % template_path)
		return ERR_CANT_OPEN

	# 使用 GEN_EDIT_STATE_MAIN 实例化，保留节点所有权（owner=root），保证 pack() 能正确打包
	var root := template_scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if not root:
		_push_error("实例化模板场景失败：%s" % template_path)
		return ERR_CANT_CREATE

	# 查找 Player 节点
	var player := root.get_node_or_null("BasicOBJ_Group/Player") as Player
	if not player:
		_push_error("模板场景 %s 未找到 BasicOBJ_Group/Player 节点" % template_path)
		root.queue_free()
		return ERR_INVALID_DATA

	if not player.levelData:
		_push_error("模板场景 %s 的 Player 节点未设置 levelData" % template_path)
		root.queue_free()
		return ERR_INVALID_DATA

	# 创建目录
	DirAccess.make_dir_recursive_absolute(level_dir)

	# 深拷贝 LevelData 资源，设新字段（唯一化）
	var new_data := (player.levelData as Resource).duplicate(true) as LevelData
	if not new_data:
		_push_error("复制 LevelData 资源失败")
		root.queue_free()
		return ERR_CANT_CREATE
	new_data.saveID = level_id
	new_data.levelTitle = level_name
	# levelTitleKey 保持模板原值，仅当为空时用 safe_name
	if new_data.levelTitleKey.is_empty():
		new_data.levelTitleKey = safe_name

	# 保存 LevelData 资源（ResourceSaver 会自动分配 UID）
	var save_err := ResourceSaver.save(new_data, tres_path)
	if save_err != OK:
		_push_error("LevelData 资源保存失败：%s (err=%d)" % [tres_path, save_err])
		root.queue_free()
		return save_err
	print("[NewLevel] 已生成 LevelData 资源：%s" % tres_path)

	# 重新加载刚保存的资源，拿到带 UID 的引用
	var saved_data := load(tres_path) as LevelData
	if not saved_data:
		_push_error("无法重新加载刚保存的 LevelData：%s" % tres_path)
		root.queue_free()
		return ERR_CANT_OPEN

	# 将 Player 的 levelData 指向唯一副本
	player.levelData = saved_data

	# 打包并保存场景
	var new_scene := PackedScene.new()
	var pack_err := new_scene.pack(root)
	root.queue_free()
	if pack_err != OK:
		_push_error("打包场景失败 (err=%d)" % pack_err)
		return pack_err

	var scene_save_err := ResourceSaver.save(new_scene, scene_path)
	if scene_save_err != OK:
		_push_error("场景保存失败：%s (err=%d)" % [scene_path, scene_save_err])
		return scene_save_err
	print("[NewLevel] 已生成场景文件：%s" % scene_path)

	# 刷新文件系统
	EditorInterface.get_resource_filesystem().scan()

	# 在编辑器中打开新场景
	EditorInterface.open_scene_from_path(scene_path)

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
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	if not edited_root:
		return
	var scene_path: String = str(snapshot.get("scene_path", ""))
	if edited_root.scene_file_path != scene_path:
		push_warning("[CheckpointCapture] 当前编辑场景与运行场景不一致，已忽略：%s" % scene_path)
		return
	var node_path: NodePath = NodePath(str(snapshot.get("node_path", "")))
	var checkpoint: Node = edited_root.get_node_or_null(node_path)
	if not checkpoint or not checkpoint is Checkpoint:
		push_warning("[CheckpointCapture] 本地场景未找到 Checkpoint：%s" % node_path)
		return

	var updates: Dictionary = {}
	var values_value: Variant = snapshot.get("values", {})
	if values_value is Dictionary:
		var values: Dictionary = values_value as Dictionary
		for property_name: StringName in CheckpointCaptureRuntimeClass.VALUE_PROPERTIES:
			if values.has(property_name):
				updates[property_name] = values[property_name]

	var settings_value: Variant = snapshot.get("settings", {})
	if settings_value is Dictionary:
		var settings: Dictionary = settings_value as Dictionary
		for property_name: StringName in CheckpointCaptureRuntimeClass.SETTINGS_PROPERTIES:
			var serialized_value: Variant = settings.get(property_name, null)
			if not serialized_value is Dictionary:
				continue
			var restored: Object = dict_to_inst(serialized_value as Dictionary)
			var resource: Resource = restored as Resource
			if resource:
				resource.resource_local_to_scene = true
				updates[property_name] = resource

	if updates.is_empty():
		return
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action(
		"自动复制 Checkpoint 参数",
		UndoRedo.MERGE_DISABLE,
		edited_root,
	)
	for property_name: StringName in updates:
		undo_redo.add_do_property(checkpoint, property_name, updates[property_name])
		undo_redo.add_undo_property(checkpoint, property_name, checkpoint.get(property_name))
	undo_redo.commit_action()
	print("[CheckpointCapture] 已自动复制：%s" % node_path)
