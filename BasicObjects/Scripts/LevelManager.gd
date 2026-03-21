@tool
extends Node
class_name LevelManager

@export_group("Color")
@export var MainlineColor := Color(1,1,1): set = setlinecolor,get = getlinecolor
@export var FogColor := Color(1,1,1): set = setfogcolor,get = getfogcolor
@export_group("Node")
@export var Mainline: CharacterBody3D
@export var Camera: Camera3D
@export var factor:= 1.415
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

	# 应该计算角色已经移动的距离，而不是到原点的距离
	var origin_2d = Vector2(origin_pos.x, origin_pos.z)
	var current_2d = Vector2(Mainline.global_position.x,
	Mainline.global_position.z)
	var moved_distance = origin_2d.distance_to(current_2d) * factor

	# 或者如果你想要反向计算：
	# var remaining_distance =
	Mainline.global_position.distance_to(origin_pos)
	# var moved_distance = (total_path_length - remaining_distance) * 1.39

	var actual_speed = Mainline.speed
	var anim_time = moved_distance / actual_speed

	return anim_time
func setlinecolor(color):
	if Mainline and Mainline.has_method("set_color"):
		Mainline.call("set_color", color)
func getlinecolor() -> Color:
	if Mainline and Mainline.has_method("get_color"):
		return Mainline.call("get_color")
	return Color(1, 1, 1, 1)
func setfogcolor(color):
	if Engine.is_editor_hint() and Camera:
		Camera.get_environment().fog_light_color = color
func getfogcolor() -> Color:
	if Engine.is_editor_hint() and Camera:
		return Camera.get_environment().fog_light_color
	return Color(1, 1, 1, 1)
