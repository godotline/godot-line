@tool
class_name GuidanceBoxSorter
extends RefCounted

## GuidanceBox 路径排序：把 holder 下的 Box 排成连续路径。
## 以 OriginalGuidanceBox（或首个 Box）为起点做最近邻贪心：正前方优先、
## 欧氏距离最近（距离相同取方向更正者），逐块链接直到排完。


static func sortCurrentScene() -> void:
	var sceneRoot: Node = EditorInterface.get_edited_scene_root()
	if not sceneRoot:
		_pushError("当前没有打开的场景")
		return

	var holders: Array[Node] = []
	_collectGuidanceHolders(sceneRoot, holders)
	if holders.is_empty():
		_pushError("当前场景没有找到 GuidanceBoxHolder")
		return
	var changedCount: int = 0
	var boxCount: int = 0
	var undoRedo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undoRedo.create_action("排序 GuidanceBox")
	for holder: Node in holders:
		var ordered: Array[Node] = _sortHolderBoxes(holder)
		if ordered.is_empty():
			continue
		var original: Array[Node] = []
		for child: Node in holder.get_children():
			if _isGuidanceBoxRoot(child):
				original.append(child)
		if _sameNodeOrder(original, ordered):
			continue
		undoRedo.add_do_method(GuidanceBoxSorter, "_applyGuidanceBoxOrder", holder, ordered)
		undoRedo.add_undo_method(GuidanceBoxSorter, "_applyGuidanceBoxOrder", holder, original)
		changedCount += 1
		boxCount += ordered.size()
	if changedCount == 0:
		undoRedo.commit_action(false)
		print("[GuidanceSort] 当前 GuidanceBox 已经是路径顺序")
		return
	undoRedo.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	print("[GuidanceSort] 已排序 %d 个 GuidanceBoxHolder 共 %d 个 Box" % [changedCount, boxCount])


static func _collectGuidanceHolders(node: Node, holders: Array[Node]) -> void:
	if node.name == "GuidanceBoxHolder":
		holders.append(node)
	for child: Node in node.get_children():
		_collectGuidanceHolders(child, holders)


static func _sortHolderBoxes(holder: Node) -> Array[Node]:
	var remaining: Array[Node] = []
	for child: Node in holder.get_children():
		if _isGuidanceBoxRoot(child):
			remaining.append(child)
	if remaining.size() < 2:
		return remaining

	var ordered: Array[Node] = []
	var current: Node = null
	for candidate: Node in remaining:
		if candidate.name == "OriginalGuidanceBox":
			current = candidate
			break
	if current == null:
		current = remaining[0]
	ordered.append(current)
	remaining.erase(current)

	while not remaining.is_empty():
		var next: Node = _findNextGuidanceBox(current, remaining, _boxForward(current))
		ordered.append(next)
		remaining.erase(next)
		current = next
	return ordered


static func _boxForward(box: Node) -> Vector3:
	var box3d: Node3D = box as Node3D
	if not box3d:
		return Vector3(0, 0, 1)
	var direction: Vector3 = box3d.global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		return direction.normalized()
	return Vector3(0, 0, 1)


static func _findNextGuidanceBox(current: Node, candidates: Array[Node], playerDirection: Vector3) -> Node:
	var current3d: Node3D = current as Node3D
	var direction: Vector3 = playerDirection

	var best: Node = candidates[0]
	var bestDistance: float = INF
	var bestProjection: float = INF
	var bestIsAhead: bool = false
	for candidate: Node in candidates:
		var candidate3d: Node3D = candidate as Node3D
		if not candidate3d or not current3d:
			continue
		var offset: Vector3 = candidate3d.global_position - current3d.global_position
		var projection: float = offset.dot(direction)
		var distance: float = offset.length_squared()
		var isAhead: bool = projection > 0.001
		var shouldReplace: bool = false
		# 最近邻贪心：主标准取欧氏距离最近；正前方优先防止在已走过的
		# 点附近回环倒走；距离完全相同（is_equal_approx）时取方向更正者。
		if isAhead and not bestIsAhead:
			shouldReplace = true
		elif isAhead == bestIsAhead:
			if is_equal_approx(distance, bestDistance):
				shouldReplace = projection > bestProjection
			else:
				shouldReplace = distance < bestDistance
		if shouldReplace:
			best = candidate
			bestDistance = distance
			bestProjection = projection
			bestIsAhead = isAhead
	return best


static func _isGuidanceBoxRoot(node: Node) -> bool:
	if node is GuidanceBox:
		return true
	for child: Node in node.get_children():
		if _isGuidanceBoxRoot(child):
			return true
	return false


static func _sameNodeOrder(first: Array[Node], second: Array[Node]) -> bool:
	if first.size() != second.size():
		return false
	for i: int in range(first.size()):
		if first[i] != second[i]:
			return false
	return true


static func _applyGuidanceBoxOrder(holder: Node, ordered: Array[Node]) -> void:
	for i: int in range(ordered.size()):
		holder.move_child(ordered[i], i)


static func _pushError(msg: String) -> void:
	push_error("[Template 插件] " + msg)
	printerr("[Template 插件] " + msg)