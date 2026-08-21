@tool
extends CanvasLayer
class_name StartPage

signal start_requested
signal info_button_pressed
signal autoplay_toggled(isOn: bool)
signal setting_changed(key: String, value: Variant)
signal shadow_toggled(isOn: bool)
signal post_toggled(isOn: bool)

@onready var uiContainer: Control = $UIContainer
@onready var mainPanel: Panel = $UIContainer/MainPanel
@onready var autoplayArea: HBoxContainer = $UIContainer/RightArea
@onready var topBar: HBoxContainer = $UIContainer/TopBar
@onready var infoBtn: Button = $UIContainer/InfoButton
@onready var bottomBar: Panel = $UIContainer/BottomBar
@onready var aboutPanel: Panel = $UIContainer/AboutPanel
@onready var aboutContent: Panel = $UIContainer/AboutPanel/AboutContent
@onready var aboutCanvas: Control = $UIContainer/AboutPanel/AboutContent
@onready var aboutHideCanvas: Node = $UIContainer/AboutPanel/AboutContent/HideCanvas
# Setting item mode constants
const MODE_CYCLIC: int = 0
const MODE_RANGE: int = 1
const MODE_LATENCY: int = 2

@onready var setAutoPlay: Node = $SetAutoPlay

# Inlined checkbox item references
@onready var autoplayCheckbox: CheckBox = $UIContainer/RightArea/AutoPlayToggle/CheckBox
@onready var autoplayLabel: Label = $UIContainer/RightArea/AutoPlayToggle/ItemLabel
@onready var shadowCheckbox: CheckBox = $UIContainer/BottomBar/HBox/ShadowToggle/CheckBox
@onready var shadowLabel: Label = $UIContainer/BottomBar/HBox/ShadowToggle/ItemLabel
@onready var postCheckbox: CheckBox = $UIContainer/BottomBar/HBox/PostToggle/CheckBox
@onready var postLabel: Label = $UIContainer/BottomBar/HBox/PostToggle/ItemLabel

# Setting item state dictionary: key -> state
var settingStates: Dictionary = {}

var aboutVisible: bool = false

func _ready() -> void:
	_init_setting_states()
	_populate_about_from_level_data()
	if OS.has_feature("template"):
		autoplayArea.visible = false
		if setAutoPlay:
			setAutoPlay.queue_free()
	else:
		await get_tree().process_frame
		if setAutoPlay and setAutoPlay.has_method("get_auto"):
			autoplayCheckbox.button_pressed = setAutoPlay.get_auto()

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
	lt.minVal = -5.0
	lt.maxVal = 5.0
	lt.step = 0.01
	lt.value = 0.0
	lt.suffix = "ms"
	lt.arrowLeft.visible = false
	lt.arrowRight.visible = false
	lt.arrowCoarseLeft.visible = true
	lt.arrowFineLeft.visible = true
	lt.arrowCoarseRight.visible = true
	lt.arrowFineRight.visible = true
	_update_setting_display(lt)

	# --- Volume (RANGE) ---
	var vl: Dictionary = _create_setting_state("volume", $UIContainer/BottomBar/HBox/VolumeItem)
	vl.mode = MODE_RANGE
	vl.minVal = 0.0
	vl.maxVal = 1.0
	vl.step = 0.1
	vl.value = 1.0
	vl.suffix = "%"
	_update_setting_display(vl)

	# --- Checkbox items ---
	autoplayLabel.text = "AUTOPLAY"
	autoplayLabel.add_theme_color_override("font_color", Color(1, 0, 0))
	autoplayLabel.add_theme_font_size_override("font_size", 16)

	autoplayCheckbox.toggled.connect(_on_autoplay_toggled)
	shadowCheckbox.toggled.connect(_on_shadow_toggled)
	postCheckbox.toggled.connect(_on_post_toggled)

func _populate_about_from_level_data() -> void:
	# Player 使用 class_name + static var instance 模式
	var player: Player = Player.instance if Player.instance != null else null
	if not player or not player.levelData:
		return
	var ld: LevelData = player.levelData

	# 设置标题
	var titleNode: Node = aboutContent.find_child("about_title", true)
	if titleNode is Label:
		titleNode.text = ld.levelTitle

	# 设置作者列表（带可点击 URL，与 Unity 版 StartPage 一致）
	var authorContainer: Node = aboutContent.find_child("about_authors", true)
	if authorContainer:
		for child in authorContainer.get_children():
			child.queue_free()
		for a in ld.authors:
			var btn: Button = Button.new()
			btn.text = a.name
			btn.flat = true
			btn.add_theme_font_size_override("font_size", 16)
			if a.pageURL:
				btn.pressed.connect(_open_author_url.bind(a.pageURL))
			authorContainer.add_child(btn)

static func _open_author_url(url: String) -> void:
	OS.shell_open(url)


# === Background click ===

func _on_main_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_requested.emit()

func _on_autoplay_hit_target_pressed() -> void:
	var isOn: bool = not autoplayCheckbox.button_pressed
	autoplayCheckbox.set_pressed_no_signal(isOn)
	_on_autoplay_toggled(isOn)

# === About show/hide animation ===

func _show_about() -> void:
	if aboutVisible:
		return
	aboutVisible = true
	aboutPanel.visible = true
	if aboutCanvas.has_method("show_canvas"):
		aboutCanvas.call("show_canvas")

func _hide_about() -> void:
	if not aboutVisible:
		return
	aboutVisible = false
	if aboutHideCanvas.has_method("hide_canvas"):
		aboutHideCanvas.call("hide_canvas")
func _on_about_hide_finished() -> void:
	aboutPanel.visible = false

# === Public API ===

func show_ui() -> void:
	visible = true

func hide_animated() -> void:
	if not visible:
		return

	# 让所有子节点无视鼠标事件，确保事件穿透到 3D 场景
	for child in uiContainer.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tween: Tween = create_tween().set_parallel()

	if topBar and is_instance_valid(topBar):
		tween.tween_property(topBar, "offset_top", -topBar.size.y - 20, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(topBar, "modulate:a", 0.0, 0.35)

	if autoplayArea and is_instance_valid(autoplayArea):
		tween.tween_property(autoplayArea, "offset_top", -autoplayArea.size.y - 20, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(autoplayArea, "modulate:a", 0.0, 0.35)

	if aboutContent and is_instance_valid(aboutContent):
		tween.tween_property(aboutContent, "modulate:a", 0.0, 0.35)
		tween.tween_property(aboutContent, "position:y", get_viewport().get_visible_rect().size.y + 100, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	if bottomBar and is_instance_valid(bottomBar):
		tween.tween_property(bottomBar, "offset_top", get_viewport().get_visible_rect().size.y + 20, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(bottomBar, "modulate:a", 0.0, 0.35)

	if infoBtn and is_instance_valid(infoBtn):
		tween.tween_property(infoBtn, "offset_left", -60, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(infoBtn, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	if mainPanel and is_instance_valid(mainPanel):
		tween.tween_property(mainPanel, "modulate:a", 0.0, 0.45)

	tween.finished.connect(_on_hide_finished)

func _on_hide_finished() -> void:
	queue_free()

func set_about_content(title: String, authors: Array, credits: String) -> void:
	var titleNode: Node = aboutContent.find_child("about_title", true)
	if titleNode is Label:
		titleNode.text = title

	var authorContainer: Node = aboutContent.find_child("about_authors", true)
	if authorContainer:
		for child in authorContainer.get_children():
			child.queue_free()
		for author in authors:
			var lbl: Label = Label.new()
			lbl.text = str(author)
			lbl.add_theme_font_size_override("font_size", 16)
			authorContainer.add_child(lbl)

	var creditsNode: Node = aboutContent.find_child("about_credits", true)
	if creditsNode is Label:
		creditsNode.text = credits

func set_setting(key: String, value: Variant) -> void:
	if not settingStates.has(key):
		return
	var state: Dictionary = settingStates[key]
	if state.mode == MODE_CYCLIC:
		var idx: int = state.options.find(value)
		if idx >= 0:
			state.index = idx
		elif state.options.size() > 0:
			push_warning("StartPage.set_setting: value '%s' not found in options" % str(value))
	else:
		state.value = clampf(float(value), state.minVal, state.maxVal)
	_update_setting_display(state)

func get_setting(key: String) -> Variant:
	if settingStates.has(key):
		return _get_setting_value(settingStates[key])
	return null

func _create_setting_state(key: String, root: VBoxContainer) -> Dictionary:
	var titleLabel: Label = root.get_node_or_null("TitleLabel") as Label
	var valueLabel: Label = root.get_node_or_null("Controls/ValueLabel") as Label
	var arrowLeft: Button = root.get_node_or_null("Controls/ArrowLeft") as Button
	var arrowRight: Button = root.get_node_or_null("Controls/ArrowRight") as Button
	var arrowCoarseLeft: Button = root.get_node_or_null("Controls/ArrowCoarseLeft") as Button
	var arrowFineLeft: Button = root.get_node_or_null("Controls/ArrowFineLeft") as Button
	var arrowCoarseRight: Button = root.get_node_or_null("Controls/ArrowCoarseRight") as Button
	var arrowFineRight: Button = root.get_node_or_null("Controls/ArrowFineRight") as Button
	if not titleLabel or not valueLabel or not arrowLeft or not arrowRight or not arrowCoarseLeft or not arrowFineLeft or not arrowCoarseRight or not arrowFineRight:
		push_error("StartPage.gd: 设置项 '%s' 的 UI 子节点缺失，请检查场景结构" % key)
	var state: Dictionary = {
		key = key,
		root = root,
		titleLabel = titleLabel,
		valueLabel = valueLabel,
		arrowLeft = arrowLeft,
		arrowRight = arrowRight,
		arrowCoarseLeft = arrowCoarseLeft,
		arrowFineLeft = arrowFineLeft,
		arrowCoarseRight = arrowCoarseRight,
		arrowFineRight = arrowFineRight,
		mode = MODE_CYCLIC,
		options = [],
		index = 0,
		value = 0.0,
		minVal = 0.0, maxVal = 100.0, step = 1.0,
		suffix = "",
	}
	settingStates[key] = state

	state.arrowLeft.pressed.connect(_on_setting_left.bind(state))
	state.arrowRight.pressed.connect(_on_setting_right.bind(state))
	state.arrowCoarseLeft.pressed.connect(_on_setting_coarse_left.bind(state))
	state.arrowFineLeft.pressed.connect(_on_setting_fine_left.bind(state))
	state.arrowCoarseRight.pressed.connect(_on_setting_coarse_right.bind(state))
	state.arrowFineRight.pressed.connect(_on_setting_fine_right.bind(state))

	return state

func _update_setting_display(state: Dictionary) -> void:
	match state.mode:
		MODE_CYCLIC:
			state.valueLabel.text = str(state.options[state.index]) if state.options.size() > 0 else ""
		MODE_RANGE, MODE_LATENCY:
			var displayVal: Variant = state.value
			if state.suffix == "ms":
				displayVal = round(state.value * 1000)
			elif state.suffix == "%":
				displayVal = round(state.value * 100)
			state.valueLabel.text = str(displayVal) + state.suffix

func _get_setting_value(state: Dictionary) -> Variant:
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
			state.value = clampf(state.value - state.step, state.minVal, state.maxVal)
	setting_changed.emit(state.key, _get_setting_value(state))
	_update_setting_display(state)

func _on_setting_right(state: Dictionary) -> void:
	match state.mode:
		MODE_CYCLIC:
			if state.options.size() == 0:
				return
			state.index = (state.index + 1) % state.options.size()
		MODE_RANGE, MODE_LATENCY:
			state.value = clampf(state.value + state.step, state.minVal, state.maxVal)
	setting_changed.emit(state.key, _get_setting_value(state))
	_update_setting_display(state)

func _on_setting_fine_left(state: Dictionary) -> void:
	if state.mode == MODE_LATENCY:
		state.value = max(state.minVal, state.value - 0.001)
		setting_changed.emit(state.key, state.value)
		_update_setting_display(state)

func _on_setting_fine_right(state: Dictionary) -> void:
	if state.mode == MODE_LATENCY:
		state.value = min(state.maxVal, state.value + 0.001)
		setting_changed.emit(state.key, state.value)
		_update_setting_display(state)

func _on_setting_coarse_left(state: Dictionary) -> void:
	if state.mode == MODE_LATENCY:
		state.value = max(state.minVal, state.value - 0.01)
		setting_changed.emit(state.key, state.value)
		_update_setting_display(state)

func _on_setting_coarse_right(state: Dictionary) -> void:
	if state.mode == MODE_LATENCY:
		state.value = min(state.maxVal, state.value + 0.01)
		setting_changed.emit(state.key, state.value)
		_update_setting_display(state)

# === Internal handlers ===

func _on_about_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_about()

func _on_info_pressed() -> void:
	info_button_pressed.emit()
	_show_about()

func _on_autoplay_toggled(isOn: bool) -> void:
	autoplay_toggled.emit(isOn)
	if setAutoPlay and setAutoPlay.has_method("SetAuto"):
		setAutoPlay.SetAuto(isOn)

func _on_shadow_toggled(isOn: bool) -> void:
	shadow_toggled.emit(isOn)

func _on_post_toggled(isOn: bool) -> void:
	post_toggled.emit(isOn)
