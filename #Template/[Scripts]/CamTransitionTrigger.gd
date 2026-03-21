extends Area3D

@export var transition_duration: float = 1.0
@export var orthogonal_size: float = 10.0
@export var perspective_fov: float = 75.0
@export_enum("Switch to Orthogonal", "Switch to Perspective") var projection_mode: int = 1

@onready var level_manager = get_tree().current_scene
@export var camera: Camera3D

const MIN_FOV: float = 5.0      # 超长焦模拟正交（不是 0.1！）
const SWITCH_THRESHOLD: float = 0.3  # 30% 时切换投影模式

var tween: Tween
var is_transitioning: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		$MeshInstance3D.visible = false

func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	if is_transitioning:
		return
	
	match projection_mode:
		0: _transition_to_orthogonal()
		1: _transition_to_perspective()

func _transition_to_orthogonal():
	if not camera:
		return
	
	is_transitioning = true
	
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# 阶段 1: 透视模式下缩小 FOV 到超长焦（模拟正交感）
	var start_fov = camera.fov if camera.projection == Camera3D.PROJECTION_PERSPECTIVE else perspective_fov
	
	tween.tween_method(
		func(t): _apply_transition(t, start_fov, true),
		0.0, 1.0,
		transition_duration
	)
	
	tween.tween_callback(func():
		_set_orthogonal_final()
		is_transitioning = false
	)

func _transition_to_perspective():
	if not camera:
		return
	
	is_transitioning = true
	
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# 阶段 1: 正交模式下先切到透视超长焦，再放大 FOV
	var start_size = camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else orthogonal_size
	
	tween.tween_method(
		func(t): _apply_transition(t, start_size, false),
		0.0, 1.0,
		transition_duration
	)
	
	tween.tween_callback(func():
		_set_perspective_final()
		is_transitioning = false
	)

func _apply_transition(t: float, start_value: float, to_ortho: bool):
	if not camera:
		return
	
	if to_ortho:
		# 透视 -> 正交
		if t < SWITCH_THRESHOLD:
			# 阶段 1: 透视模式下 FOV 缩小到超长焦
			var local_t = t / SWITCH_THRESHOLD
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = lerp(start_value, MIN_FOV, local_t)
		else:
			# 阶段 2: 切换到正交
			var local_t = (t - SWITCH_THRESHOLD) / (1.0 - SWITCH_THRESHOLD)
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = lerp(MIN_FOV * 0.1, orthogonal_size, local_t)  # 从极小 size 过渡到目标 size
	else:
		# 正交 -> 透视
		if t < SWITCH_THRESHOLD:
			# 阶段 1: 保持正交但缩小 size（视觉压缩）
			var local_t = t / SWITCH_THRESHOLD
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = lerp(start_value, orthogonal_size * 0.5, local_t)
		else:
			# 阶段 2: 切换到透视并放大 FOV
			var local_t = (t - SWITCH_THRESHOLD) / (1.0 - SWITCH_THRESHOLD)
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = lerp(MIN_FOV, perspective_fov, local_t)

func _set_orthogonal_final():
	if not camera:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = orthogonal_size

func _set_perspective_final():
	if not camera:
		return
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = perspective_fov
