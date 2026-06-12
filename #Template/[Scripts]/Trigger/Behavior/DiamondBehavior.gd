@tool
extends TriggerBehavior
class_name DiamondBehavior

## DiamondBehavior - 钻石收集行为组件
## 当父 BaseTrigger 被触发时收集钻石

@export var speed := 1.0

var _collected := false

func _ready() -> void:
	super._ready()
	# 如果父节点是 BaseTrigger，需要让父节点也连接 body_entered 来处理收集
	var parent = get_parent()
	if parent is BaseTrigger:
		parent.triggered.connect(_on_triggered_wrapper)

func _on_triggered_wrapper(body: Node3D) -> void:
	_on_triggered(body)

func _on_triggered(_body: Node3D) -> void:
	if _collected:
		return
	_collected = true
	set_process(false)
	LevelManager.diamond += 1
	if Player.instance and Player.instance.has_signal("on_get_gem"):
		Player.instance.on_get_gem.emit()
	
	# 尝试播放动画和粒子
	var parent = get_parent()
	if parent:
		var anim_player = parent.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim_player:
			anim_player.play("diamond")
		var particle = parent.get_node_or_null("RemainParticle") as GPUParticles3D
		if particle:
			particle.emitting = true
			particle.finished.connect(parent.queue_free, Object.CONNECT_ONE_SHOT)
			var timer := get_tree().create_timer(2.0)
			timer.timeout.connect(parent.queue_free)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		get_parent().rotate_y(delta * speed)

func _on_revive() -> void:
	_collected = false
	set_process(true)
