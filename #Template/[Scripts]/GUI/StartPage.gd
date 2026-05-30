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
@onready var center_card: Panel = $UIContainer/CenterCard
@onready var info_btn: Button = $UIContainer/InfoButton
@onready var bottom_bar: Panel = $UIContainer/BottomBar
@onready var about_panel: Panel = $UIContainer/AboutPanel
@onready var autoplay_check: CheckBoxItem = $UIContainer/TopBar/RightArea/AutoPlayToggle
@onready var antialiasing_item: SettingItem = $UIContainer/BottomBar/HBox/AntiAliasingItem
@onready var quality_item: SettingItem = $UIContainer/BottomBar/HBox/QualityItem
@onready var latency_item: SettingItem = $UIContainer/BottomBar/HBox/LatencyItem
@onready var volume_item: SettingItem = $UIContainer/BottomBar/HBox/VolumeItem
@onready var shadow_toggle: CheckBoxItem = $UIContainer/BottomBar/HBox/ShadowToggle
@onready var post_toggle: CheckBoxItem = $UIContainer/BottomBar/HBox/PostToggle

func _ready() -> void:
	antialiasing_item.set_title("抗锯齿")
	antialiasing_item.set_mode(SettingItem.Mode.CYCLIC)
	antialiasing_item.set_options(["Off", "x2", "x4", "x8"])

	quality_item.set_title("画质等级")
	quality_item.set_mode(SettingItem.Mode.CYCLIC)
	quality_item.set_options(["低", "中", "高", "极高"])
	quality_item.set_value("中")

	latency_item.set_title("音画延迟")
	latency_item.set_mode(SettingItem.Mode.LATENCY)
	latency_item.set_range(0.0, 5.0, 0.01)
	latency_item.set_value(0.0)

	volume_item.set_title("音量大小")
	volume_item.set_mode(SettingItem.Mode.RANGE)
	volume_item.set_range(0.0, 1.0, 0.1)
	volume_item.set_value(1.0)
	volume_item.set_suffix("%")

	autoplay_check.set_title("AUTOPLAY")
	autoplay_check.label.add_theme_color_override("font_color", Color(1, 0, 0))
	autoplay_check.label.add_theme_font_size_override("font_size", 16)

	antialiasing_item.value_changed.connect(_on_setting_changed.bind("antialiasing"))
	quality_item.value_changed.connect(_on_setting_changed.bind("quality"))
	latency_item.value_changed.connect(_on_setting_changed.bind("latency"))
	volume_item.value_changed.connect(_on_setting_changed.bind("volume"))
	autoplay_check.toggled.connect(_on_autoplay_toggled)
	shadow_toggle.toggled.connect(_on_shadow_toggled)
	post_toggle.toggled.connect(_on_post_toggled)
	info_btn.pressed.connect(_on_info_pressed)

# === Background click ===

func _on_background_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_requested.emit()

# === Public API ===

func show_ui() -> void:
	visible = true

func hide_animated() -> void:
	if not visible:
		return

	_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tween = create_tween().set_parallel()

	if top_bar and is_instance_valid(top_bar):
		tween.tween_property(top_bar, "offset_top", -top_bar.size.y - 20, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(top_bar, "modulate:a", 0.0, 0.35)

	if center_card and is_instance_valid(center_card):
		var screen_h = get_viewport().get_visible_rect().size.y
		tween.tween_property(center_card, "position:y", screen_h + 100, 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(center_card, "modulate:a", 0.0, 0.35)

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

func set_info_card(config: Dictionary) -> void:
	if config.has("title"):
		var title_node = center_card.find_child("center_title", true)
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
	var title_node = about_panel.find_child("about_title", true)
	if title_node is Label:
		title_node.text = title

	var author_container = about_panel.find_child("about_authors", true)
	if author_container:
		for child in author_container.get_children():
			child.queue_free()
		for author in authors:
			var lbl = Label.new()
			lbl.text = str(author)
			lbl.add_theme_font_size_override("font_size", 16)
			author_container.add_child(lbl)

	var credits_node = about_panel.find_child("about_credits", true)
	if credits_node is Label:
		credits_node.text = credits

# === Internal handlers ===

func _on_setting_changed(value, key: String) -> void:
	setting_changed.emit(key, value)

func _on_info_pressed() -> void:
	info_button_pressed.emit()
	_show_about()

func _on_autoplay_toggled(is_on: bool) -> void:
	autoplay_toggled.emit(is_on)

func _on_shadow_toggled(is_on: bool) -> void:
	shadow_toggled.emit(is_on)

func _on_post_toggled(is_on: bool) -> void:
	post_toggled.emit(is_on)

func _show_about() -> void:
	if about_panel:
		about_panel.visible = true

func _on_about_close() -> void:
	if about_panel:
		about_panel.visible = false
