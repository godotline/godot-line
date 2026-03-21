@tool
extends Node3D

# 对应 Unity 的 ActiveOffset 和 pivotOffset
@export var active_offset: bool = true
@export var pivot_offset: Vector3 = Vector3.ZERO

# 对应 Unity 的 ActiveRot 和 targetX/Y/Z
@export var active_rot: bool = true
@export var target_x: float = -45.0  # 对应 targetX
@export var target_y: float = 45.0   # 对应 targetY  
@export var target_z: float = 0.0    # 对应 targetZ

# 对应 Unity 的 TargetDistance
@export var target_distance: float = 20.0

# 对应 Unity 的 SmoothTime/needtime
@export var smooth_time: float = 1.0

# 过渡类型（保留原有功能）
@export var TransitionType: Tween.TransitionType = Tween.TRANS_SINE
@export var EaseType: Tween.EaseType = Tween.EASE_IN_OUT

@export var Camera: Camera3D
var preview_camera: Camera3D

# 计算属性：实时计算 end_pos（类似 Unity 中相机控制器的计算逻辑）
var end_pos: Vector3:
	get:
		return calculate_camera_position()
		
var end_rot: Vector3:
	get:
		return Vector3(target_x, target_y, target_z) if active_rot else Camera.global_rotation_degrees if Camera else Vector3.ZERO

func calculate_camera_position() -> Vector3:
	"""根据 pivot_offset 和 target_distance 计算相机目标位置（类似 Unity FollowCamera 逻辑）"""
	var pivot = global_position
	if active_offset:
		pivot += pivot_offset
	
	if not active_rot:
		# 如果不激活旋转，保持当前朝向，仅按距离偏移
		var current_dir = (Camera.global_position - pivot).normalized() if Camera else Vector3.BACK
		return pivot + current_dir * target_distance
	
	# 根据角度计算方向（Unity 风格的欧拉角转方向）
	var rotation_rad = Vector3(deg_to_rad(target_x), deg_to_rad(target_y), deg_to_rad(target_z))
	var basis = Basis.from_euler(rotation_rad)
	var direction = -basis.z  # 相机朝向 -Z 轴
	
	return pivot - direction * target_distance

#region 编辑器工具按钮
@export_tool_button("Create Preview Camera", "Camera")
var create_preview_action = func():
	if Engine.is_editor_hint():
		if not preview_camera:
			preview_camera = Camera3D.new()
			add_child(preview_camera)
			preview_camera.name = "PreviewCamera"
			preview_camera.owner = get_tree().edited_scene_root
			preview_camera.top_level = true
			update_preview_camera()
			preview_camera.current = true
			await get_tree().process_frame
			EditorInterface.edit_node(preview_camera)
			print("Preview camera created at calculated position")
		else:
			print("Preview camera already exists")

@export_tool_button("Get Preview Camera Transform", "TransitionEnd")
var get_preview_transform_action = func():
	if Engine.is_editor_hint() and preview_camera:
		# 反算参数（从预览相机位置反推 pivot_offset 或距离）
		var preview_pos = preview_camera.global_position
		var preview_rot = preview_camera.global_rotation_degrees
		
		if active_rot:
			target_x = preview_rot.x
			target_y = preview_rot.y
			target_z = preview_rot.z
			print("Updated rotation: ", end_rot)
		
		if active_offset:
			# 假设保持距离，反推 offset
			var current_pivot = global_position + pivot_offset
			var dir = (current_pivot - preview_pos).normalized()
			var new_pivot = preview_pos + dir * target_distance
			pivot_offset = new_pivot - global_position
			print("Updated pivot offset: ", pivot_offset)
			print("Target distance: ", target_distance)
		else:
			# 如果不使用 offset，则更新距离
			target_distance = (preview_pos - global_position).length()
			print("Updated target distance: ", target_distance)

@export_tool_button("Delete Preview Camera", "Remove")
var delete_preview_action = func():
	if Engine.is_editor_hint() and preview_camera:
		preview_camera.queue_free()
		preview_camera = null
		print("Preview camera deleted")

func update_preview_camera():
	"""更新预览相机到计算位置"""
	if preview_camera:
		preview_camera.global_position = end_pos
		preview_camera.global_rotation_degrees = end_rot
#endregion

signal on_animation_start
signal on_animation_end

func _on_body_entered(body: Node3D) -> void:
	# 对应 Unity 的 if (other.tag == "line")
	if body.is_in_group("line") or body.name.contains("line"):
		play_camera_transition()

func _ready() -> void:
	if not Engine.is_editor_hint():
		$MeshInstance3D.visible = false
		# 如果需要在运行时初始化相机到正确位置
		if Camera:
			Camera.global_position = end_pos
			Camera.global_rotation_degrees = end_rot

func play_camera_transition():
	"""执行相机过渡（对应 Unity 中设置 FollowCamera 参数后的平滑移动）"""
	on_animation_start.emit()
	
	var final_pos = calculate_camera_position()
	var final_rot = end_rot
	
	print("Changing camera to pos: ", final_pos, " rot: ", final_rot)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 位置过渡
	tween.tween_property(Camera, "global_position", final_pos, smooth_time)\
		.set_trans(TransitionType)\
		.set_ease(EaseType)
	
	# 旋转过渡  
	tween.tween_property(Camera, "global_rotation_degrees", final_rot, smooth_time)\
		.set_trans(TransitionType)\
		.set_ease(EaseType)
	
	tween.chain().tween_callback(func(): on_animation_end.emit())

# 编辑器中更新预览
func _process(_delta):
	if Engine.is_editor_hint() and preview_camera:
		update_preview_camera()
