extends Node3D

@export var player: NodePath
@export var add_position: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3(45, 45, 0)
@export var distance_from_object: float = 25.0
@export var follow_speed: float = 1.2
@export var following: bool = true

@onready var player_node: Node3D = get_node(player) if player else null
@onready var camera: Node3D = get_child(0) if get_child_count() > 0 else null

var do_pos: Tween
var do_rot: Tween
var do_dis: Tween
var do_spe: Tween

var pos_e: Vector3
var rot_e: Vector3
var dtc_e: float
var spd_e: float

var _pos: Vector3
var _rot: Vector3
var _dtc: float
var _spd: float
var _skip_follow_once := false
var _checkpoint_applied := false

func _ready() -> void:
	if not camera and get_child_count() > 0:
		camera = get_child(0)
	if State.camera_follower_has_checkpoint and State.camera_follower_restore_pending:
		call_deferred("_apply_state_checkpoint")
	# 这里假设有 Crown 系统，在 GDScript 中需要手动连接信号

func _process(delta: float) -> void:
	if State.camera_follower_has_checkpoint and State.camera_follower_restore_pending and not _checkpoint_applied:
		_apply_state_checkpoint()
	if following and player_node:
		rotation_degrees = rotation_offset
		var base_transform = player_node.position + add_position
		if _skip_follow_once:
			position = base_transform
			_skip_follow_once = false
		else:
			position = position.slerp(base_transform, abs(follow_speed * delta))
	
	# 假设 player 有 Is_Stop 和 Over 属性
	if player_node and player_node.get("Is_Stop") and player_node.get("Over") and following:
		following = false
		kill_tweens()

func _apply_state_checkpoint() -> void:
	if _checkpoint_applied:
		return
	if not State.camera_follower_has_checkpoint or not State.camera_follower_restore_pending:
		return
	if player_node == null and player:
		player_node = get_node_or_null(player) as Node3D
	if player_node == null:
		return
	add_position = State.camera_follower_add_position
	rotation_offset = State.camera_follower_rotation_offset
	distance_from_object = State.camera_follower_distance
	follow_speed = State.camera_follower_follow_speed
	rotation_degrees = rotation_offset
	var base_transform = player_node.position + add_position
	position = base_transform
	_skip_follow_once = true
	_checkpoint_applied = true
	State.camera_follower_restore_pending = false

func kill_tweens() -> void:
	if do_pos and do_pos.is_running():
		do_pos.kill()
	if do_rot and do_rot.is_running():
		do_rot.kill()
	if do_dis and do_dis.is_running():
		do_dis.kill()
	if do_spe and do_spe.is_running():
		do_spe.kill()

func revive() -> void:
	add_position = _pos
	rotation_offset = _rot
	distance_from_object = _dtc
	follow_speed = _spd
	rotation_degrees = rotation_offset
	var base_transform = player_node.position + add_position
	position = base_transform

func pick() -> void:
	if do_pos == null or not do_pos.is_running():
		_pos = add_position
	else:
		_pos = pos_e
	
	if do_rot == null or not do_rot.is_running():
		_rot = rotation_offset
	else:
		_rot = rot_e
	
	if do_dis == null or not do_dis.is_running():
		_dtc = distance_from_object
	else:
		_dtc = dtc_e
	
	if do_spe == null or not do_spe.is_running():
		_spd = follow_speed
	else:
		_spd = spd_e

# 辅助方法：设置目标位置（带 Tween 动画）
func tween_to_position(new_pos: Vector3, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if do_pos and do_pos.is_running():
		do_pos.kill()
	pos_e = new_pos
	do_pos = create_tween()
	do_pos.set_ease(ease_type)
	do_pos.tween_property(self, "add_position", new_pos, duration)

# 辅助方法：设置旋转（带 Tween 动画）
func tween_to_rotation(new_rot: Vector3, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if do_rot and do_rot.is_running():
		do_rot.kill()
	rot_e = new_rot
	do_rot = create_tween()
	do_rot.set_ease(ease_type)
	do_rot.tween_property(self, "rotation_offset", new_rot, duration)

# 辅助方法：设置距离（带 Tween 动画）
func tween_to_distance(new_dist: float, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if do_dis and do_dis.is_running():
		do_dis.kill()
	dtc_e = new_dist
	do_dis = create_tween()
	do_dis.set_ease(ease_type)
	do_dis.tween_property(self, "distance_from_object", new_dist, duration)

# 辅助方法：设置速度（带 Tween 动画）
func tween_to_speed(new_speed: float, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if do_spe and do_spe.is_running():
		do_spe.kill()
	spd_e = new_speed
	do_spe = create_tween()
	do_spe.set_ease(ease_type)
	do_spe.tween_property(self, "follow_speed", new_speed, duration)

# 相机震动函数
func camera_shake(intensity: float, time: float) -> void:
	var cam = get_node("Camera3D") if has_node("Camera3D") else null
	if not cam:
		return
	var original_pos = cam.position
	var timer = 0.0
	while timer < time:
		var decay = 1.0 - (timer / time)
		var shake_offset = Vector3(
			randf_range(-1, 1) * intensity * decay,
			randf_range(-1, 1) * intensity * decay,
			0
		)
		cam.position = original_pos + shake_offset
		timer += get_process_delta_time()
		await get_tree().process_frame
	cam.position = original_pos
