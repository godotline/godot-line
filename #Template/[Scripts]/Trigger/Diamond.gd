@tool
extends Area3D

@export var speed := 1.0

var _collected := false

func _on_Diamond_body_entered(_body: Node) -> void:
	if _collected:
		return
	_collected = true
	set_process(false)
	monitoring = false
	LevelManager.diamond += 1
	if Player.instance and Player.instance.has_signal("on_get_gem"):
		Player.instance.on_get_gem.emit()
	$AnimationPlayer.play("diamond")
	$RemainParticle.emitting = true
	# 用 Timer 替代 await，避免阻塞和延迟节点释放
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(queue_free)
	# 粒子结束后也尝试释放（以先到者为准）
	$RemainParticle.finished.connect(queue_free, Object.CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		rotate_y(delta * speed)
