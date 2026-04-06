extends Area3D

@export var active_position: bool = true
@export var new_add_position: Vector3 = Vector3.ZERO
@export var active_rotate: bool = true
@export var new_rotation: Vector3 = Vector3(45, 45, 0)
@export var active_distance: bool = true
@export var new_distance: float = 25.0
@export var active_speed: bool = true
@export var new_follow_speed: float = 1.2
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var need_time: float = 2.0

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
				#print("CameraTrigger animtime: ", current_time)
		
		if current_time >= trigger_time:
			_trigger()

func _trigger() -> void:
	var cf = _get_camera_follower()
	if not cf:
		return
	
	triggered = true
	
	# 停止现有 Tween
	cf.kill_tweens()
	
	if active_position:
		cf.pos_e = new_add_position
		cf.do_pos = create_tween()
		cf.do_pos.set_ease(ease_type)
		cf.do_pos.tween_property(cf, "add_position", new_add_position, need_time)
	
	if active_rotate:
		cf.rot_e = new_rotation
		cf.do_rot = create_tween()
		cf.do_rot.set_ease(ease_type)
		cf.do_rot.tween_property(cf, "rotation_offset", new_rotation, need_time)
	
	if active_distance:
		cf.dtc_e = new_distance
		cf.do_dis = create_tween()
		cf.do_dis.set_ease(ease_type)
		cf.do_dis.tween_property(cf, "distance_from_object", new_distance, need_time)
	
	if active_speed:
		cf.spd_e = new_follow_speed
		cf.do_spe = create_tween()
		cf.do_spe.set_ease(ease_type)
		cf.do_spe.tween_property(cf, "follow_speed", new_follow_speed, need_time)
