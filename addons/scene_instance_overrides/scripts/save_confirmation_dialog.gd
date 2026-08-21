@tool
extends Window

signal save_and_apply_requested
signal apply_without_saving_parent_requested
signal cancel_requested
signal dirty_parent_apply_behavior_changed(behavior: int)

const DIRTY_PARENT_APPLY_BEHAVIOR_LABELS := [
	"Ask every time",
	"Save Parent and Apply",
	"Apply to Base Only",
]
const WARNING_OUTLINE_WIDTH := 2
const WARNING_COLOR_FALLBACK := Color("e05f65")

@onready var _dirty_parent_apply_behavior_option: OptionButton = %DirtyParentApplyBehaviorOption
@onready var _apply_without_saving_parent_button: Button = %ApplyWithoutSavingParentButton

var _updating_controls := false


func _ready() -> void:
	for behavior_label: String in DIRTY_PARENT_APPLY_BEHAVIOR_LABELS:
		_dirty_parent_apply_behavior_option.add_item(behavior_label)
	_apply_warning_outline_to_dirty_parent_button()


func configure(property_entries_only: bool, dirty_parent_apply_behavior: int) -> void:
	_updating_controls = true
	_dirty_parent_apply_behavior_option.select(
		clampi(
			dirty_parent_apply_behavior,
			0,
			DIRTY_PARENT_APPLY_BEHAVIOR_LABELS.size() - 1
		)
	)
	_updating_controls = false
	_apply_without_saving_parent_button.disabled = not property_entries_only
	_apply_without_saving_parent_button.tooltip_text = (
		"Apply property overrides to the base scene while keeping the current parent scene unsaved."
		if property_entries_only
		else "Added-node overrides require Save and Apply because Godot cannot safely refresh them in an unsaved parent scene."
	)


func get_selected_dirty_parent_apply_behavior() -> int:
	return _dirty_parent_apply_behavior_option.selected


func is_apply_without_saving_parent_enabled() -> bool:
	return not _apply_without_saving_parent_button.disabled


func _apply_warning_outline_to_dirty_parent_button() -> void:
	var warning_color := WARNING_COLOR_FALLBACK
	if _apply_without_saving_parent_button.has_theme_color("error_color", "Editor"):
		warning_color = _apply_without_saving_parent_button.get_theme_color(
			"error_color",
			"Editor"
		)
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		_apply_without_saving_parent_button.add_theme_stylebox_override(
			style_name,
			_create_warning_outline_style(style_name, warning_color, 1.0)
		)
	_apply_without_saving_parent_button.add_theme_stylebox_override(
		"disabled",
		_create_warning_outline_style("disabled", warning_color, 0.35)
	)


func _create_warning_outline_style(
		style_name: StringName,
		warning_color: Color,
		outline_opacity: float
	) -> StyleBoxFlat:
	var source_style := _apply_without_saving_parent_button.get_theme_stylebox(
		style_name,
		"Button"
	)
	var outlined_style: StyleBoxFlat
	if source_style is StyleBoxFlat:
		outlined_style = source_style.duplicate() as StyleBoxFlat
	else:
		outlined_style = StyleBoxFlat.new()
		outlined_style.bg_color = Color(0.16, 0.16, 0.16, 1.0)
		outlined_style.content_margin_left = 8.0
		outlined_style.content_margin_top = 4.0
		outlined_style.content_margin_right = 8.0
		outlined_style.content_margin_bottom = 4.0
		outlined_style.corner_radius_top_left = 4
		outlined_style.corner_radius_top_right = 4
		outlined_style.corner_radius_bottom_right = 4
		outlined_style.corner_radius_bottom_left = 4
	outlined_style.border_width_left = WARNING_OUTLINE_WIDTH
	outlined_style.border_width_top = WARNING_OUTLINE_WIDTH
	outlined_style.border_width_right = WARNING_OUTLINE_WIDTH
	outlined_style.border_width_bottom = WARNING_OUTLINE_WIDTH
	outlined_style.border_color = Color(
		warning_color.r,
		warning_color.g,
		warning_color.b,
		warning_color.a * outline_opacity
	)
	return outlined_style


func _on_dirty_parent_apply_behavior_option_item_selected(index: int) -> void:
	if not _updating_controls:
		dirty_parent_apply_behavior_changed.emit(index)


func _on_save_and_apply_button_pressed() -> void:
	hide()
	save_and_apply_requested.emit()


func _on_apply_without_saving_parent_button_pressed() -> void:
	if _apply_without_saving_parent_button.disabled:
		return
	hide()
	apply_without_saving_parent_requested.emit()


func _on_cancel_requested() -> void:
	hide()
	cancel_requested.emit()
