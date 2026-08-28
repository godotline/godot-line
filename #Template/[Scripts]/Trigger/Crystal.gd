@tool
extends Node3D
## Crystal - 水晶收集物
## 对齐 Unity Crystal：触碰后隐藏，并在复活时按检查点恢复。

const FRAGMENT_SCENE: PackedScene = preload("res://#Template/[Resources]/GemFragment.tscn")
const FRAGMENT_COUNT_MIN: int = 20
const FRAGMENT_COUNT_MAX: int = 25
const FRAGMENT_START_SPEED_MIN: float = 2.0
const FRAGMENT_START_SPEED_MAX: float = 5.0
const FRAGMENT_AXIS_SPEED_MIN: float = -4.0
const FRAGMENT_AXIS_SPEED_MAX: float = 4.0
const FRAGMENT_CONE_ANGLE_RADIANS: float = PI / 6.0
const FRAGMENT_GRAVITY_SCALE: float = 1.5
const FRAGMENT_SCALE_MIN: float = 1.0
const FRAGMENT_SCALE_MAX: float = 1.5
const FRAGMENT_LIFETIME_MIN: float = 3.0
const FRAGMENT_LIFETIME_MAX: float = 5.0
const FRAGMENT_SHRINK_DURATION: float = 0.5
const FRAGMENT_TORQUE_SCALE: float = 0.2
const LIGHTNING_DURATION: float = 0.3
const COLLECTION_LIGHT_ENERGY: float = 6.0
const THUNDER_MATERIAL: Material = preload("res://#Template/[Materials]/CrystalThunder.tres")

@export var speed: float = 40.0
@export var scanDuration: float = 1.25
@export var scanMaxRadius: float = 28.0

var got: bool = false
var index: int = -1
var scanElapsed: float = 0.0
var scanMaterial: ShaderMaterial
var lightningElapsed: float = LIGHTNING_DURATION
var contentRoot: Node3D
var triggerArea: Area3D
var hexahedron: MeshInstance3D
var scanQuad: MeshInstance3D
var crystalThunder: MeshInstance3D
var aura: CPUParticles3D
var crystalLight: OmniLight3D
var spawnedFragments: Array[RigidBody3D] = []

func _ready() -> void:
	contentRoot = _resolve_content_root()
	triggerArea = get_parent() as Area3D
	hexahedron = contentRoot.get_node_or_null("Hexahedron") as MeshInstance3D
	scanQuad = contentRoot.get_node_or_null("ScanQuad") as MeshInstance3D
	aura = contentRoot.get_node_or_null("Aura") as CPUParticles3D
	if not hexahedron or not scanQuad or not aura:
		push_error("Crystal.gd: 收集物视觉节点不完整")
		return
	_apply_crystal_material(hexahedron)
	scanMaterial = scanQuad.material_override as ShaderMaterial
	aura.emitting = false
	_reset_scan()
	if not Engine.is_editor_hint():
		LevelManager.add_revive_listener(_on_revive)

func _create_collection_effect_nodes() -> void:
	crystalThunder = contentRoot.get_node_or_null("CrystalThunder") as MeshInstance3D
	if not crystalThunder:
		crystalThunder = MeshInstance3D.new()
		crystalThunder.name = "CrystalThunder"
		# (4.8, 6, 4.8)：保留重构前 contentRoot 携带 0.8 缩放时的等效世界尺寸（6 × 0.8）
		crystalThunder.transform = Transform3D(Basis.from_scale(Vector3(4.8, 6.0, 4.8)), Vector3.ZERO)
		crystalThunder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lightningMesh: QuadMesh = QuadMesh.new()
		lightningMesh.size = Vector2(0.9, 2.7)
		lightningMesh.material = THUNDER_MATERIAL
		crystalThunder.mesh = lightningMesh
		contentRoot.add_child(crystalThunder)

	crystalLight = contentRoot.get_node_or_null("CrystalLight") as OmniLight3D
	if not crystalLight:
		crystalLight = OmniLight3D.new()
		crystalLight.name = "CrystalLight"
		crystalLight.omni_range = 4.0
		crystalLight.light_energy = 0.0
		crystalLight.visible = false
		contentRoot.add_child(crystalLight)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_on_revive)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not contentRoot or not scanMaterial:
		return
	contentRoot.rotate_y(deg_to_rad(speed) * delta)
	if scanElapsed < scanDuration:
		scanElapsed += delta
		var progress: float = clampf(scanElapsed / scanDuration, 0.0, 1.0)
		scanMaterial.set_shader_parameter("scan_origin", contentRoot.global_position)
		scanMaterial.set_shader_parameter("scan_radius", lerpf(0.0, scanMaxRadius, progress))
		var fadeProgress: float = inverse_lerp(0.7, 1.0, progress)
		scanMaterial.set_shader_parameter("scan_strength", 1.0 - smoothstep(0.0, 1.0, fadeProgress))
	else:
		scanQuad.visible = false
	if lightningElapsed < LIGHTNING_DURATION:
		lightningElapsed += delta
		var lightProgress: float = clampf(lightningElapsed / LIGHTNING_DURATION, 0.0, 1.0)
		if crystalLight:
			crystalLight.light_energy = lerpf(COLLECTION_LIGHT_ENERGY, 0.0, lightProgress)
		if lightningElapsed >= LIGHTNING_DURATION:
			if crystalThunder:
				crystalThunder.visible = false
			aura.emitting = false
			if crystalLight:
				crystalLight.visible = false

func _resolve_content_root() -> Node3D:
	var area: Area3D = get_parent() as Area3D
	if area and area.get_parent() is Node3D:
		return area.get_parent() as Node3D
	return self

func trigger(body: Node3D) -> bool:
	return _on_body_entered(body)

func _on_body_entered(body: Node3D) -> bool:
	if got or body != Player.instance:
		return false
	got = true
	index = LevelManager.checkpointCount
	_set_monitoring(false)
	_set_crystal_mesh_visible(false)
	if Player.instance:
		Player.instance.emitGameEvent(6)
	if GraphicsQuality.qualityLevel > 0:
		_start_scan()
		_start_lightning()
		_spawn_fragments()
	return true

func _spawn_fragments() -> void:
	var fragmentParent: Node = contentRoot.get_parent()
	var fragmentCount: int = randi_range(FRAGMENT_COUNT_MIN, FRAGMENT_COUNT_MAX)
	var sourceMesh: MeshInstance3D = hexahedron
	var sourceMaterial: Material = sourceMesh.get_active_material(0)
	for index: int in fragmentCount:
		var fragment: RigidBody3D = FRAGMENT_SCENE.instantiate() as RigidBody3D
		fragment.name = "CrystalFragment_%02d" % index
		fragmentParent.add_child(fragment)
		spawnedFragments.append(fragment)
		fragment.global_position = contentRoot.global_position
		var scaleFactor: float = randf_range(FRAGMENT_SCALE_MIN, FRAGMENT_SCALE_MAX)
		var fragmentMesh: MeshInstance3D = fragment.get_node("MeshInstance3D") as MeshInstance3D
		fragmentMesh.scale *= scaleFactor
		fragmentMesh.material_override = sourceMaterial

		# FX_GetCrystal 内嵌 GetGem：30° 向上圆锥初速改为 2–5，XYZ 仍各 -4–4。
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

func _start_scan() -> void:
	scanElapsed = 0.0
	scanMaterial.set_shader_parameter("scan_origin", contentRoot.global_position)
	scanMaterial.set_shader_parameter("scan_radius", 0.0)
	scanMaterial.set_shader_parameter("scan_strength", 1.0)
	scanQuad.visible = true

func _start_lightning() -> void:
	_create_collection_effect_nodes()
	lightningElapsed = 0.0
	crystalThunder.visible = true
	aura.global_transform = Transform3D(Basis.IDENTITY, contentRoot.global_position)
	aura.restart()
	aura.emitting = true
	crystalLight.light_energy = COLLECTION_LIGHT_ENERGY
	crystalLight.visible = true

func _on_revive() -> void:
	# Unity Crystal.ResetData: 复活时销毁收集特效 (Destroy(effect))
	for fragment: RigidBody3D in spawnedFragments:
		if is_instance_valid(fragment):
			fragment.queue_free()
	spawnedFragments.clear()
	LevelManager.CompareCheckpointIndex(index, func():
		got = false
		_set_crystal_mesh_visible(true)
		_set_monitoring(true)
		_reset_scan()
	)

func _reset_scan() -> void:
	scanElapsed = scanDuration
	if scanMaterial:
		scanMaterial.set_shader_parameter("scan_origin", contentRoot.global_position)
		scanMaterial.set_shader_parameter("scan_radius", -1.0)
		scanMaterial.set_shader_parameter("scan_strength", 0.0)
	scanQuad.visible = false
	if crystalThunder:
		crystalThunder.visible = false
	aura.emitting = false
	if crystalLight:
		crystalLight.light_energy = 0.0
		crystalLight.visible = false

func _set_crystal_mesh_visible(value: bool) -> void:
	hexahedron.visible = value

func _set_monitoring(value: bool) -> void:
	if triggerArea:
		triggerArea.set_deferred("monitoring", value)

func _apply_crystal_material(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = preload("res://#Template/[Materials]/CrystalGradientMaterial.tres")
	for child: Node in node.get_children():
		_apply_crystal_material(child)
