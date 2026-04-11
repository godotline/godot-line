extends Node3D

@export var player: NodePath
@export var add_position: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3(45, 45, 0)
@export var distance_from_object: float = 25.0
@export var follow_speed: float = 1.2
@export var following: bool = true

@onready var player_node: Node3D = get_node(player) if player else null
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

func _ready() -> void:
	if not camera and get_child_count() > 0:
		camera = get_child(0)
	if State.camera_checkpoint.has_checkpoint and State.camera_checkpoint.restore_pending:
		call_deferred("_apply_state_checkpoint")

func _process(delta: float) -> void:
	if State.camera_checkpoint.has_checkpoint and State.camera_checkpoint.restore_pending and not _checkpoint_applied:
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
	var cp := State.camera_checkpoint
	if not cp.has_checkpoint or not cp.restore_pending:
		return
	if player_node == null and player:
		player_node = get_node_or_null(player) as Node3D
	if player_node == null:
		return
	State.load_to_camera_follower(self)
	rotation_degrees = rotation_offset
	var base_transform = player_node.position + add_position
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
	var base_transform = player_node.position + add_position
	position = base_transform

func pick() -> void:
	tween_backups[TweenProp.POSITION] = add_position if tweens[TweenProp.POSITION] == null or not tweens[TweenProp.POSITION].is_running() else tween_ends[TweenProp.POSITION]
	tween_backups[TweenProp.ROTATION] = rotation_offset if tweens[TweenProp.ROTATION] == null or not tweens[TweenProp.ROTATION].is_running() else tween_ends[TweenProp.ROTATION]
	tween_backups[TweenProp.DISTANCE] = distance_from_object if tweens[TweenProp.DISTANCE] == null or not tweens[TweenProp.DISTANCE].is_running() else tween_ends[TweenProp.DISTANCE]
	tween_backups[TweenProp.SPEED] = follow_speed if tweens[TweenProp.SPEED] == null or not tweens[TweenProp.SPEED].is_running() else tween_ends[TweenProp.SPEED]

# 通用 Tween 动画方法
func _tween_to(index: int, new_value: Variant, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if tweens[index] and tweens[index].is_running():
		tweens[index].kill()
	tween_ends[index] = new_value
	tweens[index] = create_tween()
	tweens[index].set_ease(ease_type)
	tweens[index].tween_property(self, TWEEN_PROPERTIES[index], new_value, duration)

# 辅助方法：设置目标位置（带 Tween 动画）
func tween_to_position(new_pos: Vector3, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	_tween_to(TweenProp.POSITION, new_pos, duration, ease_type)

# 辅助方法：设置旋转（带 Tween 动画）
func tween_to_rotation(new_rot: Vector3, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	_tween_to(TweenProp.ROTATION, new_rot, duration, ease_type)

# 辅助方法：设置距离（带 Tween 动画）
func tween_to_distance(new_dist: float, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	_tween_to(TweenProp.DISTANCE, new_dist, duration, ease_type)

# 辅助方法：设置速度（带 Tween 动画）
func tween_to_speed(new_speed: float, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	_tween_to(TweenProp.SPEED, new_speed, duration, ease_type)

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
