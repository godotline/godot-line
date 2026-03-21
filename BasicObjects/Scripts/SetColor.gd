@tool
extends Area3D

@export var need_change_material: StandardMaterial3D:
	set(value):
		need_change_material = value
		if value and Engine.is_editor_hint():
			start_color = value.albedo_color
			notify_property_list_changed()

@export var start_color: Color = Color.WHITE
@export var end_color: Color = Color.WHITE
@export var duration: float = 1.0
@export var transition_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export_tool_button("预览播放")
var preview_play_action = func():
	if Engine.is_editor_hint() and need_change_material:
		play_color_change()
		await get_tree().create_timer(duration + 0.1).timeout
		need_change_material.albedo_color = start_color

@export_tool_button("预览停止")
var stop_action = func():
	if Engine.is_editor_hint() and need_change_material:
		need_change_material.albedo_color = start_color

signal on_color_change_start
signal on_color_change_end

func _ready() -> void:
	if not need_change_material:
		push_error("Need_Change_Material is not assigned!")
		return
	
	# 隐藏碰撞辅助线
	$MeshInstance3D.visible = false
	
	# 运行时：直接修改原资源设置初始色（会影响所有使用该材质的物体）
	if not Engine.is_editor_hint():
		need_change_material.albedo_color = start_color

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		print("OK")
		play_color_change()

func play_color_change() -> void:
	if not need_change_material:
		return
	
	on_color_change_start.emit()
	var tween = create_tween()
	tween.set_trans(transition_type)
	tween.set_ease(ease_type)
	# 直接修改原资源
	tween.tween_property(need_change_material, "albedo_color", end_color, duration)
	tween.tween_callback(func(): on_color_change_end.emit())
