class_name ObjectPool
extends RefCounted

## 通用对象池（与 Unity ObjectPool<T> 一致）
## 用 queue（先进先出）管理对象，满额时循环复用最旧的对象

var pool: Array[Node] = []
var size: int = 100:
	set(value):
		size = value
	get:
		return size

var full: bool:
	get:
		return pool.size() >= size

func _init(initialSize: int = 100) -> void:
	size = initialSize

func is_full() -> bool:
	return pool.size() >= size

func Add(obj: Node) -> void:
	pool.append(obj)

func First() -> Node:
	if pool.is_empty():
		return null
	return pool.pop_front()

## 出栈（兼容原有调用）
func pop() -> Node:
	if pool.is_empty():
		return null
	return pool.pop_back()

## 清空并销毁所有对象（对齐 Unity DestoryAll）
func DestoryAll() -> void:
	for obj in pool:
		if is_instance_valid(obj):
			obj.queue_free()
	pool.clear()

## 兼容原有 destroy_all 命名
func destroy_all() -> void:
	DestoryAll()

func get_size() -> int:
	return size

func get_count() -> int:
	return pool.size()

