extends Area3D

@export var transition_duration: float = 1.0
@onready var level_manager = get_tree().current_scene
@onready var Camera = level_manager.Camera
@export var orthogonal_size: float = 10.0
@export var perspective_fov: float = 75.0
@export_enum("Switch to Orthogonal", "Switch to Perspective") var projection_mode: int = 1

var tween: Tween

func _ready() -> void:
	if not Engine.is_editor_hint():
		$MeshInstance3D.visible = false

func switch_to_orthogonal():
	if not Camera:
		return

	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)

	# 获取当前FOV作为起始值
	var current_fov = Camera.fov
	tween.tween_method(func(weight):_interpolate_to_orthogonal(current_fov, weight), 0.0, 1.0,transition_duration)
	tween.tween_callback(_set_orthogonal_final)

func switch_to_perspective():
	if not Camera:
		return

	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)

	# 计算等效FOV作为起始值
	var equivalent_fov = _calculate_equivalent_fov()
	tween.tween_method(func(weight):_interpolate_to_perspective(equivalent_fov, weight), 0.0, 1.0,transition_duration)
	tween.tween_callback(_set_perspective_final)

func _interpolate_to_orthogonal(start_fov: float, weight: float):
	Camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	Camera.fov = lerp(start_fov, 0.1, weight)

func _interpolate_to_perspective(start_fov: float, weight: float):
	Camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	Camera.fov = lerp(start_fov, perspective_fov, weight)

func _calculate_equivalent_fov() -> float:
	# 根据正交size计算等效的透视FOV
	var distance = Camera.transform.origin.distance_to(Vector3.ZERO)
	var equivalent_fov = 2.0 * atan(Camera.size / (2.0 * distance)) *180.0 / PI
	return max(equivalent_fov, 0.1)  # 确保最小值

func _set_orthogonal_final():
	Camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	Camera.size = orthogonal_size

func _set_perspective_final():
	Camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	Camera.fov = perspective_fov

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if projection_mode == 0:
			switch_to_orthogonal()
		else:  # Switch to Perspective
			switch_to_perspective()
