extends BaseTrigger

@export var cameraParent: Node3D  # 这是Camera3D的父节点
@export var shakeIntensity: float = 0.5
@export var shakeDuration: float = 0.3

var shakeTimer: float = 0.0
var originalPosition: Vector3

func _ready() -> void:
	super._ready()
	set_process(false)  ## 默认关闭，仅在震动时启用

func _process(delta: float) -> void:
	if shakeTimer > 0 and cameraParent:
		shakeTimer -= delta

		if shakeTimer <= 0:
			cameraParent.position = originalPosition
			set_process(false)  ## 震动结束，关闭 _process
		else:
			var shakeOffset: Vector3 = Vector3(
				randf_range(-shakeIntensity, shakeIntensity),
				randf_range(-shakeIntensity, shakeIntensity),
				randf_range(-shakeIntensity, shakeIntensity)
			)
			cameraParent.position = originalPosition + shakeOffset

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		if cameraParent:
			originalPosition = cameraParent.position
			shakeTimer = shakeDuration
			set_process(true)  ## 开始震动，启用 _process
		else:
			push_error("OldCameraShakeTrigger.gd: cameraParent 未指定")
