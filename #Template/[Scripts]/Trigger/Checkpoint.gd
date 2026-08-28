extends Node3D
class_name Checkpoint

enum Direction { First, Second }

@export var AutoRecord: bool = false
@export var GameTime: float = 0.0
@export var playerSpeed: float = 12.0
@export var usingOldCameraFollower: bool = false

@export_group("Player")
@export var direction: Direction = Direction.First

@export var cameraNew: CameraSettings = CameraSettings.new()
@export var cameraOld: OldCameraSettings = OldCameraSettings.new()
@export var manualCamera: bool = false

@export var fog: FogSettings = FogSettings.new()
@export var manualFog: bool = false

@export var light: LightSettings = LightSettings.new()
@export var manualLight: bool = false

@export var ambient: AmbientSettings = AmbientSettings.new()
@export var manualAmbient: bool = false

@export_group("Colors")
@export var materialColorsAuto: Array[SingleColor] = []
@export var materialColorsManual: Array[SingleColor] = []
@export var imageColorsAuto: Array[SingleImageColor] = []
@export var imageColorsManual: Array[SingleImageColor] = []

const REVIVE_FADE_DURATION: float = 0.32

signal on_revive

var used: bool = false
var usedRevive: bool = false

var trackProgress: float = 0.0
var sceneGravity: Vector3 = Vector3.ZERO
var gravityCaptured: bool = false
var playerFirstDirection: Vector3 = Vector3.ZERO
var playerSecondDirection: Vector3 = Vector3.ZERO
var fakePlayersData: Array[Dictionary] = []
var materialColorsAutoStates: Array[Dictionary] = []
var imageColorsAutoStates: Array[Dictionary] = []

var revivePosition: Node3D
var checkpointContainer: Node3D

func _ready() -> void:
	checkpointContainer = _resolve_checkpoint_container()
	revivePosition = checkpointContainer.get_node_or_null("RevivePosition") as Node3D
	if revivePosition:
		revivePosition.visible = false

func _resolve_checkpoint_container() -> Node3D:
	var parentArea: Area3D = get_parent() as Area3D
	if parentArea:
		var container: Node3D = parentArea.get_parent() as Node3D
		if container:
			return container
	return self

func trigger(body: Node3D) -> bool:
	return _on_checkpoint_body_entered(body)

func _on_checkpoint_body_entered(body: Node3D) -> bool:
	if used:
		return false
	if not body is Player:
		push_error("Checkpoint.gd: 进入触发器的不是 Player 类型，无法保存检查点")
		return false
	_enter_trigger(body)
	return true

func _enter_trigger(body: Node3D) -> void:
	used = true
	LevelManager.currentCheckpoint = self
	LevelManager.checkpointCount += 1
	_capture_set_actives()
	_capture_play_animators()

	# Capture camera settings
	if not manualCamera:
		if not usingOldCameraFollower:
			if CameraFollower.instance:
				cameraNew = cameraNew.get_camera()
		else:
			if OldCameraFollower.instance:
				cameraOld = cameraOld.get_camera()

	if not manualFog:
		_capture_fog()
	if not manualLight:
		_capture_light()
	if not manualAmbient:
		_capture_ambient()

	# Capture the values at the checkpoint. Manual settings are applied only on revive.
	_capture_material_colors()
	_capture_image_colors()

	# Save player state
	playerFirstDirection = body.firstDirection
	playerSecondDirection = body.secondDirection
	# AutoRecord 关闭时按检查点授权的音乐时间记录时间轴进度（对齐 Unity GetTimelineProgresses(AutoRecord, GameTime)）
	body.GetAnimatorProgresses()
	Timeline.GetTimelineProgresses(AutoRecord, GameTime)
	trackProgress = body.animationNode.get_current_animation_position() if body.animationNode and body.animationNode.is_playing() else 0.0
	sceneGravity = body.get_current_gravity()
	gravityCaptured = true

	if AutoRecord:
		GameTime = AudioManager.time
	playerSpeed = body.Speed
	if AutoRecord:
		direction = Direction.First if body._currentDirection == 0 else Direction.Second
		TemplateCheckpointCapture.capture(self)

	# Save to LevelManager (OldCameraFollower only, new camera stores in cameraNew)
	if usingOldCameraFollower:
		LevelManager.save_checkpoint(body, OldCameraFollower.instance, revivePosition)
	else:
		LevelManager.save_checkpoint(body, null, revivePosition)
	LevelManager.musicCheckpointTime = GameTime
	LevelManager.gravity = sceneGravity

	# Save FakePlayer states
	fakePlayersData.clear()
	var fakePlayers: Array[Node] = body.get_tree().get_nodes_in_group("fake_players")
	for fp: Node in fakePlayers:
		var fake: FakePlayer = fp as FakePlayer
		if fake:
			fakePlayersData.append(fake.get_reset_data())

	# 对齐 Unity：保存所有时间轴切换器的轨道状态
	for tsNode: Node in get_tree().get_nodes_in_group("timeline_track_switchers"):
		var switcher: TrackSwitcher = tsNode as TrackSwitcher
		if switcher:
			switcher.SaveState()

func _capture_set_actives() -> void:
	for component: Node in get_tree().get_nodes_in_group("checkpoint_actives"):
		if component.has_method("capture_checkpoint_state"):
			component.call("capture_checkpoint_state")

func _capture_play_animators() -> void:
	for component: Node in get_tree().get_nodes_in_group("checkpoint_animators"):
		if component.has_method("capture_checkpoint_state"):
			component.call("capture_checkpoint_state")

func _restore_play_animators() -> void:
	for component: Node in get_tree().get_nodes_in_group("checkpoint_animators"):
		if component.has_method("restore_checkpoint_state"):
			component.call("restore_checkpoint_state")

func _capture_material_colors() -> void:
	materialColorsAutoStates.clear()
	for setting: SingleColor in materialColorsAuto:
		if not setting:
			continue
		var state: Dictionary = setting.capture_state()
		if not state.is_empty():
			materialColorsAutoStates.append(state)

func _resolve_image_target(setting: SingleImageColor) -> CanvasItem:
	if not setting or setting.target.is_empty():
		return null
	return get_node_or_null(setting.target) as CanvasItem

func _capture_image_colors() -> void:
	imageColorsAutoStates.clear()
	for setting: SingleImageColor in imageColorsAuto:
		var image: CanvasItem = _resolve_image_target(setting)
		if image:
			imageColorsAutoStates.append({
				"image": image,
				"modulate": image.modulate,
			})

func _capture_fog() -> void:
	var env: Environment = _get_scene_environment()
	if env:
		fog.useFog = env.fog_enabled
		fog.fogColor = env.fog_light_color
		fog.start = env.fog_depth_begin
		fog.end = env.fog_depth_end

func _capture_light() -> void:
	var mainLine: Player = Player.instance
	if mainLine:
		var sceneLight: DirectionalLight3D = mainLine.get_scene_light()
		if sceneLight:
			light.rotation = sceneLight.rotation
			light.color = sceneLight.light_color
			light.intensity = sceneLight.light_energy
			light.shadowStrength = 1.0 if sceneLight.shadow_enabled else 0.0

func _capture_ambient() -> void:
	var env: Environment = _get_scene_environment()
	if env:
		ambient.intensity = env.ambient_light_energy
		match env.ambient_light_source:
			Environment.AMBIENT_SOURCE_BG:
				ambient.lightingType = AmbientSettings.EnvironmentLightingType.Skybox
			Environment.AMBIENT_SOURCE_COLOR:
				ambient.lightingType = AmbientSettings.EnvironmentLightingType.Color
				ambient.ambientColor = env.ambient_light_color
			Environment.AMBIENT_SOURCE_SKY:
				ambient.lightingType = AmbientSettings.EnvironmentLightingType.Skybox
			_:
				ambient.lightingType = AmbientSettings.EnvironmentLightingType.Color

func _restore_camera() -> void:
	if not usingOldCameraFollower:
		if CameraFollower.instance:
			cameraNew.set_camera()
	else:
		if OldCameraFollower.instance:
			cameraOld.set_camera()

func _restore_fog() -> void:
	var env: Environment = _get_scene_environment()
	if env:
		env.fog_enabled = fog.useFog
		env.fog_light_color = fog.fogColor
		env.fog_depth_begin = fog.start
		env.fog_depth_end = fog.end
		env.background_color = fog.fogColor

func _restore_light() -> void:
	var mainLine: Player = Player.instance
	if mainLine:
		light.apply(mainLine.get_scene_light())

func _restore_ambient() -> void:
	var env: Environment = _get_scene_environment()
	if env:
		env.ambient_light_energy = ambient.intensity
		match ambient.lightingType:
			AmbientSettings.EnvironmentLightingType.Skybox:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			AmbientSettings.EnvironmentLightingType.Color:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_color = ambient.ambientColor
			AmbientSettings.EnvironmentLightingType.Gradient:
				env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				env.ambient_light_sky_color = ambient.skyColor
				env.ambient_light_horizon_color = ambient.equatorColor
				env.ambient_light_ground_color = ambient.groundColor

func _restore_gravity(mainLine: Player) -> void:
	if not gravityCaptured:
		return

	LevelManager.gravity = sceneGravity
	var space: RID = mainLine.get_world_3d().space
	if space.is_valid():
		PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, sceneGravity.length())
		PhysicsServer3D.area_set_param(
			space,
			PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR,
			sceneGravity.normalized() if sceneGravity.length() > 0.0 else Vector3.DOWN
		)

	var levelGravity: Vector3 = mainLine.levelData.gravity if mainLine.levelData else Vector3(0.0, -9.8, 0.0)
	if levelGravity.is_equal_approx(sceneGravity):
		mainLine.clear_gravity_override()
	else:
		mainLine.set_gravity_override(sceneGravity)

func _restore_player_collider(mainLine: Player) -> void:
	if not mainLine.levelData:
		return
	var collision: CollisionShape3D = mainLine.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = mainLine.levelData.playerHeadBoxColliderSize

func _get_scene_environment() -> Environment:
	var mainLine: Player = Player.instance
	if mainLine:
		return mainLine.get_scene_environment()
	return get_viewport().get_world_3d().environment

func revive() -> void:
	var mainLine: Player = Player.instance
	if not mainLine:
		return
	LevelManager.isEnd = false

	# Unity parity: DOTween.Clear() runs before HideScreen creates its fade tween.
	for tween: Tween in get_tree().get_processed_tweens():
		tween.kill()

	# Unity consumes one collected crown on the first revive at this checkpoint.
	# Crown count is not a gate: the checkpoint itself determines revive eligibility.
	if not usedRevive:
		LevelManager.crown = maxi(LevelManager.crown - 1, 0)
		usedRevive = true

	# Unity parity: the scene reset runs hidden behind a fog-colored screen fade
	# (LevelUI.HideScreen). The player only regains turning control once the
	# screen has fully revealed the restored scene.
	var ui: LevelUI = LevelUI.instance
	if ui:
		ui.HideScreen(
			fog.fogColor if fog else Color(0, 0, 0, 1),
			REVIVE_FADE_DURATION,
			func() -> void: _reset_scene(mainLine),
			func() -> void:
				mainLine.allowTurn = true
				ui.visible = false
		)
	else:
		_reset_scene(mainLine)
		mainLine.allowTurn = true

func _reset_scene(mainLine: Player) -> void:
	# Restore player state
	LevelManager.load_checkpoint_to_main_line(mainLine)
	if revivePosition:
		mainLine.global_position = revivePosition.global_position
	mainLine.Speed = playerSpeed
	_restore_gravity(mainLine)
	mainLine.isLive = true
	mainLine.isEnd = false
	mainLine.velocity = Vector3.ZERO
	mainLine.gameStarts = false
	mainLine.delayApplied = false
	mainLine.scale = Vector3.ONE
	mainLine._clear_tail()
	Engine.time_scale = 1.0

	# Unity parity: the checkpoint direction is authoritative on revive.
	# InitPlayerPosition restores the direction parameters, then applies the
	# serialized checkpoint direction to both the player's rotation and state.
	mainLine._currentDirection = 0 if direction == Direction.First else 1
	mainLine.rotation_degrees = mainLine.currentDirection

	# Clear death particles
	get_tree().call_group("death_particles", "queue_free")

	# Restore camera
	if not usingOldCameraFollower:
		var cf: CameraFollower = CameraFollower.instance
		if cf:
			cf.KillAllCameraTweens()
			cf.ResetShake()
			cf.global_position = mainLine.global_position
	else:
		var ocf: OldCameraFollower = OldCameraFollower.instance
		if ocf:
			ocf.KillAll()
			ocf.ResetShake()
			LevelManager.load_to_camera_follower(ocf)
			ocf.global_position = mainLine.global_position
			if ocf.rotator:
				ocf.rotator.rotation_degrees = LevelManager.cameraCheckpoint.rotation_degrees
			ocf.checkpointApplied = false
			ocf.follow = true
			ocf.isRotating = false

	# Restore settings
	# Manual flags control checkpoint capture; configured values are always applied on revive.
	_restore_camera()
	_restore_fog()
	_restore_light()
	_restore_ambient()
	_restore_player_collider(mainLine)
	mainLine.SetAnimatorProgresses()
	Timeline.SetTimelineProgresses()

	# 对齐 Unity：恢复时间轴切换器轨道状态（在位置恢复之后，保持播放头不重置）
	for tsNode: Node in get_tree().get_nodes_in_group("timeline_track_switchers"):
		var switcher: TrackSwitcher = tsNode as TrackSwitcher
		if switcher:
			switcher.RestoreState()

	# Restore material colors
	for state: Dictionary in materialColorsAutoStates:
		var setting: SingleColor = state.get("setting") as SingleColor
		if setting:
			setting.restore_state(state)
	for setting: SingleColor in materialColorsManual:
		if setting:
			setting.apply()

	# Restore UI image colors captured at this checkpoint.
	for state: Dictionary in imageColorsAutoStates:
		var image: CanvasItem = state.get("image") as CanvasItem
		var modulate: Variant = state.get("modulate", Color.WHITE)
		if image and modulate is Color:
			image.modulate = modulate
	for setting: SingleImageColor in imageColorsManual:
		var image: CanvasItem = _resolve_image_target(setting)
		if image and setting:
			image.modulate = setting.color

	# Restore FakePlayers
	var fakePlayers: Array[Node] = mainLine.get_tree().get_nodes_in_group("fake_players")
	for i: int in range(min(fakePlayers.size(), fakePlayersData.size())):
		var fake: FakePlayer = fakePlayers[i] as FakePlayer
		if fake:
			fake.set_reset_data(fakePlayersData[i])

	# Restore music to checkpoint position (paused, waiting for player to start)
	var musicPlayer: AudioStreamPlayer = mainLine.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if musicPlayer:
		musicPlayer.stop()
		musicPlayer.volume_db = 0.0
		musicPlayer.pitch_scale = 1.0
		# Set music to checkpoint position but don't play yet
		var musicTime: float = LevelManager.musicCheckpointTime
		if musicTime > 0.0 and mainLine.levelData and mainLine.levelData.levelAudioClip:
			musicPlayer.stream = mainLine.levelData.levelAudioClip
			# Play then immediately pause to set the position
			musicPlayer.play(musicTime)
			musicPlayer.stream_paused = true

	# Restore animation to checkpoint position (paused, waiting for player to start)
	if mainLine.animationNode and mainLine.animationNode.has_animation("level"):
		if trackProgress > 0.0:
			mainLine.animationNode.play("level")
			mainLine.animationNode.seek(trackProgress, true)
			mainLine.animationNode.pause()
			LevelManager.animTime = trackProgress
		else:
			mainLine.animationNode.stop()
			LevelManager.animTime = 0.0

	_restore_play_animators()
	on_revive.emit()
	LevelManager.emit_revive()
	LevelManager.DestroyRemain()
