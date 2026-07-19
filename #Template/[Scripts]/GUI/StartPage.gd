@tool
extends CanvasLayer
class_name StartPage

signal start_requested
signal info_button_pressed
signal autoplay_toggled(is_on: bool)
signal setting_changed(key: String, value)
signal shadow_toggled(is_on: bool)
signal post_toggled(is_on: bool)

@onready var _ui_container: Control = $UIContainer
@onready var main_panel: Panel = $UIContainer/MainPanel
@onready var top_bar: HBoxContainer = $UIContainer/TopBar
@onready var info_btn: Button = $UIContainer/InfoButton
@onready var bottom_bar: Panel = $UIContainer/BottomBar
@onready var about_panel: Panel = $UIContainer/AboutPanel
@onready var about_content: Panel = $UIContainer/AboutPanel/AboutContent
# Setting item mode constants
const MODE_CYCLIC: int = 0
const MODE_RANGE: int = 1
const MODE_LATENCY: int = 2

@onready var _set_auto_play: Node = $SetAutoPlay

# Inlined checkbox item references
@onready var autoplay_checkbox: CheckBox = $UIContainer/RightArea/AutoPlayToggle/CheckBox
@onready var autoplay_label: Label = $UIContainer/RightArea/AutoPlayToggle/ItemLabel
@onready var shadow_checkbox: CheckBox = $UIContainer/BottomBar/HBox/ShadowToggle/CheckBox
@onready var shadow_label: Label = $UIContainer/BottomBar/HBox/ShadowToggle/ItemLabel
@onready var post_checkbox: CheckBox = $UIContainer/BottomBar/HBox/PostToggle/CheckBox
@onready var post_label: Label = $UIContainer/BottomBar/HBox/PostToggle/ItemLabel

# Setting item state dictionary: key -> state
var _setting_states: Dictionary = {}

var _about_visible: bool = false

func _ready() -> void:
	_init_setting_states()
	# 从 Player.level_data 读取关卡信息，填充关于页面（与 Unity 版 StartPage 一致）
	_populate_about_from_level_data()

func _init_setting_states() -> void:
	# --- AntiAliasing (CYCLIC) ---
	var aa: Dictionary = _create_setting_state("antialiasing", $UIContainer/BottomBar/HBox/AntiAliasingItem)
	aa.mode = MODE_CYCLIC
	aa.options = ["Off", "x2", "x4", "x8"]
	aa.index = 0
	_update_setting_display(aa)

	# --- Quality (CYCLIC) ---
	var ql: Dictionary = _create_setting_state("quality", $UIContainer/BottomBar/HBox/QualityItem)
	ql.mode = MODE_CYCLIC
	ql.options = ["低", "中", "高", "极高"]
	ql.index = 1
	_update_setting_display(ql)

	# --- Latency (LATENCY) ---
	var lt: Dictionary = _create_setting_state("latency", $UIContainer/BottomBar/HBox/LatencyItem)
	lt.mode = MODE_LATENCY
	lt.min_val = -5.0
	lt.max_val = 5.0
	lt.step = 0.01
	lt.value = 0.0
	lt.suffix = "ms"
	lt.arrow_left.visible = false
	lt.arrow_right.visible = false
	lt.arrow_coarse_left.visible = true
	lt.arrow_fine_left.visible = true
	lt.arrow_coarse_right.visible = true
	lt.arrow_fine_right.visible = true
	_update_setting_display(lt)

	# --- Volume (RANGE) ---
	var vl: Dictionary = _create_setting_state("volume", $UIContainer/BottomBar/HBox/VolumeItem)
	vl.mode = MODE_RANGE
	vl.min_val = 0.0
	vl.max_val = 1.0
	vl.step = 0.1
	vl.value = 1.0
	vl.suffix = "%"
	_update_setting_display(vl)

	# --- Checkbox items ---
	autoplay_label.text = "AUTOPLAY"
	autoplay_label.add_theme_color_override("font_color", Color(1, 0, 0))
	autoplay_label.add_theme_font_size_override("font_size", 16)

	autoplay_checkbox.toggled.connect(_on_autoplay_toggled)
	shadow_checkbox.toggled.connect(_on_shadow_toggled)
	post_checkbox.toggled.connect(_on_post_toggled)

func _populate_about_from_level_data() -> void:
	# Player 使用 class_name + static var instance 模式
	var player: Player = Player.instance if Player.instance != null else null
	if not player or not player.level_data:
		return
	var ld: LevelData = player.level_data

	# 设置标题
	var title_node: Node = about_content.find_child("about_title", true)
	if title_node is Label:
		title_node.text = ld.levelTitle

	# 设置作者列表（带可点击 URL，与 Unity 版 StartPage 一致）
	var author_container: Node = about_content.find_child("about_authors", true)
	if author_container:
		for child in author_container.get_children():
			child.queue_free()
		for a in ld.authors:
			var btn: Button = Button.new()
			btn.text = a.name
			btn.flat = true
			btn.add_theme_font_size_override("font_size", 16)
			if a.page_url:
				btn.pressed.connect(_open_author_url.bind(a.page_url))
			author_container.add_child(btn)

static func _open_author_url(url: String) -> void:
	OS.shell_open(url)


# === Background click ===

func _on_background_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_requested.emit()

# === About show/hide animation ===

func _toggle_about() -> void:
	if _about_visible:
		_hide_about()
	else:
		_show_about()

func _show_about() -> void:
	if _about_visible:
		return
	_about_visible = true
	about_panel.visible = true

	const REST: float = -150.0
	const SHIFT: float = 400.0
	about_content.offset_top = REST + SHIFT
	about_content.offset_bottom = -REST + SHIFT
	about_content.rotation_degrees = 15
	about_content.modulate.a = 0.0

	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(about_content, "offset_top", REST, 0.4)
	tween.tween_property(about_content, "offset_bottom", -REST, 0.4)
	tween.tween_property(about_content, "rotation_degrees", 0.0, 0.4)
	tween.tween_property(about_content, "modulate:a", 1.0, 0.3)

func _hide_about() -> void:
	if not _about_visible:
		return
	_about_visible = false

	const REST: float = -150.0
	const SHIFT: float = 400.0
	var tween: Tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(about_content, "offset_top", REST + SHIFT, 0.3)
	tween.tween_property(about_content, "offset_bottom", -REST + SHIFT, 0.3)
	tween.tween_property(about_content, "rotation_degrees", -15.0, 0.3)
	tween.tween_property(about_content, "modulate:a", 0.0, 0.3)
	tween.finished.connect(_on_about_hide_finished)
func _on_about_hide_finished() -> void:
	about_panel.visible = false

# === Public API ===

func show_ui() -> void:
	visible = true

func hide_animated() -> void:
	if not visible:
		return

	# 让所有子节点无视鼠标事件，确保事件穿透到 3D 场景
	for child in _ui_container.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tween: Tween = create_tween().set_parallel()

	if top_bar and is_instance_valid(top_bar):
		tween.tween_property(top_bar, "offset_top", -top_bar.size.y - 20, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(top_bar, "modulate:a", 0.0, 0.35)

	if about_content and is_instance_valid(about_content):
		tween.tween_property(about_content, "modulate:a", 0.0, 0.35)
		tween.tween_property(about_content, "position:y", get_viewport().get_visible_rect().size.y + 100, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	if bottom_bar and is_instance_valid(bottom_bar):
		tween.tween_property(bottom_bar, "offset_top", get_viewport().get_visible_rect().size.y + 20, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(bottom_bar, "modulate:a", 0.0, 0.35)

	if info_btn and is_instance_valid(info_btn):
		tween.tween_property(info_btn, "offset_left", -60, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(info_btn, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	if main_panel and is_instance_valid(main_panel):
		tween.tween_property(main_panel, "modulate:a", 0.0, 0.45)

	tween.finished.connect(_on_hide_finished)

func _on_hide_finished() -> void:
	queue_free()

func set_about_content(title: String, authors: Array, credits: String) -> void:
	var title_node: Node = about_content.find_child("about_title", true)
	if title_node is Label:
		title_node.text = title

	var author_container: Node = about_content.find_child("about_authors", true)
	if author_container:
		for child in author_container.get_children():
			child.queue_free()
		for author in authors:
			var lbl: Label = Label.new()
			lbl.text = str(author)
			lbl.add_theme_font_size_override("font_size", 16)
			author_container.add_child(lbl)

	var credits_node: Node = about_content.find_child("about_credits", true)
	if credits_node is Label:
		credits_node.text = credits

func set_setting(key: String, value) -> void:
	if not _setting_states.has(key):
		return
	var state: Dictionary = _setting_states[key]
	if state.mode == MODE_CYCLIC:
		var idx: int = state.options.find(value)
		if idx >= 0:
			state.index = idx
		elif state.options.size() > 0:
			push_warning("StartPage.set_setting: value '%s' not found in options" % str(value))
	else:
		state.value = clampf(value, state.min_val, state.max_val)
	_update_setting_display(state)

func get_setting(key: String):
	if _setting_states.has(key):
		return _get_setting_value(_setting_states[key])
	return null

func _create_setting_state(key: String, root: VBoxContainer) -> Dictionary:
	var title_label: Label = root.get_node_or_null("TitleLabel") as Label
	var value_label: Label = root.get_node_or_null("Controls/ValueLabel") as Label
	var arrow_left: Button = root.get_node_or_null("Controls/ArrowLeft") as Button
	var arrow_right: Button = root.get_node_or_null("Controls/ArrowRight") as Button
	var arrow_coarse_left: Button = root.get_node_or_null("Controls/ArrowCoarseLeft") as Button
	var arrow_fine_left: Button = root.get_node_or_null("Controls/ArrowFineLeft") as Button
	var arrow_coarse_right: Button = root.get_node_or_null("Controls/ArrowCoarseRight") as Button
	var arrow_fine_right: Button = root.get_node_or_null("Controls/ArrowFineRight") as Button
	if not title_label or not value_label or not arrow_left or not arrow_right or not arrow_coarse_left or not arrow_fine_left or not arrow_coarse_right or not arrow_fine_right:
		push_error("StartPage.gd: 设置项 '%s' 的 UI 子节点缺失，请检查场景结构" % key)
	var state: Dictionary = {
		key = key,
		root = root,
		title_label = title_label,
		value_label = value_label,
		arrow_left = arrow_left,
		arrow_right = arrow_right,
		arrow_coarse_left = arrow_coarse_left,
		arrow_fine_left = arrow_fine_left,
		arrow_coarse_right = arrow_coarse_right,
		arrow_fine_right = arrow_fine_right,
		mode = MODE_CYCLIC,
		options = [],
		index = 0,
		value = 0.0,
		min_val = 0.0, max_val = 100.0, step = 1.0,
		suffix = "",
	}
	_setting_states[key] = state

	state.arrow_left.pressed.connect(_on_setting_left.bind(state))
	state.arrow_right.pressed.connect(_on_setting_right.bind(state))
	state.arrow_coarse_left.pressed.connect(_on_setting_coarse_left.bind(state))
	state.arrow_fine_left.pressed.connect(_on_setting_fine_left.bind(state))
	state.arrow_coarse_right.pressed.connect(_on_setting_coarse_right.bind(state))
	state.arrow_fine_right.pressed.connect(_on_setting_fine_right.bind(state))

	return state

func _update_setting_display(state: Dictionary) -> void:
	match state.mode:
		MODE_CYCLIC:
			state.value_label.text = str(state.options[state.index]) if state.options.size() > 0 else ""
		MODE_RANGE, MODE_LATENCY:
			var display_val: Variant = state.value
			if state.suffix == "ms":
				display_val = round(state.value * 1000)
			elif state.suffix == "%":
				display_val = round(state.value * 100)
			state.value_label.text = str(display_val) + state.suffix

func _get_setting_value(state: Dictionary):
	if state.mode == MODE_CYCLIC:
		return state.options[state.index] if state.options.size() > 0 else null
	return state.value

# === Arrow button handlers ===

func _on_setting_left(state: Dictionary) -> void:
	match state.mode:
		MODE_CYCLIC:
			if state.options.size() == 0:
				return
			state.index = (state.index - 1 + state.options.size()) % state.options.size()
		MODE_RANGE, MODE_LATENCY:
			state.value = clampf(state.value - state.step, state.min_val, state.max_val)
	setting_changed.emit(state.key, _get_setting_value(state))
	_update_setting_display(state)

func _on_setting_right(state: Dictionary) -> void:
	match state.mode:
		MODE_CYCLIC:
			if state.options.size() == 0:
				return
			state.index = (state.index + 1) % state.options.size()
		MODE_RANGE, MODE_LATENCY:
			state.value = clampf(state.value + state.step, state.min_val, state.max_val)
	setting_changed.emit(state.key, _get_setting_value(state))
	_update_setting_display(state)

func _on_setting_fine_left(state: Dictionary) -> void:
	if state.mode == MODE_LATENCY:
		state.value = max(state.min_val, state.value - 0.001)
		setting_changed.emit(state.key, state.value)
		_update_setting_display(state)

func _on_setting_fine_right(state: Dictionary) -> void:
	if state.mode == MODE_LATENCY:
		state.value = min(state.max_val, state.value + 0.001)
		setting_changed.emit(state.key, state.value)
		_update_setting_display(state)

func _on_setting_coarse_left(state: Dictionary) -> void:
	if state.mode == MODE_LATENCY:
		state.value = max(state.min_val, state.value - 0.01)
		setting_changed.emit(state.key, state.value)
		_update_setting_display(state)

func _on_setting_coarse_right(state: Dictionary) -> void:
	if state.mode == MODE_LATENCY:
		state.value = min(state.max_val, state.value + 0.01)
		setting_changed.emit(state.key, state.value)
		_update_setting_display(state)

# === Internal handlers ===

func _on_about_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_about()

func _on_info_pressed() -> void:
	info_button_pressed.emit()
	_toggle_about()

func _on_autoplay_toggled(_is_on: bool) -> void:
	autoplay_toggled.emit(_is_on)
	if _set_auto_play and _set_auto_play.has_method("SetAuto"):
		_set_auto_play.SetAuto()

func _on_shadow_toggled(is_on: bool) -> void:
	shadow_toggled.emit(is_on)

func _on_post_toggled(is_on: bool) -> void:
	post_toggled.emit(is_on)
