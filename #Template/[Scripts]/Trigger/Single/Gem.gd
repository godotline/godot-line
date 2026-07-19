@tool
extends Area3D
## Gem - 宝石收集物
## 参考 Unity Gem.cs 实现，支持 fake 属性和复活恢复

const FRAGMENT_SCENE: PackedScene = preload("res://#Template/[Resources]/GemFragment.tscn")
const FRAGMENT_COUNT: int = 8
const FRAGMENT_SPEED_MIN: float = 2.0
const FRAGMENT_SPEED_MAX: float = 4.0
const FRAGMENT_UPWARD_SPEED: float = 3.0
const FRAGMENT_SCALE_MIN: float = 2
const FRAGMENT_SCALE_MAX: float = 2.5
const FRAGMENT_LIFETIME: float = 3.0
const FRAGMENT_SHRINK_DURATION: float = 0.5
const FRAGMENT_TORQUE_SCALE: float = 0.2

@export var speed: float = 1.0
@export var fake: bool = false

var _collected: bool = false
var _checkpoint_index: int = -1

func _on_body_entered(_body: Node) -> void:
	if _collected or fake:
		return
	_collected = true
	_checkpoint_index = LevelManager.checkpoint_count
	set_process(false)
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
	_spawn_fragments()
	# 注册复活回调
	LevelManager.add_revive_listener(_on_revive)
	# 用 Timer 替代 await，避免阻塞和延迟节点释放
	var timer: SceneTreeTimer = get_tree().create_timer(2.0)
	timer.timeout.connect(queue_free)

func _spawn_fragments() -> void:
	var fragment_parent: Node = get_parent()
	for index in FRAGMENT_COUNT:
		var fragment: RigidBody3D = FRAGMENT_SCENE.instantiate() as RigidBody3D
		fragment.name = "GemFragment_%02d" % index
		fragment_parent.add_child(fragment)
		fragment.global_position = global_position
		var scale_factor: float = randf_range(FRAGMENT_SCALE_MIN, FRAGMENT_SCALE_MAX)
		var fragment_mesh: MeshInstance3D = fragment.get_node("MeshInstance3D") as MeshInstance3D
		fragment_mesh.scale *= scale_factor

		# 向上喷出并向四周散射，重力自然形成斜抛轨迹。
		var angle: float = randf_range(0.0, TAU)
		var horizontal: float = randf_range(FRAGMENT_SPEED_MIN, FRAGMENT_SPEED_MAX)
		var launch_velocity: Vector3 = Vector3(cos(angle) * horizontal, FRAGMENT_UPWARD_SPEED, sin(angle) * horizontal)
		fragment.apply_central_impulse(launch_velocity * fragment.mass)
		fragment.apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * FRAGMENT_TORQUE_SCALE)

		var shrink_tween: Tween = fragment.create_tween()
		shrink_tween.tween_interval(FRAGMENT_LIFETIME)
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
		set_deferred("monitoring", true)
		LevelManager.gem -= 1
	LevelManager.remove_revive_listener(_on_revive)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not visible:
		return
	rotate_y(delta * speed)
