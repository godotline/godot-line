extends Area3D
class_name Checkpoint

enum Direction { First, Second }

@export var AutoRecord: bool = false
@export var GameTime: float = 0.0
@export var PlayerSpeed: float = 12.0
@export var UsingOldCameraFollower: bool = false

@export_group("Player")
@export var direction: Direction = Direction.First

@export_group("Camera")
@export var camera_new: CameraSettings = CameraSettings.new()
@export var camera_old: OldCameraSettings = OldCameraSettings.new()
@export var manual_camera: bool = false

@export_group("Fog")
@export var fog: FogSettings = FogSettings.new()
@export var manual_fog: bool = false

@export_group("Light")
@export var light: LightSettings = LightSettings.new()
@export var manual_light: bool = false

@export_group("Ambient")
@export var ambient: AmbientSettings = AmbientSettings.new()
@export var manual_ambient: bool = false

signal on_revive

var used := false

func _ready() -> void:
	$RevivePosition.visible = false
	if not body_entered.is_connected(_on_checkpoint_body_entered):
		body_entered.connect(_on_checkpoint_body_entered)

func _on_checkpoint_body_entered(body: Node3D) -> void:
	if used:
		return
	used = true
	LevelManager.current_checkpoint = self
	LevelManager.save_checkpoint(body, CameraFollower.instance, $RevivePosition)

	if AutoRecord:
		var music_player := body.get_node_or_null("MusicPlayer") as AudioStreamPlayer
		if music_player and music_player.playing:
			GameTime = music_player.get_playback_position()
		PlayerSpeed = body.speed

	if not manual_camera:
		var cf := CameraFollower.instance
		if cf:
			if not UsingOldCameraFollower:
				camera_new.offset = cf.add_position
				camera_new.rotation = cf.rotation_degrees
				camera_new.distance = cf.distance_from_object
				camera_new.follow = cf.following
			else:
				camera_old.offset = cf.add_position
				camera_old.rotation = cf.rotation_degrees
				camera_old.distance = cf.distance_from_object
				camera_old.follow = cf.following

	if not manual_fog:
		_capture_fog()
	if not manual_light:
		_capture_light()
	if not manual_ambient:
		_capture_ambient()

func _capture_fog() -> void:
	var env := get_viewport().get_world_3d().environment
	if env:
		fog.use_fog = env.fog_enabled
		fog.fog_color = env.fog_light_color
		fog.start = env.fog_depth_begin
		fog.end = env.fog_depth_end

func _capture_light() -> void:
	var main_line := Player.instance
	if main_line:
		var scene_light := main_line.get_tree().get_first_node_in_group("scene_light") as DirectionalLight3D
		if scene_light:
			light.rotation = scene_light.rotation_degrees
			light.color = scene_light.light_color
			light.intensity = scene_light.light_energy

func _capture_ambient() -> void:
	var env := get_viewport().get_world_3d().environment
	if env:
		ambient.intensity = env.ambient_light_energy
		match env.ambient_light_source:
			Environment.AMBIENT_SOURCE_BG:
				ambient.lighting_type = AmbientSettings.EnvironmentLightingType.Skybox
			Environment.AMBIENT_SOURCE_COLOR:
				ambient.lighting_type = AmbientSettings.EnvironmentLightingType.Color
				ambient.ambient_color = env.ambient_light_color
			Environment.AMBIENT_SOURCE_SKY:
				ambient.lighting_type = AmbientSettings.EnvironmentLightingType.Skybox
			_:
				# AMBIENT_SOURCE_DISABLED or other values
				ambient.lighting_type = AmbientSettings.EnvironmentLightingType.Color

func _restore_camera() -> void:
	var cf := CameraFollower.instance
	if not cf:
		return
	if not UsingOldCameraFollower:
		cf.add_position = camera_new.offset
		cf.rotation_degrees = camera_new.rotation
		cf.distance_from_object = camera_new.distance
		cf.following = camera_new.follow
	else:
		cf.add_position = camera_old.offset
		cf.rotation_degrees = camera_old.rotation
		cf.distance_from_object = camera_old.distance
		cf.following = camera_old.follow

func _restore_fog() -> void:
	var env := get_viewport().get_world_3d().environment
	if env:
		env.fog_enabled = fog.use_fog
		env.fog_light_color = fog.fog_color
		env.fog_depth_begin = fog.start
		env.fog_depth_end = fog.end

func _restore_light() -> void:
	var main_line := Player.instance
	if main_line:
		var scene_light := main_line.get_tree().get_first_node_in_group("scene_light") as DirectionalLight3D
		if scene_light:
			scene_light.rotation_degrees = light.rotation
			scene_light.light_color = light.color
			scene_light.light_energy = light.intensity

func _restore_ambient() -> void:
	var env := get_viewport().get_world_3d().environment
	if env:
		env.ambient_light_energy = ambient.intensity
		match ambient.lighting_type:
			AmbientSettings.EnvironmentLightingType.Skybox:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			AmbientSettings.EnvironmentLightingType.Color:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_color = ambient.ambient_color
			AmbientSettings.EnvironmentLightingType.Gradient:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_sky_color = ambient.sky_color
				env.ambient_light_horizon_color = ambient.equator_color
				env.ambient_light_ground_color = ambient.ground_color

func revive() -> void:
	var main_line := Player.instance
	if not main_line:
		return

	LevelManager.load_checkpoint_to_main_line(main_line)
	main_line.is_live = true
	main_line.velocity = Vector3.ZERO
	main_line.is_start = false
	main_line.scale = Vector3.ONE
	main_line._clear_tail()
	Engine.time_scale = 1.0



	match direction:
		Direction.First:
			if LevelManager.player_first_direction != Vector3.ZERO:
				main_line.rotation_degrees = LevelManager.player_first_direction
		Direction.Second:
			if LevelManager.player_second_direction != Vector3.ZERO:
				main_line.rotation_degrees = LevelManager.player_second_direction

	get_tree().call_group("death_particles", "queue_free")

	for tween in get_tree().get_processed_tweens():
		tween.kill()

	var cf := CameraFollower.instance
	if cf:
		LevelManager.load_to_camera_follower(cf)
		cf.position = main_line.position + cf.add_position
		cf.rotation_degrees = LevelManager.camera_checkpoint.rotation_degrees
		cf._checkpoint_applied = false
		cf.following = true
		cf._is_rotating = false

	if not manual_camera:
		_restore_camera()
	if not manual_fog:
		_restore_fog()
	if not manual_light:
		_restore_light()
	if not manual_ambient:
		_restore_ambient()

	var music_player := main_line.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player:
		music_player.stop()
		music_player.pitch_scale = 1.0

	if main_line.animation_node and main_line.animation_node.has_animation("level"):
		main_line.animation_node.stop()

	on_revive.emit()
