class_name OldCameraSettings
extends Resource

@export var offset: Vector3 = Vector3.ZERO
@export var rotation: Vector3 = Vector3.ZERO
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
		settings.rotation = follower.rotator.rotation_degrees
	if follower.scale_node:
		settings.scale = follower.scale_node.scale
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
		follower.rotator.rotation_degrees = rotation
	if follower.scale_node:
		follower.scale_node.scale = scale
		follower.scale_node.position = Vector3.ZERO
	if follower.camera:
		follower.camera.fov = fov
		if distance > 0.0:
			follower.camera.position.z = -distance
	follower.follow = follow
	follower.update_follow_position()
