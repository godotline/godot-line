extends Area3D
class_name Checkpoint

enum Direction { First, Second }

@export_group("Config")
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

@export_group("Colors")
@export var material_colors_auto: Array[SingleColor] = []
@export var material_colors_manual: Array[SingleColor] = []

signal on_revive

var used := false
var used_revive := false

var _track_progress: float = 0.0
var _scene_gravity: Vector3 = Vector3.ZERO
var _player_first_direction: Vector3 = Vector3.ZERO
var _player_second_direction: Vector3 = Vector3.ZERO

var _revive_position: Node3D

func _ready() -> void:
	_revive_position = get_node_or_null("RevivePosition")
	if _revive_position:
		_revive_position.visible = false

	if not body_entered.is_connected(_on_checkpoint_body_entered):
		body_entered.connect(_on_checkpoint_body_entered)

func _on_checkpoint_body_entered(body: Node3D) -> void:
	if used:
		return
	_enter_trigger(body)

func _enter_trigger(body: Node3D) -> void:
	used = true
	LevelManager.current_checkpoint = self

	# Capture camera settings
	if not manual_camera:
		if not UsingOldCameraFollower:
			var cf := CameraFollower.instance
			if cf and cf.rotator:
				camera_new.offset = cf.rotator.position
				camera_new.rotation = cf.rotator.rotation_degrees
				if cf.camera:
					camera_new.fov = cf.camera.fov
				camera_new.follow = cf.follow
		else:
			var ocf := OldCameraFollower.instance
			if ocf:
				camera_old.offset = ocf.add_position
				camera_old.rotation = ocf.rotation_degrees
				camera_old.distance = ocf.distance_from_object
				camera_old.follow = ocf.following

	if not manual_fog:
		_capture_fog()
	if not manual_light:
		_capture_light()
	if not manual_ambient:
		_capture_ambient()

	# Capture material colors auto
	for s in material_colors_auto:
		s.apply()

	# Save player state
	_player_first_direction = body.firstDirection
	_player_second_direction = body.secondDirection
	_track_progress = body.animation_node.get_current_animation_position() if body.animation_node and body.animation_node.is_playing() else 0.0
	_scene_gravity = ProjectSettings.get_setting("physics/3d/default_gravity_vector") * ProjectSettings.get_setting("physics/3d/default_gravity")

	if AutoRecord:
		var music_player := body.get_node_or_null("MusicPlayer") as AudioStreamPlayer
		if music_player and music_player.playing:
			GameTime = music_player.get_playback_position()
		PlayerSpeed = body.speed

	# Save to LevelManager (OldCameraFollower only, new camera stores in camera_new)
	if UsingOldCameraFollower:
		LevelManager.save_checkpoint(body, OldCameraFollower.instance, _revive_position)
	else:
		LevelManager.save_checkpoint(body, null, _revive_position)

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
				ambient.lighting_type = AmbientSettings.EnvironmentLightingType.Color

func _restore_camera() -> void:
	if not UsingOldCameraFollower:
		var cf := CameraFollower.instance
		if cf and cf.rotator:
			cf.rotator.position = camera_new.offset
			cf.rotator.rotation_degrees = camera_new.rotation
			if cf.camera:
				cf.camera.fov = camera_new.fov
			cf.follow = camera_new.follow
	else:
		var ocf := OldCameraFollower.instance
		if ocf:
			ocf.add_position = camera_old.offset
			ocf.rotation_degrees = camera_old.rotation
			ocf.distance_from_object = camera_old.distance
			ocf.following = camera_old.follow

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

	# Decrement crown on first revive
	if not used_revive:
		LevelManager.crown = maxi(LevelManager.crown - 1, 0)
		used_revive = true

	# Restore player state
	LevelManager.load_checkpoint_to_main_line(main_line)
	main_line.is_live = true
	main_line.velocity = Vector3.ZERO
	main_line.is_start = false
	main_line.allowTurn = true
	main_line.scale = Vector3.ONE
	main_line._clear_tail()
	Engine.time_scale = 1.0

	# Restore direction
	match direction:
		Direction.First:
			if _player_first_direction != Vector3.ZERO:
				main_line.rotation_degrees = _player_first_direction
		Direction.Second:
			if _player_second_direction != Vector3.ZERO:
				main_line.rotation_degrees = _player_second_direction

	# Clear death particles
	get_tree().call_group("death_particles", "queue_free")

	# Kill all tweens
	for tween in get_tree().get_processed_tweens():
		tween.kill()

	# Restore camera
	if not UsingOldCameraFollower:
		var cf := CameraFollower.instance
		if cf:
			cf.kill_all_camera_tweens()
			cf.reset_shake()
			cf.position = main_line.position + camera_new.offset
			if cf.rotator:
				cf.rotator.rotation_degrees = camera_new.rotation
			if cf.camera:
				cf.camera.fov = camera_new.fov
			cf.follow = camera_new.follow
	else:
		var ocf := OldCameraFollower.instance
		if ocf:
			LevelManager.load_to_camera_follower(ocf)
			ocf.position = main_line.position + ocf.add_position
			ocf.rotation_degrees = LevelManager.camera_checkpoint.rotation_degrees
			ocf._checkpoint_applied = false
			ocf.following = true
			ocf._is_rotating = false

	# Restore settings
	if not manual_camera:
		_restore_camera()
	if not manual_fog:
		_restore_fog()
	if not manual_light:
		_restore_light()
	if not manual_ambient:
		_restore_ambient()

	# Restore material colors
	for s in material_colors_auto:
		s.apply()
	for s in material_colors_manual:
		s.apply()

	# Stop and reset music
	var music_player := main_line.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player:
		music_player.stop()
		music_player.pitch_scale = 1.0

	# Stop animation
	if main_line.animation_node and main_line.animation_node.has_animation("level"):
		main_line.animation_node.stop()

	LevelManager.game_state = LevelManager.GameStatus.Waiting
	LevelManager.emit_revive()

	on_revive.emit()
