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
var _mode: Mode = Mode.CYCLIC
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

func set_mode(mode: Mode) -> void:
	_mode = mode
	var is_latency = (_mode == Mode.LATENCY)
	arrow_coarse_left.visible = is_latency
	arrow_fine_left.visible = is_latency
	arrow_fine_right.visible = is_latency
	arrow_coarse_right.visible = is_latency
	# In LATENCY mode, fine arrows replace the regular arrows
	arrow_left.visible = not is_latency
	arrow_right.visible = not is_latency
	if is_latency and _suffix == "":
		_suffix = "ms"
	_update_display()

func set_options(options: Array) -> void:
	_options = options
	_current_index = 0
	_update_display()

func set_value(val) -> void:
	if _mode == Mode.CYCLIC:
		var idx = _options.find(val)
		if idx >= 0:
			_current_index = idx
		elif _options.size() > 0:
			push_warning("SettingItem.set_value: value '%s' not found in options, keeping current" % str(val))
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
		if _options.size() == 0:
			return
		_current_index = (_current_index - 1 + _options.size()) % _options.size()
	else:
		_current_value = clampf(_current_value - _step, _min_val, _max_val)
	emit_signal("value_changed", get_value())
	_update_display()

func _on_arrow_right() -> void:
	if _mode == Mode.CYCLIC:
		if _options.size() == 0:
			return
		_current_index = (_current_index + 1) % _options.size()
	else:
		_current_value = clampf(_current_value + _step, _min_val, _max_val)
	emit_signal("value_changed", get_value())
	_update_display()

func _on_arrow_left_fine() -> void:
	if _mode == Mode.LATENCY:
		_current_value = max(_min_val, _current_value - 0.001)
		emit_signal("value_changed", get_value())
		_update_display()

func _on_arrow_right_fine() -> void:
	if _mode == Mode.LATENCY:
		_current_value = min(_max_val, _current_value + 0.001)
		emit_signal("value_changed", get_value())
		_update_display()

func _on_arrow_left_coarse() -> void:
	if _mode == Mode.LATENCY:
		_current_value = max(_min_val, _current_value - 0.01)
		emit_signal("value_changed", get_value())
		_update_display()

func _on_arrow_right_coarse() -> void:
	if _mode == Mode.LATENCY:
		_current_value = min(_max_val, _current_value + 0.01)
		emit_signal("value_changed", get_value())
		_update_display()
