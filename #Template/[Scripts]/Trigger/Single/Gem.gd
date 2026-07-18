@tool
extends Area3D
## Gem - 宝石收集物
## 参考 Unity Gem.cs 实现，支持 fake 属性和复活恢复

@export var speed := 1.0
@export var fake := false

var _collected := false
var _checkpoint_index := -1

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
	var mesh := get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = false
	else:
		push_error("Gem.gd: MeshInstance3D 子节点未找到")
	var anim_player := get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("diamond")
	else:
		push_error("Gem.gd: AnimationPlayer 子节点未找到")
	var particles := get_node_or_null("RemainParticle")
	if particles:
		particles.emitting = true
	else:
		push_error("Gem.gd: RemainParticle 子节点未找到")
	# 注册复活回调
	LevelManager.add_revive_listener(_on_revive)
	# 用 Timer 替代 await，避免阻塞和延迟节点释放
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(queue_free)
	# 粒子结束后也尝试释放（以先到者为准）
	particles = get_node_or_null("RemainParticle")
	if particles:
		particles.finished.connect(queue_free, Object.CONNECT_ONE_SHOT)
	else:
		push_error("Gem.gd: RemainParticle 子节点未找到，无法连接 finished 信号")

func _on_revive() -> void:
	# 只有在宝石之后存档才恢复（存档点索引 >= 宝石索引）
	if _checkpoint_index >= LevelManager.checkpoint_count:
		# 宝石在存档点之前，需要恢复
		_collected = false
		var mesh := get_node_or_null("MeshInstance3D")
		if mesh:
			mesh.visible = true
		else:
			push_error("Gem.gd: MeshInstance3D 子节点未找到，复活时无法恢复显示")
		set_deferred("monitoring", true)
		LevelManager.gem -= 1
	LevelManager.remove_revive_listener(_on_revive)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not visible:
		return
	rotate_y(delta * speed)
