@tool
extends Node3D

@export var end_rot = Vector3(-45,45,0)
@export var end_pos = Vector3(5,5,5)
@export var duration = 1.0
@export var TransitionType: Tween.TransitionType = Tween.TRANS_SINE
@export var EaseType: Tween.EaseType = Tween.EASE_IN_OUT

var preview_camera: Camera3D

@export_tool_button("Create Preview Camera","Camera")
var create_preview_action = func():
	if Engine.is_editor_hint():
		if not preview_camera:
			preview_camera = Camera3D.new()
			add_child(preview_camera)
			preview_camera.name = "PreviewCamera"
			preview_camera.owner = get_tree().edited_scene_root
			
			# 设置为top_level,使其不受父节点transform影响
			preview_camera.top_level = true
			
			# 转换到全局坐标
			preview_camera.global_position = global_position + end_pos
			preview_camera.global_rotation_degrees = global_rotation_degrees + end_rot
			
			preview_camera.current = true
			
			# 自动选中预览相机 防止报错
			await get_tree().process_frame
			EditorInterface.edit_node(preview_camera)

			print("Preview camera created and selected")
		else:
			print("Preview camera already exists")

@export_tool_button("Get Preview Camera Transform","TransitionEnd")
var get_preview_transform_action = func():
	if Engine.is_editor_hint() and preview_camera:
		# 从全局坐标转换为相对坐标
		end_pos = preview_camera.global_position - global_position
		end_rot = preview_camera.global_rotation_degrees - global_rotation_degrees
		print("Position: ", end_pos)
		print("Rotation: ", end_rot)

@export_tool_button("Delete Preview Camera","Remove")
var delete_preview_action = func():
	if Engine.is_editor_hint() and preview_camera:
		preview_camera.queue_free()
		preview_camera = null
		print("Preview camera deleted")

var level_manager
var Camera

signal on_animation_start
signal on_animation_end

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		play_()
		
func _ready() -> void:
	if not Engine.is_editor_hint():
		$MeshInstance3D.visible = false

func play_():
	level_manager = get_tree().current_scene
	Camera = level_manager.Camera
	on_animation_start.emit()
	var tween = create_tween()
	tween.parallel().tween_property(Camera,"position",end_pos,duration).set_trans(TransitionType).set_ease(EaseType)
	tween.parallel().tween_property(Camera,"rotation_degrees",end_rot,duration).set_trans(TransitionType).set_ease(EaseType)
	tween.tween_callback(func(): on_animation_end.emit())
