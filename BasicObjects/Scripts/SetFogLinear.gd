@tool
extends Area3D

# ========== 核心导出变量 ==========
@export var camera: Camera3D  # 指定相机（从中获取 Environment）
@export var use_fog: bool = true
@export var fog_color: Color = Color(0, 0, 0)
@export var fog_start: float = 10.0  # 对应 fog_depth_begin
@export var fog_end: float = 100.0   # 对应 fog_depth_end
@export var need_time: float = 1.0
@export var one_shot: bool = false

var used: bool = false
var _is_previewing: bool = false
var _backup_env: Dictionary  # 编辑器预览用备份

signal hit_the_line
signal on_fog_transition_complete

# ========== 编辑器按钮 ==========
@export var 预览雾效: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_preview_fog()
		预览雾效 = false

@export var 停止预览: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_reset_fog_immediately()
		停止预览 = false

# ========== 生命周期 ==========
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	used = false
	if has_node("MeshInstance3D"):
		$MeshInstance3D.visible = false

func _on_body_entered(body: Node3D) -> void:
	if Engine.is_editor_hint():
		return
	if not (body is CharacterBody3D):
		return
	if one_shot and used:
		return
	
	hit_the_line.emit()
	_transition_fog()
	if one_shot:
		used = true

# ========== 核心雾效逻辑 ==========
func _get_environment() -> Environment:
	if camera and camera.environment:
		return camera.environment

	var world_env = get_tree().current_scene.find_child("WorldEnvironment", true, false)
	if world_env is WorldEnvironment and world_env.environment:
		return world_env.environment
	
	push_warning("未找到有效的 Environment。请确保 Camera3D 有 Environment 属性，或场景中存在 WorldEnvironment 节点。")
	return null

func _transition_fog() -> void:
	var env = _get_environment()
	if not env:
		return
	
	# 启用雾效并设置为线性/深度模式
	if use_fog:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH  # 关键：设置为线性雾模式
	
	# 创建并行 Tween 同时过渡三个参数
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Godot 4 线性雾参数名：fog_depth_begin, fog_depth_end
	tween.tween_property(env, "fog_depth_begin", fog_start, need_time)
	tween.tween_property(env, "fog_depth_end", fog_end, need_time)
	tween.tween_property(env, "fog_light_color", fog_color, need_time)
	
	# 如果 use_fog 为 false，动画结束后禁用雾
	if not use_fog:
		tween.chain().tween_callback(func():
			env.fog_enabled = false
		)
	
	tween.finished.connect(func():
		on_fog_transition_complete.emit()
	, CONNECT_ONE_SHOT)

# ========== 编辑器预览功能 ==========
func _preview_fog() -> void:
	if _is_previewing:
		return
	
	var env = _get_environment()
	if not env:
		push_warning("预览失败：无法获取 Environment")
		return
	
	_is_previewing = true
	
	# 备份当前雾效状态（使用正确的属性名）
	_backup_env = {
		"enabled": env.fog_enabled,
		"mode": env.fog_mode,
		"begin": env.fog_depth_begin,
		"end": env.fog_depth_end,
		"color": env.fog_light_color
	}
	
	print("开始预览雾效，原始状态已备份")
	_transition_fog()
	
	# 等待动画结束后自动重置（给 0.5 秒缓冲观察）
	await get_tree().create_timer(need_time + 0.5).timeout
	_reset_fog_immediately()

func _reset_fog_immediately() -> void:
	if not _is_previewing or _backup_env.is_empty():
		_is_previewing = false
		return
	
	var env = _get_environment()
	if env:
		env.fog_enabled = _backup_env.enabled
		env.fog_mode = _backup_env.mode
		env.fog_depth_begin = _backup_env.begin
		env.fog_depth_end = _backup_env.end
		env.fog_light_color = _backup_env.color
		print("雾效已重置为预览前状态")
	
	_is_previewing = false
	_backup_env.clear()
