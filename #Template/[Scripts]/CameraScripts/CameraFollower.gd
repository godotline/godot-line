extends Node3D

@export var player: NodePath
@export var add_position: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3(45, 45, 0)
@export var distance_from_object: float = 25.0
@export var follow_speed: float = 1.2
@export var following: bool = true
@export var tween_transition: Tween.TransitionType = Tween.TRANS_SINE
@export var tween_ease: Tween.EaseType = Tween.EASE_IN_OUT

@onready var line: Node3D = get_node(player) if player else null
@onready var camera: Node3D = get_child(0) if get_child_count() > 0 else null

## Tween 属性索引枚举
enum TweenProp { POSITION, ROTATION, DISTANCE, SPEED, COUNT }

## Tween 实例数组：[pos, rot, dis, spe]
var tweens: Array = [null, null, null, null]
## Tween 目标值数组：[pos_e, rot_e, dtc_e, spd_e]
var tween_ends: Array = [Vector3.ZERO, Vector3.ZERO, 0.0, 0.0]
## Tween 备份值数组：[_pos, _rot, _dtc, _spd]
var tween_backups: Array = [Vector3.ZERO, Vector3.ZERO, 0.0, 0.0]

## Tween 属性名数组，用于动态绑定
const TWEEN_PROPERTIES: Array[String] = [
	"add_position",
	"rotation_offset",
	"distance_from_object",
	"follow_speed",
]

var _skip_follow_once := false
var _checkpoint_applied := false

## Lerp 状态
var _lerp_target_position: Vector3 = Vector3.ZERO
var _lerp_target_rotation: Vector3 = Vector3.ZERO
var _lerping: bool = false
var _lerp_speed: float = 2.0

func _ready() -> void:
	if not camera and get_child_count() > 0:
		camera = get_child(0)
	if State.camera_checkpoint.has_checkpoint and State.camera_checkpoint.restore_pending:
		call_deferred("_apply_state_checkpoint")

func _process(delta: float) -> void:
	if _lerping:
		_do_lerp(delta)
		return
	if State.camera_checkpoint.has_checkpoint and State.camera_checkpoint.restore_pending and not _checkpoint_applied:
		_apply_state_checkpoint()
	if following and line:
		rotation_degrees = rotation_offset
		var base_transform = line.position + add_position
		if _skip_follow_once:
			position = base_transform
			_skip_follow_once = false
		else:
			position = position.slerp(base_transform, abs(follow_speed * delta))
	
	if line and State.is_end and following:
		following = false
		kill_tweens()

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
	rotation_degrees = rotation_offset
	var base_transform = line.position + add_position
	position = base_transform
	_skip_follow_once = true
	_checkpoint_applied = true
	State.camera_checkpoint.restore_pending = false


func kill_tweens() -> void:
	for i in TweenProp.COUNT:
		if tweens[i] and tweens[i].is_running():
			tweens[i].kill()

func revive() -> void:
	add_position = tween_backups[TweenProp.POSITION]
	rotation_offset = tween_backups[TweenProp.ROTATION]
	distance_from_object = tween_backups[TweenProp.DISTANCE]
	follow_speed = tween_backups[TweenProp.SPEED]
	rotation_degrees = rotation_offset
	var base_transform = line.position + add_position
	position = base_transform

func pick() -> void:
	tween_backups[TweenProp.POSITION] = add_position if tweens[TweenProp.POSITION] == null or not tweens[TweenProp.POSITION].is_running() else tween_ends[TweenProp.POSITION]
	tween_backups[TweenProp.ROTATION] = rotation_offset if tweens[TweenProp.ROTATION] == null or not tweens[TweenProp.ROTATION].is_running() else tween_ends[TweenProp.ROTATION]
	tween_backups[TweenProp.DISTANCE] = distance_from_object if tweens[TweenProp.DISTANCE] == null or not tweens[TweenProp.DISTANCE].is_running() else tween_ends[TweenProp.DISTANCE]
	tween_backups[TweenProp.SPEED] = follow_speed if tweens[TweenProp.SPEED] == null or not tweens[TweenProp.SPEED].is_running() else tween_ends[TweenProp.SPEED]

# 通用 Tween 动画方法
func _tween_to(index: int, new_value: Variant, duration: float = 2.0, ease_type: Tween.EaseType = -1, trans_type: Tween.TransitionType = -1) -> void:
	if tweens[index] and tweens[index].is_running():
		tweens[index].kill()
	tween_ends[index] = new_value
	tweens[index] = create_tween()
	var final_trans := trans_type if trans_type != -1 else tween_transition
	var final_ease := ease_type if ease_type != -1 else tween_ease
	tweens[index].set_trans(final_trans)
	tweens[index].set_ease(final_ease)
	tweens[index].tween_property(self, TWEEN_PROPERTIES[index], new_value, duration)

# 辅助方法：设置目标位置（带 Tween 动画）
func tween_to_position(new_pos: Vector3, duration: float = 2.0, ease_type: Tween.EaseType = -1, trans_type: Tween.TransitionType = -1) -> void:
	_tween_to(TweenProp.POSITION, new_pos, duration, ease_type, trans_type)

# 辅助方法：设置旋转（带 Tween 动画）
func tween_to_rotation(new_rot: Vector3, duration: float = 2.0, ease_type: Tween.EaseType = -1, trans_type: Tween.TransitionType = -1) -> void:
	_tween_to(TweenProp.ROTATION, new_rot, duration, ease_type, trans_type)

# 辅助方法：设置距离（带 Tween 动画）
func tween_to_distance(new_dist: float, duration: float = 2.0, ease_type: Tween.EaseType = -1, trans_type: Tween.TransitionType = -1) -> void:
	_tween_to(TweenProp.DISTANCE, new_dist, duration, ease_type, trans_type)

# 辅助方法：设置速度（带 Tween 动画）
func tween_to_speed(new_speed: float, duration: float = 2.0, ease_type: Tween.EaseType = -1, trans_type: Tween.TransitionType = -1) -> void:
	_tween_to(TweenProp.SPEED, new_speed, duration, ease_type, trans_type)

## 开始 lerp 到目标位置/旋转（最短角路径）
func lerp_to(target_pos: Vector3, target_rot: Vector3, speed: float = 2.0) -> void:
	_lerp_target_position = target_pos
	_lerp_target_rotation = target_rot
	_lerp_speed = speed
	_lerping = true

func stop_lerp() -> void:
	_lerping = false

func _do_lerp(delta: float) -> void:
	var weight := 1.0 - exp(-_lerp_speed * delta)
	position = position.lerp(_lerp_target_position, weight)
	var cur := rotation_degrees
	rotation_degrees = Vector3(
		rad_to_deg(lerp_angle(deg_to_rad(cur.x), deg_to_rad(_lerp_target_rotation.x), weight)),
		rad_to_deg(lerp_angle(deg_to_rad(cur.y), deg_to_rad(_lerp_target_rotation.y), weight)),
		rad_to_deg(lerp_angle(deg_to_rad(cur.z), deg_to_rad(_lerp_target_rotation.z), weight)),
	)
	if position.is_equal_approx(_lerp_target_position) and _angle_approx(rotation_degrees, _lerp_target_rotation):
		_lerping = false

func _angle_approx(from: Vector3, to: Vector3, tolerance: float = 0.1) -> bool:
	return abs(fmod(to.x - from.x + 180.0, 360.0) - 180.0) < tolerance \
		and abs(fmod(to.y - from.y + 180.0, 360.0) - 180.0) < tolerance \
		and abs(fmod(to.z - from.z + 180.0, 360.0) - 180.0) < tolerance

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
