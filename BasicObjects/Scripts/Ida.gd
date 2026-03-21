extends Node3D

@export var speed := 10.0
@export var rot := 90
@export var rotation_duration := 0.3  # 旋转持续时间（秒）
@export var source_character: NodePath

var active = false
var v := Vector3.ZERO
var is_turn := false
var is_start := false
var is_rotating := false  # 旋转状态标记
var tween: Tween

func _ready() -> void:
	if bool(State.get("is_restoring_checkpoint")):
		return
	if not Engine.is_editor_hint():
		if source_character and has_node(source_character):
			var source_node = get_node(source_character)
			if source_node.has_signal("onturn"):
				source_node.connect("onturn", _on_newline)

func _process(delta: float) -> void:
	if active and not Engine.is_editor_hint():
		position += v * delta

func turn():
	# 防止旋转中重复触发
	if is_rotating:
		return
	
	if is_start:
		is_rotating = true
		
		# 计算目标旋转角度
		var target_rotation = rotation_degrees
		if is_turn:
			target_rotation += Vector3(0, rot, 0)
		else:
			target_rotation += Vector3(0, -rot, 0)
		
		is_turn = not is_turn
		
		# 创建 Tween 动画
		if tween:
			tween.kill()  # 停止之前的 Tween
		
		tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)  # 平滑曲线
		tween.set_ease(Tween.EASE_IN_OUT)   # 缓入缓出
		
		# 旋转动画
		tween.tween_property(
			self, 
			"rotation_degrees", 
			target_rotation, 
			rotation_duration
		)
		
		# 动画结束回调
		tween.finished.connect(_on_rotation_finished)
		
		# 立即更新移动方向（基于目标旋转）
		var future_basis = Basis()
		future_basis = future_basis.rotated(Vector3.UP, deg_to_rad(target_rotation.y))
		v = future_basis.z * -speed
	else:
		is_start = true
		v = transform.basis.z * -speed

func _on_rotation_finished():
	is_rotating = false

func _on_newline():
	turn()

func _on_active():
	active = not active

func stop_movement():
	v = Vector3.ZERO
	if tween:
		tween.kill()
	is_rotating = false
