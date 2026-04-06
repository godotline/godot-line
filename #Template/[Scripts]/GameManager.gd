@tool
extends Node
class_name GameManager

@export_group("Node")
@export var Camera: Camera3D
@export var Mainline: CharacterBody3D
@export var factor:= 1

var camera_follower: Node3D:
	get:
		if Camera:
			return Camera.get_parent() as Node3D
		return null
@export_tool_button("Origin Pos","TransitionImmediateBig")

var origin_action = func():
	if Mainline:
			origin_pos = Mainline.global_position
			print("Origin position set to: ", origin_pos)
@export_tool_button("Get Origin Pos","PlayStart")
var get_origin_action = func():
	if Mainline:
			Mainline.global_position = origin_pos
			print("Origin position set to: ", origin_pos)

@export var origin_pos: Vector3

func calculate_anim_start_time() -> float:
	if not Mainline:
		return 0.0

	# 计算 2D 直线距离（忽略 Y 轴）
	var origin_2d = Vector2(origin_pos.x, origin_pos.z)
	var current_2d = Vector2(Mainline.global_position.x, Mainline.global_position.z)
	var moved_distance = origin_2d.distance_to(current_2d) * factor

	# 获取速度并确保为非负
	var actual_speed = Mainline.speed
	if actual_speed == 0:
		return 0.0  # 速度为零时，动画时间设为 0
	actual_speed = abs(actual_speed)  # 防止速度为负

	var anim_time = moved_distance / actual_speed
	return anim_time
