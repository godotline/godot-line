class_name TrackSwitchTrigger
extends Node

## 对应 Unity TrackSwitchTrigger：玩家进入触发区时切换到 Target 轨道。
## 模式 1 纯组件：作为 BaseTrigger / Trigger.tscn 的子节点放置，
## 碰撞检测由父级 BaseTrigger 负责，本组件只实现 trigger(body)。

@export_group("Timeline Track Switch Control")
## 指向挂有 TrackSwitcher 组件的节点；留空则自动使用场景中第一个切换器
@export var trackSwitcherPath: NodePath

func trigger(body: Node3D) -> void:
	if not body is Player:
		return
	var switcher: TrackSwitcher = _resolveSwitcher()
	if switcher:
		switcher.SwitchToTargetTrack()

func _resolveSwitcher() -> TrackSwitcher:
	if not trackSwitcherPath.is_empty():
		return get_node_or_null(trackSwitcherPath) as TrackSwitcher
	var nodes: Array[Node] = get_tree().get_nodes_in_group("timeline_track_switchers")
	return nodes[0] as TrackSwitcher if not nodes.is_empty() else null
