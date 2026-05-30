@tool
extends CanvasLayer
class_name StartPage

signal start_requested
signal info_button_pressed
signal autoplay_toggled(is_on: bool)
signal setting_changed(key: String, value)
signal shadow_toggled(is_on: bool)
signal post_toggled(is_on: bool)

# UI section references (for animation)
var main_panel: Panel
var top_bar: HBoxContainer
var center_card: Panel
var bottom_bar: Panel
var info_btn: Button
var about_panel: Panel
var autoplay_check: CheckBoxItem

# Setting item references
var antialiasing_item: SettingItem
var quality_item: SettingItem
var latency_item: SettingItem
var volume_item: SettingItem
var shadow_toggle: CheckBoxItem
var post_toggle: CheckBoxItem

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(container)

	# Background overlay
	main_panel = Panel.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.39)
	main_panel.add_theme_stylebox_override("panel", bg_style)
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(main_panel)

	_build_top_bar(container)
	_build_center_card(container)
	_build_info_button(container)
	_build_bottom_bar(container)
	_build_about_panel(container)

func _build_top_bar(parent: Control) -> void:
	top_bar = HBoxContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	top_bar.offset_bottom = top_bar.offset_top + 40
	parent.add_child(top_bar)

	# Left spacer
	var left = Control.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	top_bar.add_child(left)

	# Center keyboard hints
	var hint = Label.new()
	hint.text = "R: 重新开始  |  K: 快速死亡  |  D: 调试模式"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1))
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	top_bar.add_child(hint)

	# Right: Autoplay toggle
	var right = HBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.alignment = BOX_ALIGNMENT_END
	top_bar.add_child(right)

	autoplay_check = CheckBoxItem.new("AUTOPLAY")
	autoplay_check.label.add_theme_color_override("font_color", Color(1, 0, 0))
	autoplay_check.label.add_theme_font_size_override("font_size", 16)
	right.add_child(autoplay_check)
	autoplay_check.toggled.connect(_on_autoplay_toggled)

func _build_center_card(parent: Control) -> void:
	center_card = Panel.new()
	center_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.25, 0.25, 0.25)
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	center_card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(center_card)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 32
	vbox.offset_right = -32
	vbox.offset_top = 24
	vbox.offset_bottom = -24
	center_card.add_child(vbox)

	# Info labels
	var lines = [
		{text = "测试场景", size = 32, color = Color(1, 1, 1)},
		{text = "筱夕Sushi", size = 20, color = Color(0.8, 0.8, 0.8)},
		{text = "共舞的线模板", size = 14, color = Color(0.7, 0.7, 0.7)},
		{text = "基于冰焰模板 4.3.0 修改", size = 14, color = Color(0.7, 0.7, 0.7)},
		{text = "作者：Max冰焰、筱夕Sushi、Quantumilk", size = 14, color = Color(0.7, 0.7, 0.7)},
	]
	for info in lines:
		var lbl = Label.new()
		lbl.text = info.text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", info.size)
		lbl.add_theme_color_override("font_color", info.color)
		vbox.add_child(lbl)

func _build_info_button(parent: Control) -> void:
	info_btn = Button.new()
	info_btn.text = "i"
	info_btn.flat = true
	info_btn.custom_minimum_size = Vector2(40, 40)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.38, 0.38, 0.38)
	btn_style.corner_radius_top_left = 20
	btn_style.corner_radius_top_right = 20
	btn_style.corner_radius_bottom_left = 20
	btn_style.corner_radius_bottom_right = 20
	info_btn.add_theme_stylebox_override("normal", btn_style)

	info_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	info_btn.offset_top -= 100
	info_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(info_btn)
	info_btn.pressed.connect(_on_info_pressed)

func _build_bottom_bar(parent: Control) -> void:
	bottom_bar = Panel.new()
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -80
	bottom_bar.custom_minimum_size.y = 80

	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.19, 0.19, 0.19, 0.7)
	bottom_bar.add_theme_stylebox_override("panel", bar_style)
	parent.add_child(bottom_bar)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 20
	hbox.offset_right = -20
	bottom_bar.add_child(hbox)

	# Antialiasing — CYCLIC mode
	antialiasing_item = SettingItem.new("抗锯齿")
	antialiasing_item.set_mode(SettingItem.Mode.CYCLIC)
	antialiasing_item.set_options(["Off", "x2", "x4", "x8"])
	hbox.add_child(antialiasing_item)
	antialiasing_item.value_changed.connect(_on_setting_changed.bind("antialiasing"))

	# Quality — CYCLIC mode
	quality_item = SettingItem.new("画质等级")
	quality_item.set_mode(SettingItem.Mode.CYCLIC)
	quality_item.set_options(["低", "中", "高", "极高"])
	quality_item.set_value("中")
	hbox.add_child(quality_item)
	quality_item.value_changed.connect(_on_setting_changed.bind("quality"))

	# Latency — LATENCY mode
	latency_item = SettingItem.new("音画延迟")
	latency_item.set_mode(SettingItem.Mode.LATENCY)
	latency_item.set_range(0.0, 5.0, 0.01)
	latency_item.set_value(0.0)
	hbox.add_child(latency_item)
	latency_item.value_changed.connect(_on_setting_changed.bind("latency"))

	# Volume — RANGE mode
	volume_item = SettingItem.new("音量大小")
	volume_item.set_mode(SettingItem.Mode.RANGE)
	volume_item.set_range(0.0, 1.0, 0.1)
	volume_item.set_value(1.0)
	volume_item.set_suffix("%")
	hbox.add_child(volume_item)
	volume_item.value_changed.connect(_on_setting_changed.bind("volume"))

	# Separator
	var sep = Control.new()
	sep.custom_minimum_size = Vector2(16, 0)
	hbox.add_child(sep)

	# Shadow toggle
	shadow_toggle = CheckBoxItem.new("阴影")
	hbox.add_child(shadow_toggle)
	shadow_toggle.toggled.connect(_on_shadow_toggled)

	# Post-process toggle
	post_toggle = CheckBoxItem.new("后处理")
	hbox.add_child(post_toggle)
	post_toggle.toggled.connect(_on_post_toggled)

func _build_about_panel(parent: Control) -> void:
	about_panel = Panel.new()
	about_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	about_panel.visible = false
	about_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.6)
	about_panel.add_theme_stylebox_override("panel", overlay_style)
	parent.add_child(about_panel)

	# Content panel (centered)
	var content = Panel.new()
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(0.25, 0.25, 0.25)
	content_style.corner_radius_top_left = 8
	content_style.corner_radius_top_right = 8
	content_style.corner_radius_bottom_left = 8
	content_style.corner_radius_bottom_right = 8
	content.add_theme_stylebox_override("panel", content_style)
	about_panel.add_child(content)

	# Use a container for centering
	var center_ctrl = CenterContainer.new()
	center_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	about_panel.add_child(center_ctrl)
	center_ctrl.add_child(content)

	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(480, 300)
	content.add_child(vbox)

	var title_label = Label.new()
	title_label.name = "about_title"
	title_label.text = "关卡名称"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_label)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer1)

	var author_container = VBoxContainer.new()
	author_container.name = "about_authors"
	author_container.alignment = BOX_ALIGNMENT_CENTER
	vbox.add_child(author_container)

	var spacer2 = Control.new()
	spacer2.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(spacer2)

	var credits_label = Label.new()
	credits_label.name = "about_credits"
	credits_label.text = "基于冰焰模板 4.3.0 修改"
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(credits_label)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	vbox.add_child(close_btn)
	close_btn.pressed.connect(_on_about_close)

# === Public API ===

func show_ui() -> void:
	visible = true

func hide_animated() -> void:
	if not visible:
		return

	var tween = create_tween().set_parallel()

	if top_bar and is_instance_valid(top_bar):
		tween.tween_property(top_bar, "offset_top", -top_bar.size.y - 20, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(top_bar, "modulate:a", 0.0, 0.35)

	if center_card and is_instance_valid(center_card):
		var screen_h = get_viewport_rect().size.y
		tween.tween_property(center_card, "position:y", screen_h + 100, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(center_card, "modulate:a", 0.0, 0.35)

	if bottom_bar and is_instance_valid(bottom_bar):
		tween.tween_property(bottom_bar, "offset_top", get_viewport_rect().size.y + 20, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(bottom_bar, "modulate:a", 0.0, 0.35)

	if info_btn and is_instance_valid(info_btn):
		tween.tween_property(info_btn, "offset_left", -60, 0.35).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(info_btn, "modulate:a", 0.0, 0.35)

	if main_panel and is_instance_valid(main_panel):
		tween.tween_property(main_panel, "modulate:a", 0.0, 0.45)

	tween.finished.connect(_on_hide_finished)

func _on_hide_finished() -> void:
	queue_free()

func set_info_card(config: Dictionary) -> void:
	if config.has("title"):
		var title_node = center_card.find_child("about_title", true, false)
		if title_node is Label:
			title_node.text = config["title"]

func set_setting(key: String, value) -> void:
	match key:
		"antialiasing": antialiasing_item.set_value(value)
		"quality": quality_item.set_value(value)
		"latency": latency_item.set_value(value)
		"volume": volume_item.set_value(value)

func get_setting(key: String):
	match key:
		"antialiasing": return antialiasing_item.get_value()
		"quality": return quality_item.get_value()
		"latency": return latency_item.get_value()
		"volume": return volume_item.get_value()
	return null

func set_about_content(title: String, authors: Array, credits: String) -> void:
	var title_node = about_panel.find_child("about_title", true, false)
	if title_node is Label:
		title_node.text = title

	var author_container = about_panel.find_child("about_authors", true, false)
	if author_container:
		for child in author_container.get_children():
			child.queue_free()
		for author in authors:
			var lbl = Label.new()
			lbl.text = str(author)
			lbl.add_theme_font_size_override("font_size", 16)
			author_container.add_child(lbl)

	var credits_node = about_panel.find_child("about_credits", true, false)
	if credits_node is Label:
		credits_node.text = credits

# === Internal handlers ===

func _on_setting_changed(value, key: String) -> void:
	emit_signal("setting_changed", key, value)

func _on_info_pressed() -> void:
	emit_signal("info_button_pressed")
	_show_about()

func _on_autoplay_toggled(is_on: bool) -> void:
	emit_signal("autoplay_toggled", is_on)

func _on_shadow_toggled(is_on: bool) -> void:
	emit_signal("shadow_toggled", is_on)

func _on_post_toggled(is_on: bool) -> void:
	emit_signal("post_toggled", is_on)

func _show_about() -> void:
	if about_panel:
		about_panel.visible = true

func _on_about_close() -> void:
	if about_panel:
		about_panel.visible = false
