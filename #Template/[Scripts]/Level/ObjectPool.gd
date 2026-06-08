class_name ObjectPool
extends RefCounted

## 通用对象池（与 Unity ObjectPool<T> 一致）
## 用 queue（先进先出）管理对象，满额时循环复用最旧的对象

var _pool: Array[Node] = []
var _size: int = 256

func _init(size: int = 256):
	_size = size

func is_full() -> bool:
	return _pool.size() >= _size

func add(obj: Node) -> void:
	_pool.append(obj)

## 取出最近放入的对象（栈顶）—— O(1) 避免 pop_front 的 O(n) 移动
func pop() -> Node:
	if _pool.is_empty():
		return null
	return _pool.pop_back()

## 清空并销毁所有对象
func destroy_all() -> void:
	for obj in _pool:
		if is_instance_valid(obj):
			obj.queue_free()
	_pool.clear()

func get_size() -> int:
	return _size

func get_count() -> int:
	return _pool.size()
