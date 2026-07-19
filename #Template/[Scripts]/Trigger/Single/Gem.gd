@tool
extends Area3D
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
const SPRIRT_LIFETIME: float = 7.0
const SPRIRT_GRAVITY: float = -0.5
const SPRIRT_VELOCITY_X_MAX: float = 10.0
const SPRIRT_VELOCITY_Y_MAX: float = 50.0
const SPRIRT_VELOCITY_Z_MAX: float = 50.0
const TAIL_RATE_OVER_DISTANCE: float = 30.0

@export var speed: float = 1.0
@export var fake: bool = false

var _collected: bool = false
var _checkpoint_index: int = -1
var _collection_light_elapsed: float = COLLECTION_LIGHT_DURATION
var _sprirt_active: bool = false
var _sprirt_elapsed: float = SPRIRT_LIFETIME
var _sprirt_velocity: Vector3 = Vector3.ZERO
var _tail_distance_remainder: float = 0.0

@onready var _sprirt: GPUParticles3D = $Sprirt
@onready var _tail: GPUParticles3D = $Tail
@onready var _aura: GPUParticles3D = $Aura
@onready var _gem_light: OmniLight3D = $GemLight

func _ready() -> void:
	_reset_collection_effect()

func _on_body_entered(body: Node) -> void:
	if _collected or fake or body != Player.instance:
		return
	_collected = true
	_checkpoint_index = LevelManager.checkpoint_count
	set_deferred("monitoring", false)
	LevelManager.gem += 1
	if Player.instance and Player.instance.has_signal("on_get_gem"):
		Player.instance.on_get_gem.emit()
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.visible = false
	var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player:
		anim_player.play("diamond")
	_start_collection_effect()
	_spawn_fragments()
	# 注册复活回调
	LevelManager.add_revive_listener(_on_revive)

func _start_collection_effect() -> void:
	var effect_origin: Vector3 = global_position
	_sprirt.global_transform = Transform3D(Basis.IDENTITY, effect_origin + Vector3(
		randf_range(-0.5, 0.5),
		randf_range(-0.5, 0.5),
		randf_range(-0.5, 0.5)
	))
	_sprirt_velocity = Vector3(
		randf_range(0.0, SPRIRT_VELOCITY_X_MAX),
		randf_range(0.0, SPRIRT_VELOCITY_Y_MAX),
		randf_range(0.0, SPRIRT_VELOCITY_Z_MAX)
	)
	_sprirt_elapsed = 0.0
	_sprirt_active = true
	_sprirt.restart()
	_sprirt.emitting = true

	_tail.global_transform = Transform3D(Basis.IDENTITY, _sprirt.global_position)
	_tail_distance_remainder = 0.0
	_tail.restart()
	_tail.emitting = false

	_aura.global_transform = Transform3D(Basis.IDENTITY, effect_origin)
	_aura.restart()
	_aura.emitting = true

	_collection_light_elapsed = 0.0
	_gem_light.light_energy = COLLECTION_LIGHT_ENERGY
	_gem_light.visible = true

func _update_sprirt(delta: float) -> void:
	if not _sprirt_active:
		return
	var start_position: Vector3 = _sprirt.global_position
	_sprirt_velocity.y += SPRIRT_GRAVITY * delta
	var end_position: Vector3 = start_position + _sprirt_velocity * delta
	_emit_tail_between(start_position, end_position)
	_sprirt.global_position = end_position
	_tail.global_position = end_position
	_sprirt_elapsed += delta
	if _sprirt_elapsed >= SPRIRT_LIFETIME:
		_sprirt_active = false
		_sprirt.emitting = false

func _emit_tail_between(start_position: Vector3, end_position: Vector3) -> void:
	var segment: Vector3 = end_position - start_position
	var segment_length: float = segment.length()
	if segment_length <= 0.000001:
		return
	var spacing: float = 1.0 / TAIL_RATE_OVER_DISTANCE
	var distance_along: float = spacing - _tail_distance_remainder
	var direction: Vector3 = segment / segment_length
	while distance_along <= segment_length:
		var emit_position: Vector3 = start_position + direction * distance_along
		_tail.global_position = emit_position
		_tail.emit_particle(Transform3D.IDENTITY, Vector3.ZERO, Color.WHITE, Color.WHITE, GPUParticles3D.EMIT_FLAG_POSITION)
		distance_along += spacing
	_tail_distance_remainder = fmod(_tail_distance_remainder + segment_length, spacing)

func _spawn_fragments() -> void:
	var fragment_parent: Node = get_parent()
	var fragment_count: int = randi_range(FRAGMENT_COUNT_MIN, FRAGMENT_COUNT_MAX)
	var source_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	var source_material: Material = source_mesh.get_active_material(0) if source_mesh else null
	for index in fragment_count:
		var fragment: RigidBody3D = FRAGMENT_SCENE.instantiate() as RigidBody3D
		fragment.name = "GemFragment_%02d" % index
		fragment_parent.add_child(fragment)
		fragment.global_position = global_position
		var scale_factor: float = randf_range(FRAGMENT_SCALE_MIN, FRAGMENT_SCALE_MAX)
		var fragment_mesh: MeshInstance3D = fragment.get_node("MeshInstance3D") as MeshInstance3D
		fragment_mesh.scale *= scale_factor
		if source_material:
			fragment_mesh.material_override = source_material

		# Unity GetGem：30° 向上圆锥初速 1–3，再叠加世界 XYZ 各 -4–4。
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

func _on_revive() -> void:
	# 只有在宝石之后存档才恢复（存档点索引 >= 宝石索引）
	if _checkpoint_index >= LevelManager.checkpoint_count:
		# 宝石在存档点之前，需要恢复
		_collected = false
		var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh:
			mesh.visible = true
		var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim_player:
			anim_player.play("RESET")
		_reset_collection_effect()
		set_deferred("monitoring", true)
		LevelManager.gem -= 1
	LevelManager.remove_revive_listener(_on_revive)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_sprirt(delta)
	if _collection_light_elapsed < COLLECTION_LIGHT_DURATION:
		_collection_light_elapsed += delta
		var light_progress: float = clampf(_collection_light_elapsed / COLLECTION_LIGHT_DURATION, 0.0, 1.0)
		_gem_light.light_energy = lerpf(COLLECTION_LIGHT_ENERGY, 0.0, light_progress)
		if _collection_light_elapsed >= COLLECTION_LIGHT_DURATION:
			_gem_light.visible = false
	if not visible:
		return
	rotate_y(delta * speed)

func _reset_collection_effect() -> void:
	_sprirt_active = false
	_sprirt_elapsed = SPRIRT_LIFETIME
	_sprirt.restart()
	_sprirt.emitting = false
	_tail.restart()
	_tail.emitting = false
	_aura.restart()
	_aura.emitting = false
	_collection_light_elapsed = COLLECTION_LIGHT_DURATION
	_gem_light.light_energy = 0.0
	_gem_light.visible = false
