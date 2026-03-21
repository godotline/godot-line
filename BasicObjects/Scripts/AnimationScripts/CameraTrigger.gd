extends Area3D

@export var set_camera: NodePath
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

@onready var camera_follower = get_node(set_camera) if set_camera else null

var triggered: bool = false
var triggered_at_crown: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("mainline") or body.name == "MainLine":
		if not use_time:
			_trigger()

func _process(delta: float) -> void:
	if use_time and not triggered:
		var current_time = 0.0
		if camera_follower and camera_follower.player_node:
			var main_line = camera_follower.player_node
			if main_line.animation_node:
				current_time = main_line.animation_node.current_animation_position
				#print("CameraTrigger animtime: ", current_time)
		
		if current_time >= trigger_time:
			_trigger()

func _trigger() -> void:
	if not camera_follower:
		return
	
	triggered = true
	
	# 停止现有 Tween
	camera_follower.kill_tweens()
	
	if active_position:
		camera_follower.pos_e = new_add_position
		camera_follower.do_pos = create_tween()
		camera_follower.do_pos.set_ease(ease_type)
		camera_follower.do_pos.tween_property(camera_follower, "add_position", new_add_position, need_time)
	
	if active_rotate:
		camera_follower.rot_e = new_rotation
		camera_follower.do_rot = create_tween()
		camera_follower.do_rot.set_ease(ease_type)
		camera_follower.do_rot.tween_property(camera_follower, "rotation_offset", new_rotation, need_time)
	
	if active_distance:
		camera_follower.dtc_e = new_distance
		camera_follower.do_dis = create_tween()
		camera_follower.do_dis.set_ease(ease_type)
		camera_follower.do_dis.tween_property(camera_follower, "distance_from_object", new_distance, need_time)
	
	if active_speed:
		camera_follower.spd_e = new_follow_speed
		camera_follower.do_spe = create_tween()
		camera_follower.do_spe.set_ease(ease_type)
		camera_follower.do_spe.tween_property(camera_follower, "follow_speed", new_follow_speed, need_time)
