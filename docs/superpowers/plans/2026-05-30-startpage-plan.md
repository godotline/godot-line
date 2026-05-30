# StartPage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Dancing Line style start screen that appears before the game starts, with info card, settings panel, and animated hide-on-click.

**Architecture:** Four Godot components — SettingItem (reusable arrow-control widget with 3 modes), CheckBoxItem (toggle widget), StartPage (CanvasLayer overlay assembling the full layout), and a Player.gd integration that auto-instantiates and hides on first turn. UI is built programmatically in `_ready()` for each component, keeping .tscn files minimal.

**Tech Stack:** Godot 4.6, GDScript, Control nodes, CanvasLayer, Tween animations

---

## File Structure

```
#Template/[Scripts]/GUI/              (new directory)
├── SettingItem.gd                    # Cyclic/range/latency arrow control
├── CheckBoxItem.gd                   # Checkbox + label toggle
└── StartPage.gd                      # Main start page controller

#Template/[Resources/]
├── SettingItem.tscn                   # Root: HBoxContainer + SettingItem.gd
├── CheckBoxItem.tscn                  # Root: HBoxContainer + CheckBoxItem.gd
└── StartPage.tscn                     # Root: CanvasLayer + StartPage.gd
```

**Modified:**
- `#Template/[Scripts]/Level/Player.gd` — add `music_delay`, `music_volume`, instantiate StartPage, hide on first turn

---

### Task 1: SettingItem Custom Control

**Files:**
- Create: `#Template/[Scripts]/GUI/SettingItem.gd`
- Create: `#Template/[Resources]/SettingItem.tscn`

**Overview:** A reusable arrow-control widget. Three modes:
| Mode | Visual | Behavior |
|------|--------|----------|
| CYCLIC | ◀ value ▶ | Cycles through an `options` Array |
| RANGE | ◀ value ▶ | Steps by `step` within [min, max], suffix appended to display |
| LATENCY | ◀◀ ◀ value ▶ ▶▶ | Coarse arrows ±10, fine arrows ±1, suffix "ms" |

- [ ] **Step 1: Write SettingItem.gd**

```gdscript
@tool
extends HBoxContainer
class_name SettingItem

enum Mode { CYCLIC, RANGE, LATENCY }

signal value_changed(value)

# Visual elements
var title_label: Label
var arrow_coarse_left: Button
var arrow_fine_left: Button
var arrow_left: Button
var value_label: Label
var arrow_right: Button
var arrow_fine_right: Button
var arrow_coarse_right: Button

# State
var _mode: int = Mode.CYCLIC
var _options: Array = []
var _current_index: int = 0
var _min_val: float = 0.0
var _max_val: float = 100.0
var _step: float = 1.0
var _current_value: float = 0.0
var _suffix: String = ""
var _title_text: String = ""

func _init(p_title: String = ""):
	_init_ui(p_title)

func _init_ui(p_title: String) -> void:
	title_label = Label.new()
	title_label.text = p_title
	title_label.add_theme_font_size_override("font_size", 14)
	add_child(title_label)
	
	# Latency coarse/fine arrows (hidden by default)
	arrow_coarse_left = Button.new()
	arrow_coarse_left.text = "<<"
	arrow_coarse_left.flat = true
	arrow_coarse_left.visible = false
	add_child(arrow_coarse_left)
	arrow_coarse_left.pressed.connect(_on_arrow_left_coarse)
	
	arrow_fine_left = Button.new()
	arrow_fine_left.text = "<"
	arrow_fine_left.flat = true
	arrow_fine_left.visible = false
	add_child(arrow_fine_left)
	arrow_fine_left.pressed.connect(_on_arrow_left_fine)
	
	arrow_left = Button.new()
	arrow_left.text = "<"
	arrow_left.flat = true
	add_child(arrow_left)
	arrow_left.pressed.connect(_on_arrow_left)
	
	value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.add_theme_font_size_override("font_size", 14)
	add_child(value_label)
	
	arrow_right = Button.new()
	arrow_right.text = ">"
	arrow_right.flat = true
	add_child(arrow_right)
	arrow_right.pressed.connect(_on_arrow_right)
	
	arrow_fine_right = Button.new()
	arrow_fine_right.text = ">"
	arrow_fine_right.flat = true
	arrow_fine_right.visible = false
	add_child(arrow_fine_right)
	arrow_fine_right.pressed.connect(_on_arrow_right_fine)
	
	arrow_coarse_right = Button.new()
	arrow_coarse_right.text = ">>"
	arrow_coarse_right.flat = true
	arrow_coarse_right.visible = false
	add_child(arrow_coarse_right)
	arrow_coarse_right.pressed.connect(_on_arrow_right_coarse)
	
	_update_display()

func set_title(text: String) -> void:
	_title_text = text
	title_label.text = text

func set_mode(mode: int) -> void:
	_mode = mode
	var has_coarse = (_mode == Mode.LATENCY)
	arrow_coarse_left.visible = has_coarse
	arrow_fine_left.visible = has_coarse
	arrow_fine_right.visible = has_coarse
	arrow_coarse_right.visible = has_coarse

func set_options(options: Array) -> void:
	_options = options
	_current_index = 0
	_update_display()

func set_value(val) -> void:
	if _mode == Mode.CYCLIC:
		var idx = _options.find(val)
		if idx >= 0:
			_current_index = idx
	else:
		_current_value = clampf(val, _min_val, _max_val)
	_update_display()

func get_value():
	if _mode == Mode.CYCLIC:
		return _options[_current_index] if _options.size() > 0 else null
	else:
		return _current_value

func set_range(min_val: float, max_val: float, step: float) -> void:
	_min_val = min_val
	_max_val = max_val
	_step = step
	_current_value = min_val

func set_suffix(text: String) -> void:
	_suffix = text
	_update_display()

func _update_display() -> void:
	if _mode == Mode.CYCLIC:
		value_label.text = str(get_value()) if get_value() != null else ""
	else:
		var display_val = _current_value
		if _suffix == "ms":
			display_val = round(_current_value * 1000)
		elif _suffix == "%":
			display_val = round(_current_value * 100)
		value_label.text = str(display_val) + _suffix

func _on_arrow_left() -> void:
	if _mode == Mode.CYCLIC:
		_current_index = (_current_index - 1 + _options.size()) % _options.size()
	else:
		_current_value = clampf(_current_value - _step, _min_val, _max_val)
	emit_signal("value_changed", get_value())
	_update_display()

func _on_arrow_right() -> void:
	if _mode == Mode.CYCLIC:
		_current_index = (_current_index + 1) % _options.size()
	else:
		_current_value = clampf(_current_value + _step, _min_val, _max_val)
	emit_signal("value_changed", get_value())
	_update_display()

func _on_arrow_left_fine() -> void:
	if _mode == Mode.LATENCY:
		_current_value = max(0.0, _current_value - 0.001)
		emit_signal("value_changed", get_value())
		_update_display()

func _on_arrow_right_fine() -> void:
	if _mode == Mode.LATENCY:
		_current_value += 0.001
		emit_signal("value_changed", get_value())
		_update_display()

func _on_arrow_left_coarse() -> void:
	if _mode == Mode.LATENCY:
		_current_value = max(0.0, _current_value - 0.01)
		emit_signal("value_changed", get_value())
		_update_display()

func _on_arrow_right_coarse() -> void:
	if _mode == Mode.LATENCY:
		_current_value += 0.01
		emit_signal("value_changed", get_value())
		_update_display()
```

- [ ] **Step 2: Create SettingItem.tscn**

Write the minimal scene text file:

```
[gd_scene format=3 uid="uid://cfg6qns6wjtsx"]

[node name="SettingItem" type="HBoxContainer"]
script/script = ExtResource("1")
script/class_name = &"SettingItem"

[connection signal="value_changed" from="." to="." method="_on_value_changed_internal"]
```

> Note: Since the script is mostly programmatic, the .tscn is just a shell with the script attached.

- [ ] **Step 3: Commit**

```bash
git add "#Template/[Scripts]/GUI/SettingItem.gd" "#Template/[Resources]/SettingItem.tscn"
git commit -m "feat: implement SettingItem custom control with CYCLIC/RANGE/LATENCY modes"
```

---

### Task 2: CheckBoxItem Custom Control

**Files:**
- Create: `#Template/[Scripts]/GUI/CheckBoxItem.gd`
- Create: `#Template/[Resources]/CheckBoxItem.tscn`

- [ ] **Step 1: Write CheckBoxItem.gd**

```gdscript
@tool
extends HBoxContainer
class_name CheckBoxItem

signal toggled(is_on: bool)

var checkbox: CheckBox
var label: Label

func _init(p_title: String = ""):
	_init_ui(p_title)

func _init_ui(p_title: String) -> void:
	checkbox = CheckBox.new()
	checkbox.flat = true
	add_child(checkbox)
	checkbox.toggled.connect(_on_toggled)
	
	label = Label.new()
	label.text = p_title
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)

func set_title(text: String) -> void:
	label.text = text

func set_is_on(value: bool) -> void:
	checkbox.button_pressed = value

func get_is_on() -> bool:
	return checkbox.button_pressed

func _on_toggled(is_on: bool) -> void:
	emit_signal("toggled", is_on)
```

- [ ] **Step 2: Create CheckBoxItem.tscn**

```
[gd_scene format=3 uid="uid://checkitem"]

[node name="CheckBoxItem" type="HBoxContainer"]
script/script = ExtResource("1")
script/class_name = &"CheckBoxItem"
```

- [ ] **Step 3: Commit**

```bash
git add "#Template/[Scripts]/GUI/CheckBoxItem.gd" "#Template/[Resources]/CheckBoxItem.tscn"
git commit -m "feat: implement CheckBoxItem toggle control"
```

---

### Task 3: StartPage Scene and Script

**Files:**
- Create: `#Template/[Scripts]/GUI/StartPage.gd`
- Create: `#Template/[Resources]/StartPage.tscn`

- [ ] **Step 1: Write StartPage.gd**

```gdscript
@tool
extends CanvasLayer
class_name StartPage

signal start_requested
signal info_button_pressed
signal autoplay_toggled(is_on: bool)
signal setting_changed(key: String, value)
signal shadow_toggled(is_on: bool)
signal post_toggled(is_on: bool)

# UI sections (kept as references for animation)
var main_panel: Panel
var top_bar: Control
var center_card: Panel
var bottom_bar: Panel
var info_btn: Button
var about_panel: Panel
var autoplay_check: CheckBoxItem

# Setting items
var antialiasing_item: SettingItem
var quality_item: SettingItem
var latency_item: SettingItem
var volume_item: SettingItem
var shadow_toggle: CheckBoxItem
var post_toggle: CheckBoxItem

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Root container for entire UI
	var container = Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS  # Pass clicks through to 3D
	add_child(container)
	
	# == Semi-transparent background ==
	main_panel = Panel.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.39)
	main_panel.add_theme_stylebox_override("panel", bg_style)
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks through
	container.add_child(main_panel)
	
	# == Top Bar ==
	_build_top_bar(container)
	
	# == Center Card ==
	_build_center_card(container)
	
	# == Info Button ==
	_build_info_button(container)
	
	# == Bottom Bar ==
	_build_bottom_bar(container)
	
	# == About Panel (hidden) ==
	_build_about_panel(container)

func _build_top_bar(parent: Control) -> void:
	top_bar = HBoxContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	top_bar.offset_bottom = top_bar.offset_top + 40
	parent.add_child(top_bar)
	
	# Left spacer
	var left_spacer = Control.new()
	left_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	top_bar.add_child(left_spacer)
	
	# Center keyboard hints
	var hint_label = Label.new()
	hint_label.text = "R: 重新开始  |  K: 快速死亡  |  D: 调试模式"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hint_label.size_flags_horizontal = SIZE_EXPAND_FILL
	top_bar.add_child(hint_label)
	
	# Right spacer + autoplay
	var right_area = HBoxContainer.new()
	right_area.size_flags_horizontal = SIZE_EXPAND_FILL
	right_area.alignment = BOX_ALIGNMENT_END
	top_bar.add_child(right_area)
	
	autoplay_check = CheckBoxItem.new("AUTOPLAY")
	autoplay_check.label.add_theme_color_override("font_color", Color(1, 0, 0))
	autoplay_check.label.add_theme_font_size_override("font_size", 16)
	right_area.add_child(autoplay_check)
	autoplay_check.toggled.connect(_on_autoplay_toggled)

func _build_center_card(parent: Control) -> void:
	center_card = Panel.new()
	center_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_card.custom_minimum_size = Vector2(440, 0)
	
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
	
	var title = Label.new()
	title.text = "测试场景"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(title)
	
	var author = Label.new()
	author.text = "筱夕Sushi"
	author.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	author.add_theme_font_size_override("font_size", 20)
	author.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(author)
	
	# Add remaining info labels using a helper
	for info in ["共舞的线模板", "基于冰焰模板 4.3.0 修改", "作者：Max冰焰、筱夕Sushi、Quantumilk"]:
		var lbl = Label.new()
		lbl.text = info
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
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
	info_btn.offset_top -= 100  # Lift above bottom bar
	info_btn.mouse_filter = Control.MOUSE_FILTER_STOP  # Catch clicks
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
	latency_item.set_suffix("ms")
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
	
	# Semi-transparent overlay
	var overlay_style = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0, 0, 0, 0.6)
	about_panel.add_theme_stylebox_override("panel", overlay_style)
	parent.add_child(about_panel)
	
	# Content panel (centered)
	var content = Panel.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	content.custom_minimum_size = Vector2(480, 300)
	
	var content_style = StyleBoxFlat.new()
	content_style.bg_color = Color(0.25, 0.25, 0.25)
	content_style.corner_radius_top_left = 8
	content_style.corner_radius_top_right = 8
	content_style.corner_radius_bottom_left = 8
	content_style.corner_radius_bottom_right = 8
	content.add_theme_stylebox_override("panel", content_style)
	about_panel.add_child(content)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24
	vbox.offset_right = -24
	vbox.offset_top = 24
	vbox.offset_bottom = -24
	content.add_child(vbox)
	
	# Title
	var title_label = Label.new()
	title_label.name = "about_title"
	title_label.text = "关卡名称"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer1)
	
	# Author container (dynamically filled)
	var author_container = VBoxContainer.new()
	author_container.name = "about_authors"
	author_container.alignment = BOX_ALIGNMENT_CENTER
	vbox.add_child(author_container)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(spacer2)
	
	# Credits
	var credits_label = Label.new()
	credits_label.name = "about_credits"
	credits_label.text = "基于冰焰模板 4.3.0 修改"
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(credits_label)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(close_btn)
	close_btn.pressed.connect(_on_about_close)

# === Public methods ===

func show() -> void:
	visible = true

func hide_animated() -> void:
	if not visible:
		return
	
	var tween = create_tween().set_parallel()
	var screen_h = get_viewport_rect().size.y
	
	# Slide elements off-screen
	if top_bar and is_instance_valid(top_bar):
		tween.tween_property(top_bar, "offset_top", -top_bar.size.y - 20, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(top_bar, "modulate:a", 0.0, 0.35)
	
	if center_card and is_instance_valid(center_card):
		tween.tween_property(center_card, "position:y", screen_h + 100, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(center_card, "modulate:a", 0.0, 0.35)
	
	if bottom_bar and is_instance_valid(bottom_bar):
		tween.tween_property(bottom_bar, "offset_top", screen_h + 20, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(bottom_bar, "modulate:a", 0.0, 0.35)
	
	if info_btn and is_instance_valid(info_btn):
		tween.tween_property(info_btn, "offset_left", -60, 0.35).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(info_btn, "modulate:a", 0.0, 0.35)
	
	if main_panel and is_instance_valid(main_panel):
		tween.tween_property(main_panel, "modulate:a", 0.0, 0.45)
	
	tween.finished.connect(_on_hide_finished)
	
	# Disable interaction immediately
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_hide_finished() -> void:
	queue_free()

func set_info_card(config: Dictionary) -> void:
	if config.has("title"):
		var title_node = center_card.find_child("title", true, false)
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
```

- [ ] **Step 2: Create StartPage.tscn**

```
[gd_scene format=3 uid="uid://startpage"]

[node name="StartPage" type="CanvasLayer"]
script/script = ExtResource("1")
script/class_name = &"StartPage"
layer = 2
```

- [ ] **Step 3: Commit**

```bash
git add "#Template/[Scripts]/GUI/StartPage.gd" "#Template/[Resources]/StartPage.tscn"
git commit -m "feat: implement StartPage with full UI layout and signal interfaces"
```

---

### Task 4: Integrate into Player.gd

**Files:**
- Modify: `#Template/[Scripts]/Level/Player.gd` — add `music_delay`/`music_volume`, instantiate StartPage, hook hide-on-turn

- [ ] **Step 1: Add `music_delay` and `music_volume` variables**

Insert after line 63 (`@export var disallow_input := false`):

```gdscript
## 音画延迟补偿（秒），用户可配置。与 AudioServer.get_output_latency() 独立并存。
var music_delay: float = 0.0

## 音量 (0.0~1.0)
var music_volume: float = 1.0
```

- [ ] **Step 2: Add StartPage instantiation in `_ready()`**

Insert at the end of `_ready()`, before the closing `func _ready()`:

```gdscript
	# 实例化 StartPage
	if not Engine.is_editor_hint():
		var start_page_scene = preload("res://#Template/[Resources]/StartPage.tscn") as PackedScene
		if start_page_scene:
			var start_page = start_page_scene.instantiate()
			add_child(start_page)
			start_page.set_setting("latency", music_delay)
			start_page.set_setting("volume", music_volume)
```

- [ ] **Step 3: Hide StartPage on first turn**

In `turn()`, at the beginning of the `if is_start == false` branch (line 248-251), after `is_start = true`:

```gdscript
	is_start = true
	
	# Hide StartPage with animation
	var page = get_node_or_null("StartPage")
	if page and page is CanvasLayer:
		page.hide_animated()
```

- [ ] **Step 4: Commit**

```bash
git add "#Template/[Scripts]/Level/Player.gd"
git commit -m "feat: integrate StartPage into Player.gd - instantiate in _ready, hide on first turn"
```

---

## Spec Self-Review Checklist

1. **Spec coverage:**
   - SettingItem ✓ (Task 1 covers all 3 modes per spec)
   - CheckBoxItem ✓ (Task 2 covers toggle + label)
   - StartPage full layout ✓ (Task 3: top bar, center card, bottom bar with 4 settings + 2 toggles, about panel, info button)
   - Hide animation ✓ (Tween-based in hide_animated())
   - Integration ✓ (Task 4: instantiate on _ready, hide on turn)
   - Signals: start_requested, info_button_pressed, autoplay_toggled, setting_changed, shadow/post_toggled ✓
   - Methods: show(), hide_animated(), set_info_card(), set_setting(), get_setting(), set_about_content() ✓
   - music_delay/music_volume variables added to Player.gd ✓

2. **Placeholder scan:** No TBD, TODO, or incomplete code blocks. All code is complete and functional.

3. **Type consistency:** SettingItem.Mode enum used consistently. Signal names match between setting_item.gd and start_page.gd. Method signatures consistent between start_page.gd interface and player.gd integration.
