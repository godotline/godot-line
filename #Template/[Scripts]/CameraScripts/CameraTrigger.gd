extends Area3D

@export var active_position: bool = true
@export var new_add_position: Vector3 = Vector3.ZERO
@export var active_rotate: bool = true
@export var new_rotation: Vector3 = Vector3(45, 45, 0)
@export var active_distance: bool = true
@export var new_distance: float = 25.0
@export var active_speed: bool = true
@export var new_follow_speed: float = 1.2
enum RotateMode {
	Fast,           # 最短路径旋转
	FastBeyond360,  # 允许超过360度的旋转
	WorldAxisAdd,   # 世界坐标系 - 基于当前旋转增加
	LocalAxisAdd    # 本地坐标系 - 基于当前旋转增加
}
@export var rotate_mode: RotateMode = RotateMode.Fast
@export_group("时间判定")
@export var use_time: bool = false
@export var trigger_time: float = 0.0

var camera_follower: Node3D = null

func _get_camera_follower() -> Node3D:
	if camera_follower != null:
		return camera_follower
	var game_manager := get_tree().current_scene as GameManager
	if game_manager:
		camera_follower = game_manager.camera_follower
		return camera_follower
	return null

var triggered: bool = false
var triggered_at_crown: bool = false

func _ready() -> void:
	pass

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("mainline") or body.name == "MainLine":
		if not use_time:
			_trigger()

func _process(_delta: float) -> void:
	if use_time and not triggered:
		var current_time = 0.0
		var cf = _get_camera_follower()
		if cf and cf.player_node:
			var main_line = cf.player_node
			if main_line.animation_node:
				current_time = main_line.animation_node.current_animation_position
		
		if current_time >= trigger_time:
			_trigger()

func _trigger() -> void:
	var cf = _get_camera_follower()
	if not cf:
		return
	
	triggered = true
	
	if active_position:
		cf.add_position = new_add_position
	
	if active_rotate:
		cf.DORotateOffset(new_rotation, rotate_mode)
	
	if active_distance:
		cf.distance_from_object = new_distance
	
	if active_speed:
		cf.follow_speed = new_follow_speed
