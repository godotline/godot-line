@tool
extends Area3D
## BaseTrigger - 基础触发器组件
## 为所有触发器提供统一的触发逻辑、过滤器和一次性触发支持
## 子类只需重写 _on_triggered() 方法即可实现自定义触发效果
class_name BaseTrigger

## 当触发器被激活时发出，传递触发它的身体节点
signal triggered(body: Node3D)

@export_group("触发器设置")
## 是否只触发一次
@export var one_shot: bool = false
## 触发过滤器：指定什么类型的节点可以触发
## 可选值："CharacterBody3D", "PhysicsBody3D", "Any"
@export var trigger_filter: String = "CharacterBody3D"
## 是否在游戏运行时隐藏 MeshInstance3D（编辑器中可见）
@export var hide_mesh_in_game: bool = true

@export_group("调试设置")
## 是否在控制台打印触发信息
@export var debug_mode: bool = false

## 内部标记：是否已触发（用于 one_shot）
var _used: bool = false
## 内部标记：是否已初始化信号连接
var _signal_connected: bool = false

func _ready() -> void:
	# 编辑器模式下跳过游戏逻辑
	if Engine.is_editor_hint():
		return
	
	# 隐藏可视化网格
	if hide_mesh_in_game:
		_hide_mesh()
	
	# 设置触发信号连接
	_setup_trigger()

## 隐藏 MeshInstance3D 子节点
func _hide_mesh() -> void:
	if has_node("MeshInstance3D"):
		$MeshInstance3D.visible = false

## 设置触发信号连接
func _setup_trigger() -> void:
	if not _signal_connected:
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		_signal_connected = true

## 当有物体进入触发区域时的处理
func _on_body_entered(body: Node3D) -> void:
	if _should_trigger(body):
		# 检查一次性触发
		if one_shot and _used:
			if debug_mode:
				print("[BaseTrigger] ", name, " 已触发过，忽略 (one_shot)")
			return
		
		# 标记已使用
		_used = true
		
		if debug_mode:
			print("[BaseTrigger] ", name, " 被 ", body.name, " 触发")
		
		# 发出信号
		triggered.emit(body)
		
		# 调用子类的触发处理
		_on_triggered(body)

## 判断是否应该触发
## 子类可以重写此方法以实现更复杂的触发条件
func _should_trigger(body: Node3D) -> bool:
	match trigger_filter:
		"CharacterBody3D":
			return body is CharacterBody3D
		"PhysicsBody3D":
			return body is PhysicsBody3D
		"Any":
			return true
		_:
			# 默认检查是否是 CharacterBody3D
			return body is CharacterBody3D

## 触发后的处理逻辑（子类必须重写此方法）
## @param body: 触发此触发器的节点
func _on_triggered(_body: Node3D) -> void:
	pass

## 重置触发器状态（可用于重新激活 one_shot 触发器）
func reset() -> void:
	_used = false
	if debug_mode:
		print("[BaseTrigger] ", name, " 已重置")

## 获取触发器是否已使用
func is_used() -> bool:
	return _used
