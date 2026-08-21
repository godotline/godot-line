@tool
extends Window

signal show_child_node_button_changed(enabled: bool)
signal show_scene_dock_button_changed(enabled: bool)
signal dirty_parent_apply_behavior_changed(behavior: int)

const DIRTY_PARENT_APPLY_BEHAVIOR_LABELS := [
	"Ask every time",
	"Save Parent and Apply",
	"Apply to Base Only",
]

@onready var _show_child_node_button_check_box: CheckBox = %ShowChildNodeButtonCheckBox
@onready var _show_scene_dock_button_check_box: CheckBox = %ShowSceneDockButtonCheckBox
@onready var _dirty_parent_apply_behavior_option: OptionButton = %DirtyParentApplyBehaviorOption

var _updating_controls := false


func _ready() -> void:
	for behavior_label: String in DIRTY_PARENT_APPLY_BEHAVIOR_LABELS:
		_dirty_parent_apply_behavior_option.add_item(behavior_label)


func configure(
		show_child_node_button: bool,
		show_scene_dock_button: bool,
		dirty_parent_apply_behavior: int
	) -> void:
	_updating_controls = true
	_show_child_node_button_check_box.button_pressed = show_child_node_button
	_show_scene_dock_button_check_box.button_pressed = show_scene_dock_button
	_dirty_parent_apply_behavior_option.select(
		clampi(
			dirty_parent_apply_behavior,
			0,
			DIRTY_PARENT_APPLY_BEHAVIOR_LABELS.size() - 1
		)
	)
	_updating_controls = false


func _on_show_child_node_button_check_box_toggled(enabled: bool) -> void:
	if not _updating_controls:
		show_child_node_button_changed.emit(enabled)


func _on_show_scene_dock_button_check_box_toggled(enabled: bool) -> void:
	if not _updating_controls:
		show_scene_dock_button_changed.emit(enabled)


func _on_dirty_parent_apply_behavior_option_item_selected(index: int) -> void:
	if not _updating_controls:
		dirty_parent_apply_behavior_changed.emit(index)


func _on_close_requested() -> void:
	hide()


func _on_close_button_pressed() -> void:
	hide()
