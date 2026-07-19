@tool
extends Area3D
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

@export var speed: float = 40.0
@export var scan_duration: float = 1.25
@export var scan_max_radius: float = 28.0

var _collected: bool = false
var _checkpoint_index: int = -1
var _scan_elapsed: float = 0.0
var _scan_material: ShaderMaterial
var _lightning_elapsed: float = LIGHTNING_DURATION

func _ready() -> void:
	_apply_crystal_material($Hexahedron)
	_scan_material = $ScanQuad.material_override as ShaderMaterial
	$CrystalThunder.visible = false
	$Aura.emitting = false
	$CrystalLight.visible = false
	_reset_scan()
	if not Engine.is_editor_hint():
		LevelManager.add_revive_listener(_on_revive)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		LevelManager.remove_revive_listener(_on_revive)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	rotate_y(deg_to_rad(speed) * delta)
	if _scan_elapsed < scan_duration:
		_scan_elapsed += delta
		var progress: float = clampf(_scan_elapsed / scan_duration, 0.0, 1.0)
		_scan_material.set_shader_parameter("scan_origin", global_position)
		_scan_material.set_shader_parameter("scan_radius", lerpf(0.0, scan_max_radius, progress))
		var fade_progress: float = inverse_lerp(0.7, 1.0, progress)
		_scan_material.set_shader_parameter("scan_strength", 1.0 - smoothstep(0.0, 1.0, fade_progress))
	else:
		$ScanQuad.visible = false
	if _lightning_elapsed < LIGHTNING_DURATION:
		_lightning_elapsed += delta
		var light_progress: float = clampf(_lightning_elapsed / LIGHTNING_DURATION, 0.0, 1.0)
		$CrystalLight.light_energy = lerpf(COLLECTION_LIGHT_ENERGY, 0.0, light_progress)
		if _lightning_elapsed >= LIGHTNING_DURATION:
			$CrystalThunder.visible = false
			$Aura.emitting = false
			$CrystalLight.visible = false

func _on_body_entered(body: Node3D) -> void:
	if _collected or body != Player.instance:
		return
	_collected = true
	_checkpoint_index = LevelManager.checkpoint_count
	set_deferred("monitoring", false)
	_set_crystal_mesh_visible(false)
	if Player.instance and Player.instance.has_signal("on_get_gem"):
		# Crystal 使用与 Unity 事件 6 对应的收集通知；当前模板没有独立 Crystal 信号。
		Player.instance.on_get_gem.emit()
	_start_scan()
	_start_lightning()
	_spawn_fragments()

func _spawn_fragments() -> void:
	var fragment_parent: Node = get_parent()
	var fragment_count: int = randi_range(FRAGMENT_COUNT_MIN, FRAGMENT_COUNT_MAX)
	var source_mesh: MeshInstance3D = $Hexahedron as MeshInstance3D
	var source_material: Material = source_mesh.get_active_material(0)
	for index in fragment_count:
		var fragment: RigidBody3D = FRAGMENT_SCENE.instantiate() as RigidBody3D
		fragment.name = "CrystalFragment_%02d" % index
		fragment_parent.add_child(fragment)
		fragment.global_position = global_position
		var scale_factor: float = randf_range(FRAGMENT_SCALE_MIN, FRAGMENT_SCALE_MAX)
		var fragment_mesh: MeshInstance3D = fragment.get_node("MeshInstance3D") as MeshInstance3D
		fragment_mesh.scale *= scale_factor
		fragment_mesh.material_override = source_material

		# FX_GetCrystal 内嵌 GetGem：30° 向上圆锥初速改为 2–5，XYZ 仍各 -4–4。
		var azimuth: float = randf_range(0.0, TAU)
		var cos_angle: float = randf_range(cos(FRAGMENT_CONE_ANGLE_RADIANS), 1.0)
		var sin_angle: float = sqrt(1.0 - cos_angle * cos_angle)
		var cone_direction: Vector3 = Vector3(cos(azimuth) * sin_angle, cos_angle, sin(azimuth) * sin_angle)
		var start_speed: float = randf_range(FRAGMENT_START_SPEED_MIN, FRAGMENT_START_SPEED_MAX)
		var launch_velocity: Vector3 = cone_direction * start_speed + Vector3(
			randf_range(FRAGMENT_AXIS_SPEED_MIN, FRAGMENT_AXIS_SPEED_MAX),
			randf_range(FRAGMENT_AXIS_SPEED_MIN, FRAGMENT_AXIS_SPEED_MAX),
			randf_range(FRAGMENT_AXIS_SPEED_MIN, FRAGMENT_AXIS_SPEED_MAX)
		)
		fragment.gravity_scale = FRAGMENT_GRAVITY_SCALE
		fragment.apply_central_impulse(launch_velocity * fragment.mass)
		fragment.apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * FRAGMENT_TORQUE_SCALE)

		var fragment_lifetime: float = randf_range(FRAGMENT_LIFETIME_MIN, FRAGMENT_LIFETIME_MAX)
		var shrink_tween: Tween = fragment.create_tween()
		shrink_tween.tween_interval(fragment_lifetime)
		shrink_tween.tween_property(fragment_mesh, "scale", Vector3.ZERO, FRAGMENT_SHRINK_DURATION)
		shrink_tween.finished.connect(fragment.queue_free)

func _start_scan() -> void:
	_scan_elapsed = 0.0
	_scan_material.set_shader_parameter("scan_origin", global_position)
	_scan_material.set_shader_parameter("scan_radius", 0.0)
	_scan_material.set_shader_parameter("scan_strength", 1.0)
	$ScanQuad.visible = true

func _start_lightning() -> void:
	_lightning_elapsed = 0.0
	$CrystalThunder.visible = true
	$Aura.global_transform = Transform3D(Basis.IDENTITY, global_position)
	$Aura.restart()
	$Aura.emitting = true
	$CrystalLight.light_energy = COLLECTION_LIGHT_ENERGY
	$CrystalLight.visible = true

func _on_revive() -> void:
	LevelManager.CompareCheckpointIndex(_checkpoint_index, func():
		_collected = false
		_set_crystal_mesh_visible(true)
		set_deferred("monitoring", true)
		_reset_scan()
	)

func _reset_scan() -> void:
	_scan_elapsed = scan_duration
	if _scan_material:
		_scan_material.set_shader_parameter("scan_origin", global_position)
		_scan_material.set_shader_parameter("scan_radius", -1.0)
		_scan_material.set_shader_parameter("scan_strength", 0.0)
	$ScanQuad.visible = false
	$CrystalThunder.visible = false
	$Aura.restart()
	$Aura.emitting = false
	$CrystalLight.light_energy = 0.0
	$CrystalLight.visible = false

func _set_crystal_mesh_visible(value: bool) -> void:
	$Hexahedron.visible = value

func _apply_crystal_material(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = preload("res://#Template/[Materials]/CrystalGradientMaterial.tres")
	for child in node.get_children():
		_apply_crystal_material(child)
