@tool
extends TriggerBehavior
class_name FakePlayerTransportBehavior

## FakePlayerTransportBehavior - 假线传送行为组件
## 当父 BaseTrigger 被触发时传送 FakePlayer 到指定位置

enum TransportMode {
	Transform,  ## 传送到目标节点位置
	Vector3     ## 传送到世界坐标
}

@export var fake_player: FakePlayer
## 传送到玩家位置 + 偏移
@export var tp_to_player: bool = false
@export var offset: Vector3 = Vector3.ZERO
@export var transport_mode: TransportMode = TransportMode.Transform
@export var target_node: Node3D
@export var target_position: Vector3 = Vector3.ZERO

func _on_triggered(body: Node3D) -> void:
	if not fake_player or not body is CharacterBody3D:
		return

	if tp_to_player:
		fake_player.global_position = body.global_position + offset
	else:
		match transport_mode:
			TransportMode.Transform:
				if target_node:
					fake_player.global_position = target_node.global_position
			TransportMode.Vector3:
				fake_player.global_position = target_position
