extends RigidBody3D

@onready var mesh: MeshInstance3D = $MeshInstance3D

@export var shrink_delay: float = 2.0  ## 开始缩小前的延迟时间（秒）
@export var shrink_duration: float = 1.0  ## 缩小动画持续时间（秒）

var _shrink_tween: Tween

func _ready() -> void:
	_start_shrink_timer()

func _start_shrink_timer() -> void:
	await get_tree().create_timer(shrink_delay).timeout
	_start_shrink()

func _start_shrink() -> void:
	if not is_instance_valid(mesh):
		queue_free()
		return
	
	_shrink_tween = create_tween()
	_shrink_tween.tween_property(mesh, "scale", Vector3.ZERO, shrink_duration)
	_shrink_tween.finished.connect(_on_shrink_finished)

func _on_shrink_finished() -> void:
	queue_free()
