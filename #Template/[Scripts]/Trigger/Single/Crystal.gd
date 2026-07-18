@tool
extends Area3D
## Crystal - 水晶收集物
## 对齐 Unity Crystal：触碰后隐藏，并在复活时按检查点恢复。

const FRAGMENT_SCENE := preload("res://#Template/[Resources]/GemFragment.tscn")
const FRAGMENT_COUNT := 8
const FRAGMENT_SPEED_MIN := 2.0
const FRAGMENT_SPEED_MAX := 4.0
const FRAGMENT_UPWARD_SPEED := 3.0
const FRAGMENT_SCALE_MIN := 2
const FRAGMENT_SCALE_MAX := 2.5
const FRAGMENT_LIFETIME := 3.0
const FRAGMENT_SHRINK_DURATION := 0.5
const FRAGMENT_TORQUE_SCALE := 0.2

@export var speed: float = 40.0
@export var scan_duration: float = 1.25
@export var scan_max_radius: float = 28.0

var _collected := false
var _checkpoint_index := -1
var _scan_elapsed := 0.0
var _scan_material: ShaderMaterial

func _ready() -> void:
	_apply_crystal_material($Hexahedron)
	_scan_material = $ScanQuad.material_override as ShaderMaterial
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
		var progress := clampf(_scan_elapsed / scan_duration, 0.0, 1.0)
		_scan_material.set_shader_parameter("scan_origin", global_position)
		_scan_material.set_shader_parameter("scan_radius", lerpf(0.0, scan_max_radius, progress))
		var fade_progress := inverse_lerp(0.7, 1.0, progress)
		_scan_material.set_shader_parameter("scan_strength", 1.0 - smoothstep(0.0, 1.0, fade_progress))
	else:
		$ScanQuad.visible = false

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
	_spawn_fragments()

func _spawn_fragments() -> void:
	var fragment_parent := get_parent()
	for index in FRAGMENT_COUNT:
		var fragment := FRAGMENT_SCENE.instantiate() as RigidBody3D
		fragment.name = "CrystalFragment_%02d" % index
		fragment_parent.add_child(fragment)
		fragment.global_position = global_position
		var scale_factor := randf_range(FRAGMENT_SCALE_MIN, FRAGMENT_SCALE_MAX)
		var fragment_mesh := fragment.get_node("MeshInstance3D") as MeshInstance3D
		fragment_mesh.scale *= scale_factor

		# 向上喷出并向四周散射，重力自然形成斜抛轨迹。
		var angle := randf_range(0.0, TAU)
		var horizontal := randf_range(FRAGMENT_SPEED_MIN, FRAGMENT_SPEED_MAX)
		var launch_velocity := Vector3(cos(angle) * horizontal, FRAGMENT_UPWARD_SPEED, sin(angle) * horizontal)
		fragment.apply_central_impulse(launch_velocity * fragment.mass)
		fragment.apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * FRAGMENT_TORQUE_SCALE)

		var shrink_tween := fragment.create_tween()
		shrink_tween.tween_interval(FRAGMENT_LIFETIME)
		shrink_tween.tween_property(fragment_mesh, "scale", Vector3.ZERO, FRAGMENT_SHRINK_DURATION)
		shrink_tween.finished.connect(fragment.queue_free)

func _start_scan() -> void:
	_scan_elapsed = 0.0
	_scan_material.set_shader_parameter("scan_origin", global_position)
	_scan_material.set_shader_parameter("scan_radius", 0.0)
	_scan_material.set_shader_parameter("scan_strength", 1.0)
	$ScanQuad.visible = true

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

func _set_crystal_mesh_visible(value: bool) -> void:
	$Hexahedron.visible = value

func _apply_crystal_material(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = preload("res://#Template/[Materials]/CrystalGradientMaterial.tres")
	for child in node.get_children():
		_apply_crystal_material(child)
