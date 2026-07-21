extends Node
## Teleport - 传送触发器
## 当玩家进入时传送到目标位置

enum TeleportType {
	Target,   # 目标节点位置
	Position  # 绝对世界坐标
}

@export_group("传送设置")
@export var type: TeleportType = TeleportType.Target
@export var target: Node3D  # Target 模式
@export var teleport_position: Vector3 = Vector3.ZERO  # Position 模式

@export_group("转向设置")
@export var turn: bool = false
@export var target_direction: LevelManager.Direction = LevelManager.Direction.First

func trigger(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	
	var final_position: Vector3
	match type:
		TeleportType.Target:
			if not target:
				return
			final_position = target.global_position
		TeleportType.Position:
			final_position = teleport_position
	
	LevelManager.init_player_position(body, final_position, turn, target_direction)
