@tool
extends MarginContainer

signal popup_requested(anchor_control: Control)

const OVERRIDE_ICON := preload("res://addons/scene_instance_overrides/icons/scene_instance_overrides.svg")

@onready var _overrides_button: Button = %OverridesButton

var _entry_count := 0


func _ready() -> void:
	_refresh_button()


func configure(context: Dictionary) -> void:
	var entries: Variant = context.get("entries", [])
	_entry_count = entries.size() if entries is Array else 0
	if is_node_ready():
		_refresh_button()


func get_override_icon_for_test() -> Texture2D:
	return _overrides_button.icon


func get_override_icon_fallback_for_test() -> String:
	return ""


func _refresh_button() -> void:
	visible = _entry_count > 0
	_overrides_button.icon = OVERRIDE_ICON
	_overrides_button.text = "Overrides (%d)    ▾" % _entry_count
	_overrides_button.tooltip_text = (
		"Review %d changes that differ from the base scene."
		% _entry_count
	)
	_overrides_button.disabled = _entry_count <= 0


func _on_overrides_button_pressed() -> void:
	popup_requested.emit(_overrides_button)
