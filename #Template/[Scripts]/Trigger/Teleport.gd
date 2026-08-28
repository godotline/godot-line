extends Node
## Teleport - 传送触发器
## 当玩家进入时传送到目标位置

enum TeleportType {
	Target,   # 目标节点位置
	Position  # 绝对世界坐标
}

@export var type: TeleportType = TeleportType.Target
@export var target: Node3D  # Target 模式
@export var position: Vector3 = Vector3.ZERO  # Position 模式

@export var turn: bool = false
@export var targetDirection: LevelManager.Direction = LevelManager.Direction.First

func trigger(body: Node3D) -> bool:
	if not body is CharacterBody3D:
		return false
	var finalPosition: Vector3
	match type:
		TeleportType.Target:
			if not target:
				return false
			finalPosition = target.global_position
		TeleportType.Position:
			finalPosition = position
	LevelManager.InitPlayerPosition(body, finalPosition, true, turn, targetDirection)
	return true