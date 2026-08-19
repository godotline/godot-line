class_name CameraSettings
extends Resource

@export var offset: Vector3 = Vector3.ZERO
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees,or_greater,or_less") var rotation: Vector3 = Vector3.ZERO
@export var scale: Vector3 = Vector3.ONE
@export var fov: float = 60.0
@export var follow: bool = true


## Returns a snapshot of the active follower, matching CameraSettings.GetCamera.
func get_camera() -> CameraSettings:
	var settings: CameraSettings = CameraSettings.new()
	var follower: CameraFollower = CameraFollower.instance
	if not follower:
		return settings

	if follower.rotator:
		settings.offset = follower.rotator.position
		settings.rotation = follower.rotator.rotation
	if follower.scaleNode:
		settings.scale = follower.scaleNode.scale
	if follower.camera:
		settings.fov = follower.camera.fov
	settings.follow = follower.follow
	return settings


## Restores the active follower, including the shake offset reset performed by
## CameraSettings.SetCamera in Unity.
func set_camera() -> void:
	var follower: CameraFollower = CameraFollower.instance
	if not follower:
		return

	if follower.rotator:
		follower.rotator.position = offset
		follower.rotator.rotation = rotation
	if follower.scaleNode:
		follower.scaleNode.scale = scale
		follower.scaleNode.position = Vector3.ZERO
	if follower.camera:
		follower.camera.fov = fov
	follower.follow = follow
