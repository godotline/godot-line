@tool
extends Node3D
## Gem - 宝石收集物
## 参考 Unity Gem.cs 实现，支持 fake 属性和复活恢复

const FRAGMENT_SCENE: PackedScene = preload("res://#Template/[Resources]/GemFragment.tscn")
const FRAGMENT_COUNT_MIN: int = 20
const FRAGMENT_COUNT_MAX: int = 25
const FRAGMENT_START_SPEED_MIN: float = 1.0
const FRAGMENT_START_SPEED_MAX: float = 3.0
const FRAGMENT_AXIS_SPEED_MIN: float = -4.0
const FRAGMENT_AXIS_SPEED_MAX: float = 4.0
const FRAGMENT_CONE_ANGLE_RADIANS: float = PI / 6.0
const FRAGMENT_GRAVITY_SCALE: float = 1.5
const FRAGMENT_SCALE_MIN: float = 0.8
const FRAGMENT_SCALE_MAX: float = 1.2
const FRAGMENT_LIFETIME_MIN: float = 3.0
const FRAGMENT_LIFETIME_MAX: float = 5.0
const FRAGMENT_SHRINK_DURATION: float = 0.5
const FRAGMENT_TORQUE_SCALE: float = 0.2
const COLLECTION_LIGHT_DURATION: float = 0.5
const COLLECTION_LIGHT_ENERGY: float = 6.0
const MAX_GEM_COUNT: int = 10
const DEFAULT_ROTATION_SPEED_RADIANS: float = 0.6981317
const SPRIRT_LIFETIME: float = 7.0
const SPRIRT_GRAVITY: float = -0.5
const SPRIRT_VELOCITY_X_MAX: float = 10.0
const SPRIRT_VELOCITY_Y_MAX: float = 50.0
const SPRIRT_VELOCITY_Z_MAX: float = 50.0

@export var speed: float = DEFAULT_ROTATION_SPEED_RADIANS
@export var fake: bool = false

var got: bool = false
var countedInGemTotal: bool = false
var index: int = -1
var collectionLightElapsed: float = COLLECTION_LIGHT_DURATION
var sprirtActive: bool = false
var sprirtElapsed: float = SPRIRT_LIFETIME
var sprirtVelocity: Vector3 = Vector3.ZERO

var contentRoot: Node3D
var triggerArea: Area3D
var sprirt: CPUParticles3D
var tail: CPUParticles3D
var aura: CPUParticles3D
var gemLight: OmniLight3D
var spawnedFragments: Array[RigidBody3D] = []

func _ready() -> void:
	contentRoot = _resolve_content_root()
	triggerArea = get_parent() as Area3D
	sprirt = contentRoot.get_node_or_null("Sprirt") as CPUParticles3D
	tail = contentRoot.get_node_or_null("Tail") as CPUParticles3D
	aura = contentRoot.get_node_or_null("Aura") as CPUParticles3D
	gemLight = contentRoot.get_node_or_null("GemLight") as OmniLight3D
	if not sprirt or not tail or not aura or not gemLight:
		push_error("Gem.gd: 收集物视觉节点不完整")
		return
	_reset_collection_effect()

func _resolve_content_root() -> Node3D:
	var area: Area3D = get_parent() as Area3D
	if area and area.get_parent() is Node3D:
		return area.get_parent() as Node3D
	return self

func trigger(body: Node3D) -> bool:
	return _on_body_entered(body)

func _on_body_entered(body: Node3D) -> bool:
	if got or fake or body != Player.instance:
		return false
	got = true
	index = LevelManager.checkpointCount
	_set_monitoring(false)
	countedInGemTotal = LevelManager.gem < MAX_GEM_COUNT
	if countedInGemTotal:
		LevelManager.gem += 1
	if Player.instance:
		Player.instance.emitGameEvent(6)
	var mesh: MeshInstance3D = contentRoot.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.visible = false
	var animPlayer: AnimationPlayer = contentRoot.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animPlayer:
		animPlayer.play("diamond")
	if GraphicsQuality.qualityLevel > 0:
		_start_collection_effect()
		_spawn_fragments()
	# 注册复活回调
	LevelManager.add_revive_listener(_on_revive)
	return true

func _start_collection_effect() -> void:
	var effectOrigin: Vector3 = contentRoot.global_position
	sprirt.global_transform = Transform3D(Basis.IDENTITY, effectOrigin + Vector3(
		randf_range(-0.5, 0.5),
		randf_range(-0.5, 0.5),
		randf_range(-0.5, 0.5)
	))
	sprirtVelocity = Vector3(
		randf_range(0.0, SPRIRT_VELOCITY_X_MAX),
		randf_range(0.0, SPRIRT_VELOCITY_Y_MAX),
		randf_range(0.0, SPRIRT_VELOCITY_Z_MAX)
	)
	sprirtElapsed = 0.0
	sprirtActive = true
	sprirt.restart()
	sprirt.emitting = true

	tail.global_transform = Transform3D(Basis.IDENTITY, sprirt.global_position)
	tail.restart()
	tail.emitting = true

	aura.global_transform = Transform3D(Basis.IDENTITY, effectOrigin)
	aura.restart()
	aura.emitting = true

	collectionLightElapsed = 0.0
	gemLight.omni_range = 4.0
	gemLight.light_energy = COLLECTION_LIGHT_ENERGY
	gemLight.visible = true

func _update_sprirt(delta: float) -> void:
	if not sprirtActive:
		return
	sprirtVelocity.y += SPRIRT_GRAVITY * delta
	var endPosition: Vector3 = sprirt.global_position + sprirtVelocity * delta
	sprirt.global_position = endPosition
	tail.global_position = endPosition
	sprirtElapsed += delta
	if sprirtElapsed >= SPRIRT_LIFETIME:
		sprirtActive = false
		sprirt.emitting = false
		tail.emitting = false

func _spawn_fragments() -> void:
	var fragmentParent: Node = contentRoot.get_parent()
	var fragmentCount: int = randi_range(FRAGMENT_COUNT_MIN, FRAGMENT_COUNT_MAX)
	var sourceMesh: MeshInstance3D = contentRoot.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var sourceMaterial: Material = sourceMesh.get_active_material(0) if sourceMesh else null
	for index: int in fragmentCount:
		var fragment: RigidBody3D = FRAGMENT_SCENE.instantiate() as RigidBody3D
		fragment.name = "GemFragment_%02d" % index
		fragmentParent.add_child(fragment)
		spawnedFragments.append(fragment)
		fragment.global_position = contentRoot.global_position
		var scaleFactor: float = randf_range(FRAGMENT_SCALE_MIN, FRAGMENT_SCALE_MAX)
		var fragmentMesh: MeshInstance3D = fragment.get_node("MeshInstance3D") as MeshInstance3D
		fragmentMesh.scale *= scaleFactor
		if sourceMaterial:
			fragmentMesh.material_override = sourceMaterial

		# Unity GetGem：30° 向上圆锥初速 1–3，再叠加世界 XYZ 各 -4–4。
		var azimuth: float = randf_range(0.0, TAU)
		var cosAngle: float = randf_range(cos(FRAGMENT_CONE_ANGLE_RADIANS), 1.0)
		var sinAngle: float = sqrt(1.0 - cosAngle * cosAngle)
		var coneDirection: Vector3 = Vector3(cos(azimuth) * sinAngle, cosAngle, sin(azimuth) * sinAngle)
		var startSpeed: float = randf_range(FRAGMENT_START_SPEED_MIN, FRAGMENT_START_SPEED_MAX)
		var launchVelocity: Vector3 = coneDirection * startSpeed + Vector3(
			randf_range(FRAGMENT_AXIS_SPEED_MIN, FRAGMENT_AXIS_SPEED_MAX),
			randf_range(FRAGMENT_AXIS_SPEED_MIN, FRAGMENT_AXIS_SPEED_MAX),
			randf_range(FRAGMENT_AXIS_SPEED_MIN, FRAGMENT_AXIS_SPEED_MAX)
		)
		fragment.gravity_scale = FRAGMENT_GRAVITY_SCALE
		fragment.apply_central_impulse(launchVelocity * fragment.mass)
		fragment.apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * FRAGMENT_TORQUE_SCALE)

		var fragmentLifetime: float = randf_range(FRAGMENT_LIFETIME_MIN, FRAGMENT_LIFETIME_MAX)
		var shrinkTween: Tween = fragment.create_tween()
		shrinkTween.tween_interval(fragmentLifetime)
		shrinkTween.tween_property(fragmentMesh, "scale", Vector3.ZERO, FRAGMENT_SHRINK_DURATION)
		shrinkTween.finished.connect(fragment.queue_free)

func _on_revive() -> void:
	# Unity Gem.ResetData: 复活时销毁收集特效 (Destroy(effect))
	_clear_fragments()
	# 只有在宝石之后存档才恢复（存档点索引 >= 宝石索引）
	var shouldRestore: bool = index >= LevelManager.checkpointCount
	if shouldRestore:
		# 宝石在存档点之前，需要恢复
		got = false
		var mesh: MeshInstance3D = contentRoot.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh:
			mesh.visible = true
		var animPlayer: AnimationPlayer = contentRoot.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if animPlayer:
			animPlayer.play("RESET")
		_set_monitoring(true)
		if countedInGemTotal:
			LevelManager.gem = maxi(LevelManager.gem - 1, 0)
			countedInGemTotal = false
	_reset_collection_effect()
	LevelManager.remove_revive_listener(_on_revive)

func _clear_fragments() -> void:
	for fragment: RigidBody3D in spawnedFragments:
		if is_instance_valid(fragment):
			fragment.queue_free()
	spawnedFragments.clear()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not contentRoot or not sprirt:
		return
	_update_sprirt(delta)
	if collectionLightElapsed < COLLECTION_LIGHT_DURATION:
		collectionLightElapsed += delta
		var lightProgress: float = clampf(collectionLightElapsed / COLLECTION_LIGHT_DURATION, 0.0, 1.0)
		gemLight.light_energy = lerpf(COLLECTION_LIGHT_ENERGY, 0.0, lightProgress)
		if collectionLightElapsed >= COLLECTION_LIGHT_DURATION:
			gemLight.visible = false
	if not contentRoot.visible:
		return
	contentRoot.rotate_y(delta * speed)

func _reset_collection_effect() -> void:
	if not sprirt or not tail or not aura or not gemLight:
		return
	sprirtActive = false
	sprirtElapsed = SPRIRT_LIFETIME
	sprirt.emitting = false
	tail.emitting = false
	aura.emitting = false
	collectionLightElapsed = COLLECTION_LIGHT_DURATION
	gemLight.light_energy = 0.0
	gemLight.omni_range = 0.0
	gemLight.visible = false

func _set_monitoring(value: bool) -> void:
	if triggerArea:
		triggerArea.set_deferred("monitoring", value)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_on_revive)
