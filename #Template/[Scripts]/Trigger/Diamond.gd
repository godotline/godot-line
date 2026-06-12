@tool
extends BaseTrigger
## @deprecated: 推荐使用 DiamondBehavior 作为 BaseTrigger 的子节点
## Diamond - 钻石收集物（向后兼容包装）

@export var speed := 1.0

var _collected := false

func _ready() -> void:
	super._ready()
	# 断开场景中的旧连接，使用 BaseTrigger 的信号链
	for conn in body_entered.get_connections():
		if conn["callable"].get_method() == "_on_Diamond_body_entered":
			body_entered.disconnect(conn["callable"])

func _on_triggered(_body: Node3D) -> void:
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
