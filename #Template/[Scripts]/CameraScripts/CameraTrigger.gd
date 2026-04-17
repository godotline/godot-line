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
@export var TransitionType: Tween.TransitionType = Tween.TRANS_SINE
@export var EaseType: Tween.EaseType = Tween.EASE_IN_OUT
@export var need_time: float = 1.0
@export_group("时间判定")
@export var use_time: bool = false
@export var trigger_time: float = 0.0

var camera_follower: Node3D = null
var _tween: Tween = null

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
	if body is CharacterBody3D:
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
	
	if _tween:
		_tween.kill()
	if cf._tween:
		cf._tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(TransitionType).set_ease(EaseType)
	cf._tween = _tween
	
	if active_position:
		_tween.tween_property(cf, "add_position", new_add_position, need_time)
		cf._target_add_position = new_add_position
	
	if active_rotate:
		cf._current_rotate_mode = rotate_mode
		cf._start_rotation = cf.rotation_degrees
		cf._base_rotation = cf.rotation_degrees
		match rotate_mode:
			RotateMode.Fast:
				cf._target_rotation = cf._normalize_rotation_shortest(cf._start_rotation, new_rotation)
			RotateMode.FastBeyond360:
				cf._target_rotation = new_rotation
			RotateMode.WorldAxisAdd, RotateMode.LocalAxisAdd:
				cf._target_rotation = cf._start_rotation + new_rotation
		cf.rotation_offset = new_rotation
		cf._is_rotating = false
		if rotate_mode == RotateMode.Fast:
			var start_rot: Vector3 = cf.rotation_degrees
			_tween.tween_method(func(w: float) -> void:
				cf.rotation_degrees = Vector3(
					rad_to_deg(lerp_angle(deg_to_rad(start_rot.x), deg_to_rad(cf._target_rotation.x), w)),
					rad_to_deg(lerp_angle(deg_to_rad(start_rot.y), deg_to_rad(cf._target_rotation.y), w)),
					rad_to_deg(lerp_angle(deg_to_rad(start_rot.z), deg_to_rad(cf._target_rotation.z), w)),
				)
			, 0.0, 1.0, need_time)
		else:
			_tween.tween_property(cf, "rotation_degrees", cf._target_rotation, need_time)
	
	if active_distance:
		_tween.tween_property(cf, "distance_from_object", new_distance, need_time)
		cf._target_distance = new_distance
	
	if active_speed:
		_tween.tween_property(cf, "follow_speed", new_follow_speed, need_time)
		cf._target_follow_speed = new_follow_speed
