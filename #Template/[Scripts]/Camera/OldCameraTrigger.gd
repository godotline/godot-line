class_name OldCameraTrigger
extends Node

## OldCameraTrigger - 旧相机视角变换触发器（模式 1 纯组件）
## 作为 BaseTrigger 的子节点使用，由父节点负责碰撞检测。
## 与 Unity OldCameraTrigger.cs 一致。

@export_group("Camera Settings")
@export var addOffset: bool = false
@export var offset: Vector3 = Vector3.ZERO
@export var cameraRotation: Vector3 = Vector3(54.0, 45.0, 0.0)
@export var cameraScale: Vector3 = Vector3.ONE
@export_range(0.0, 179.0) var fieldOfView: float = 80.0
@export var follow: bool = true

@export_group("Animation")
@export var duration: float = 2.0
@export var transitionType: Tween.TransitionType = Tween.TRANS_SINE
@export var easeType: Tween.EaseType = Tween.EASE_IN_OUT
@export var rotationMode: OldCameraFollower.RotateMode = OldCameraFollower.RotateMode.FAST_BEYOND_360
@export var canBeTriggered: bool = true

@export_group("时间判定")
@export var useTime: bool = false
@export var triggerTime: float = 0.0

signal on_finished

var _follower: OldCameraFollower
var timeTriggered: bool = false


func _ready() -> void:
	set_process(useTime)


func _process(_delta: float) -> void:
	if useTime and not timeTriggered and LevelManager.animTime >= triggerTime:
		timeTriggered = true
		_apply_camera()
		set_process(false)


func trigger(body: Node3D) -> void:
	if useTime or not canBeTriggered:
		return
	if body is CharacterBody3D:
		_apply_camera()


## Matches Unity OldCameraTrigger.Trigger(): manual use is enabled when
## collision triggering has been disabled.
func trigger_manually() -> void:
	if not canBeTriggered:
		_apply_camera()


func _apply_camera() -> void:
	if not _follower:
		_follower = OldCameraFollower.instance
	if not _follower:
		return

	_follower.follow = follow
	_follower.Trigger(
		addOffset,
		offset,
		cameraRotation,
		cameraScale,
		fieldOfView,
		duration,
		transitionType,
		easeType,
		rotationMode,
		func() -> void: on_finished.emit()
	)

