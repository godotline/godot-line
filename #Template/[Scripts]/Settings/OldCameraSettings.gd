class_name OldCameraSettings
extends Resource

@export var offset: Vector3 = Vector3.ZERO
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees,or_greater,or_less") var rotation: Vector3 = Vector3.ZERO
@export var scale: Vector3 = Vector3.ONE
@export var fov: float = 60.0
@export var follow: bool = true
@export var distance: float = 0.0


## Returns the same state captured by Unity OldCameraSettings.GetCamera().
func get_camera() -> OldCameraSettings:
	var settings: OldCameraSettings = duplicate()
	var follower: OldCameraFollower = OldCameraFollower.instance
	if not follower:
		return settings
	if follower.rotator:
		settings.offset = follower.rotator.position
		settings.rotation = follower.rotator.rotation
	if follower.scaleNode:
		settings.scale = follower.scaleNode.scale
	if follower.camera:
		settings.fov = follower.camera.fov
		settings.distance = absf(follower.camera.position.z)
	settings.follow = follower.follow
	return settings


## Restores the same state restored by Unity OldCameraSettings.SetCamera().
func set_camera() -> void:
	var follower: OldCameraFollower = OldCameraFollower.instance
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
		if distance > 0.0:
			follower.camera.position.z = -distance
	follower.follow = follow
	follower.update_follow_position()
