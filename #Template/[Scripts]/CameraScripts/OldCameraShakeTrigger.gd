extends BaseTrigger

@export var camera_parent: Node3D  # 这是Camera3D的父节点
@export var shake_intensity: float = 0.5
@export var shake_duration: float = 0.3

var shake_timer: float = 0.0
var original_position: Vector3

func _ready():
	super._ready()
	set_process(false)  ## 默认关闭，仅在震动时启用

func _process(delta):
	if shake_timer > 0 and camera_parent:
		shake_timer -= delta

		if shake_timer <= 0:
			camera_parent.position = original_position
			set_process(false)  ## 震动结束，关闭 _process
		else:
			var shake_offset = Vector3(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
			camera_parent.position = original_position + shake_offset

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if camera_parent:
			original_position = camera_parent.position
			shake_timer = shake_duration
			set_process(true)  ## 开始震动，启用 _process
		else:
			print("Camera parent未指定")
