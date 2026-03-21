@tool extends Area3D

@export var animated_object: Node3D
@export var position_offsets: Array[Vector3] = []  # 相对偏移数组，如 [Vector3(5,0,0), Vector3(0,5,0)]
@export var move_durations: Array[float] = []
@export var wait_times: Array[float] = []
@export var duration: float = 1.0
@export var transition_type: Tween.TransitionType = Tween.TransitionType.TRANS_LINEAR
@export var one_shot: bool = false

var triggered: bool = false
var _editor_original_pos: Vector3  # 编辑器预览用，保存原始位置

signal on_animation_start
signal on_animation_end
signal hit_the_line

# ---------- 工具按钮 ----------
@export_tool_button("添加偏移 (5,0,0)") var add_offset_action = func():
	position_offsets.append(Vector3(5, 0, 0))
	move_durations.append(duration)
	wait_times.append(0.0)
	print("添加偏移点，序号: ", position_offsets.size() - 1, "，偏移量: ", position_offsets[-1])

@export_tool_button("预览播放") var preview_play_action = func():
	if Engine.is_editor_hint():
		_preview_sequence()

# ---------- 核心逻辑 ----------
func _ready() -> void:
	if not Engine.is_editor_hint():
		if has_node("MeshInstance3D"):
			$MeshInstance3D.visible = false
		triggered = false
	
	# 连接信号
	hit_the_line.connect(play_sequence)

func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if body is CharacterBody3D:
		hit_the_line.emit()
		
		if one_shot and triggered:
			return
		triggered = true

func play_sequence() -> void:
	if position_offsets.is_empty():
		push_warning("没有设置偏移量！")
		return
		
	on_animation_start.emit()
	
	var target = animated_object if animated_object else self
	var current_pos = target.position
	
	var tween = create_tween()
	
	for i in range(position_offsets.size()):
		var offset = position_offsets[i]
		var move_time = duration if i >= move_durations.size() else move_durations[i]
		var wait_time = 0.0 if i >= wait_times.size() else wait_times[i]
		var next_pos = current_pos + offset
		tween.tween_property(target, "position", next_pos, move_time).set_trans(transition_type)
		
		if wait_time > 0.0:
			tween.tween_interval(wait_time)
		current_pos = next_pos
	
	tween.tween_callback(func(): on_animation_end.emit())

# 编辑器预览：播放完毕后自动重置到原始位置
func _preview_sequence() -> void:
	var target = animated_object if animated_object else self
	if not is_instance_valid(target):
		push_warning("未设置动画对象！")
		return
		
	# 保存编辑器中的原始位置
	_editor_original_pos = target.position
	
	var tween = create_tween()
	var current_pos = target.position
	
	for i in range(position_offsets.size()):
		var offset = position_offsets[i]
		var move_time = duration if i >= move_durations.size() else move_durations[i]
		var wait_time = 0.0 if i >= wait_times.size() else wait_times[i]
		
		var next_pos = current_pos + offset
		tween.tween_property(target, "position", next_pos, move_time).set_trans(transition_type)
		
		if wait_time > 0.0:
			tween.tween_interval(wait_time)
			
		current_pos = next_pos
	tween.tween_callback(func():
		if is_instance_valid(target):
			await get_tree().create_timer(1.0).timeout
			target.position = _editor_original_pos
			print("预览完成，位置已重置")
	)

func play_():
	play_sequence()
