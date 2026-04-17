extends Node3D

enum RotateMode {
	Fast,           # 最短路径旋转
	FastBeyond360,  # 允许超过360度的旋转
	WorldAxisAdd,   # 世界坐标系 - 基于当前旋转增加
	LocalAxisAdd    # 本地坐标系 - 基于当前旋转增加
}

@export var player: NodePath
@export var add_position: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3(45, 45, 0)
@export var distance_from_object: float = 25.0
@export var follow_speed: float = 1.2
@export var following: bool = true

@onready var line: Node3D = get_node(player) if player else null
@onready var camera: Node3D = get_child(0) if get_child_count() > 0 else null

var _checkpoint_applied := false

## Tween 状态
var _tween: Tween = null
var _current_rotate_mode: RotateMode = RotateMode.Fast
var _target_rotation: Vector3 = Vector3.ZERO
var _start_rotation: Vector3 = Vector3.ZERO
var _rotation_progress: float = 0.0
var _is_rotating: bool = false
var _base_rotation: Vector3 = Vector3.ZERO
var _target_add_position: Vector3
var _target_follow_speed: float
var _target_distance: float
var _pending_resume: bool = false

func _ready() -> void:
	_target_add_position = add_position
	_target_follow_speed = follow_speed
	_target_distance = distance_from_object
	if not camera and get_child_count() > 0:
		camera = get_child(0)
	if State.camera_checkpoint.has_checkpoint and State.camera_checkpoint.restore_pending:
		_apply_state_checkpoint()

func _process(delta: float) -> void:
	if State.camera_checkpoint.has_checkpoint and State.camera_checkpoint.restore_pending and not _checkpoint_applied:
		_apply_state_checkpoint()
	if following and line and ("is_start" not in line or line.is_start):
		if _pending_resume:
			_resume_tweens()
		var base_transform = line.position + add_position
		position = position.slerp(base_transform, abs(follow_speed * delta))
		
		if _tween and _tween.is_running():
			pass
		elif _is_rotating:
			_rotation_progress = min(_rotation_progress + abs(follow_speed * delta), 1.0)
			var current_target = _calculate_target_rotation()
			rotation_degrees = _apply_rotate_mode(_start_rotation, current_target, _rotation_progress)
			if _rotation_progress >= 1.0:
				_is_rotating = false
		else:
			# 正常跟随模式
			var target_rot = _get_target_rotation()
			rotation_degrees = Vector3(
				rad_to_deg(lerp_angle(deg_to_rad(rotation_degrees.x), deg_to_rad(target_rot.x), abs(follow_speed * delta))),
				rad_to_deg(lerp_angle(deg_to_rad(rotation_degrees.y), deg_to_rad(target_rot.y), abs(follow_speed * delta))),
				rad_to_deg(lerp_angle(deg_to_rad(rotation_degrees.z), deg_to_rad(target_rot.z), abs(follow_speed * delta))),
			)
	
	if line and State.is_end and following:
		following = false

func _apply_state_checkpoint() -> void:
	if _checkpoint_applied:
		return
	var cp := State.camera_checkpoint
	if not cp.has_checkpoint or not cp.restore_pending:
		return
	if line == null and player:
		line = get_node_or_null(player) as Node3D
	if line == null:
		return
	State.load_to_camera_follower(self)
	position = line.position + add_position
	rotation_degrees = cp.rotation_degrees
	_pending_resume = true
	_checkpoint_applied = true
	State.camera_checkpoint.restore_pending = false

func _resume_tweens() -> void:
	_pending_resume = false
	if _tween:
		_tween.kill()
	var has_tween := false
	if not add_position.is_equal_approx(_target_add_position) or not is_equal_approx(follow_speed, _target_follow_speed) or not is_equal_approx(distance_from_object, _target_distance):
		_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		has_tween = true
		if not add_position.is_equal_approx(_target_add_position):
			_tween.tween_property(self, "add_position", _target_add_position, 1.0)
		if not is_equal_approx(follow_speed, _target_follow_speed):
			_tween.tween_property(self, "follow_speed", _target_follow_speed, 1.0)
		if not is_equal_approx(distance_from_object, _target_distance):
			_tween.tween_property(self, "distance_from_object", _target_distance, 1.0)
	var need_rotate := true
	if rotation_degrees.is_equal_approx(_target_rotation):
		need_rotate = false
	if need_rotate:
		if not has_tween:
			_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			has_tween = true
		if _current_rotate_mode == RotateMode.Fast:
			var start_rot := rotation_degrees
			_tween.tween_method(func(w: float) -> void:
				rotation_degrees = Vector3(
					rad_to_deg(lerp_angle(deg_to_rad(start_rot.x), deg_to_rad(_target_rotation.x), w)),
					rad_to_deg(lerp_angle(deg_to_rad(start_rot.y), deg_to_rad(_target_rotation.y), w)),
					rad_to_deg(lerp_angle(deg_to_rad(start_rot.z), deg_to_rad(_target_rotation.z), w)),
				)
			, 0.0, 1.0, 1.0)
		else:
			_tween.tween_property(self, "rotation_degrees", _target_rotation, 1.0)



## 获取当前目标旋转值
func _get_target_rotation() -> Vector3:
	match _current_rotate_mode:
		RotateMode.WorldAxisAdd, RotateMode.LocalAxisAdd:
			return _base_rotation + rotation_offset
	return rotation_offset

## 计算旋转插值的目标值
func _calculate_target_rotation() -> Vector3:
	match _current_rotate_mode:
		RotateMode.WorldAxisAdd, RotateMode.LocalAxisAdd:
			return _base_rotation + rotation_offset
	return _target_rotation

## 归一化旋转到最短路径
func _normalize_rotation_shortest(from: Vector3, to: Vector3) -> Vector3:
	var result := Vector3.ZERO
	for i in 3:
		var diff = fmod(to[i] - from[i], 360.0)
		if diff > 180:
			diff -= 360
		elif diff < -180:
			diff += 360
		result[i] = from[i] + diff
	return result

## 应用 RotateMode 计算旋转
func _apply_rotate_mode(from: Vector3, to: Vector3, t: float) -> Vector3:
	match _current_rotate_mode:
		RotateMode.Fast:
			# 最短路径：每轴使用 lerp_angle
			return Vector3(
				rad_to_deg(lerp_angle(deg_to_rad(from.x), deg_to_rad(to.x), t)),
				rad_to_deg(lerp_angle(deg_to_rad(from.y), deg_to_rad(to.y), t)),
				rad_to_deg(lerp_angle(deg_to_rad(from.z), deg_to_rad(to.z), t)),
			)
		RotateMode.FastBeyond360, RotateMode.WorldAxisAdd, RotateMode.LocalAxisAdd:
			# 直接线性插值，允许超过360度
			return from.lerp(to, t)
	return from.lerp(to, t)

## 开始 tween 到目标位置/旋转（最短角路径）
func lerp_to(target_pos: Vector3, target_rot: Vector3, speed: float = 2.0) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	var duration := 1.0 / speed
	_tween.tween_property(self, "position", target_pos, duration)
	# 旋转需要逐轴用 lerp_angle 实现最短路径
	var start_rot := rotation_degrees
	_tween.tween_method(func(w: float) -> void:
		rotation_degrees = Vector3(
			rad_to_deg(lerp_angle(deg_to_rad(start_rot.x), deg_to_rad(target_rot.x), w)),
			rad_to_deg(lerp_angle(deg_to_rad(start_rot.y), deg_to_rad(target_rot.y), w)),
			rad_to_deg(lerp_angle(deg_to_rad(start_rot.z), deg_to_rad(target_rot.z), w)),
		)
	, 0.0, 1.0, duration)
