extends Node3D
class_name CameraFollower3

## Godot port of the No.4 camera follower.

static var instance: CameraFollower3

@export_group("References")
@export var player: Player
@export_node_path("Node3D") var player_path: NodePath = NodePath("")
@export_node_path("Camera3D") var camera_path: NodePath = NodePath("")

@export_group("Follow")
@export var add_position: Vector3 = Vector3.ZERO
@export var rotation_offset: Vector3 = Vector3(45.0, 45.0, 0.0)
@export var distance_from_object: float = 25.0
@export var follow_speed: float = 1.2
@export var following: bool = true

var camera: Camera3D

var do_pos: Tween
var do_rot: Tween
var do_dis: Tween
var do_spe: Tween

var pos_e: Vector3 = Vector3.ZERO
var rot_e: Vector3 = Vector3.ZERO
var dtc_e: float = 0.0
var spd_e: float = 0.0

var _target_player: Player
var _saved_add_position: Vector3 = Vector3.ZERO
var _saved_rotation: Vector3 = Vector3.ZERO
var _saved_distance: float = 25.0
var _saved_follow_speed: float = 1.2
var _has_saved_state: bool = false
var _last_checkpoint_count: int = 0


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	_resolve_camera()
	_resolve_player()
	_last_checkpoint_count = LevelManager.checkpoint_count
	LevelManager.add_revive_listener(_on_player_revive)


func _exit_tree() -> void:
	LevelManager.remove_revive_listener(_on_player_revive)
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	_capture_checkpoint_state()
	if not is_instance_valid(_target_player):
		_resolve_player()
	if not is_instance_valid(_target_player) or not following:
		return

	_apply_camera_transform()
	if _should_stop_following():
		following = false
		kill_all()
		return

	var target_position: Vector3 = _target_player.global_position + add_position
	var blend_weight: float = clampf(absf(follow_speed * delta), 0.0, 1.0)
	global_position = global_position.slerp(target_position, blend_weight)


func _resolve_player() -> void:
	_target_player = null
	var player_instance: Player = Player.instance
	if is_instance_valid(player_instance):
		_target_player = player_instance
		return
	if is_instance_valid(player):
		_target_player = player
		return
	if not player_path.is_empty():
		_target_player = get_node_or_null(player_path) as Player
		if is_instance_valid(_target_player):
			return


func _resolve_camera() -> void:
	camera = null
	if not camera_path.is_empty():
		camera = get_node_or_null(camera_path) as Camera3D
	if not camera:
		camera = _find_camera(self)


func _find_camera(root: Node) -> Camera3D:
	for child: Node in root.get_children():
		var direct_camera: Camera3D = child as Camera3D
		if direct_camera:
			return direct_camera
		var nested_camera: Camera3D = _find_camera(child)
		if nested_camera:
			return nested_camera
	return null


func _apply_camera_transform() -> void:
	rotation_degrees = rotation_offset
	if camera:
		camera.position = Vector3(0.0, 0.0, -distance_from_object)


func _should_stop_following() -> bool:
	if _target_player and (not _target_player.is_live or _target_player.is_end):
		return true
	return LevelManager.is_end \
		or LevelManager.GameState == LevelManager.GameStatus.Died \
		or LevelManager.GameState == LevelManager.GameStatus.Completed


func trigger(active_position: bool, new_add_position: Vector3, active_rotate: bool,
		new_rotation: Vector3, active_distance: bool, new_distance: float,
		active_speed: bool, new_follow_speed: float, duration: float,
		trans_type: Tween.TransitionType = Tween.TRANS_SINE,
		ease_type: Tween.EaseType = Tween.EASE_IN_OUT,
		callback: Callable = Callable()) -> void:
	kill_all()
	if active_position:
		pos_e = new_add_position
		do_pos = _create_property_tween(NodePath("add_position"), new_add_position, duration, trans_type, ease_type)
	if active_rotate:
		rot_e = new_rotation
		do_rot = _create_property_tween(NodePath("rotation_offset"), new_rotation, duration, trans_type, ease_type)
	if active_distance:
		dtc_e = new_distance
		do_dis = _create_property_tween(NodePath("distance_from_object"), new_distance, duration, trans_type, ease_type)
	if active_speed:
		spd_e = new_follow_speed
		do_spe = _create_property_tween(NodePath("follow_speed"), new_follow_speed, duration, trans_type, ease_type)
	if callback.is_valid():
		if do_rot:
			do_rot.finished.connect(callback, CONNECT_ONE_SHOT)
		else:
			callback.call_deferred()


func _create_property_tween(property_name: NodePath, value: Variant, duration: float,
		trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> Tween:
	var tween: Tween = create_tween()
	tween.set_trans(trans_type).set_ease(ease_type)
	tween.tween_property(self, property_name, value, maxf(duration, 0.0))
	return tween


func kill_all() -> void:
	do_pos = _kill_tween(do_pos)
	do_rot = _kill_tween(do_rot)
	do_dis = _kill_tween(do_dis)
	do_spe = _kill_tween(do_spe)


func kill_all_camera_tweens() -> void:
	kill_all()


func _kill_tween(tween: Tween) -> Tween:
	if tween and tween.is_valid():
		tween.kill()
	return null


func _tween_is_active(tween: Tween) -> bool:
	return tween != null and tween.is_valid() and tween.is_running()


func _capture_checkpoint_state() -> void:
	var checkpoint_count: int = LevelManager.checkpoint_count
	if checkpoint_count == _last_checkpoint_count:
		return
	if checkpoint_count < _last_checkpoint_count:
		_has_saved_state = false
	else:
		_saved_add_position = pos_e if _tween_is_active(do_pos) else add_position
		_saved_rotation = rot_e if _tween_is_active(do_rot) else rotation_offset
		_saved_distance = dtc_e if _tween_is_active(do_dis) else distance_from_object
		_saved_follow_speed = spd_e if _tween_is_active(do_spe) else follow_speed
		_has_saved_state = true
	_last_checkpoint_count = checkpoint_count


func _on_player_revive() -> void:
	if _has_saved_state:
		add_position = _saved_add_position
		rotation_offset = _saved_rotation
		distance_from_object = _saved_distance
		follow_speed = _saved_follow_speed
	if not is_instance_valid(_target_player):
		_resolve_player()
	if _target_player:
		global_position = _target_player.global_position + add_position
	_apply_camera_transform()
	following = true
