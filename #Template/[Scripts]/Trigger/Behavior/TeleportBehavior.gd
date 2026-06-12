@tool
extends TriggerBehavior
class_name TeleportBehavior

## TeleportBehavior - 传送行为组件
## 当父 BaseTrigger 被触发时传送玩家到指定位置

enum TeleportMode {
	Offset,    ## 相对于当前位置的偏移
	Position,  ## 绝对世界坐标
	Target     ## 目标节点的位置
}

@export_group("传送模式")
@export var teleport_mode: TeleportMode = TeleportMode.Offset

@export_group("Offset 模式参数")
@export var tp_x := 0.0
@export var tp_y := 0.0
@export var tp_z := 0.0

@export_group("Position 模式参数")
@export var teleport_position := Vector3.ZERO

@export_group("Target 模式参数")
@export var target: NodePath
@onready var target_node: Node3D = get_node(target) if target else null

@export_group("摄像机设置")
@export var force_camera_follow: bool = false

@export_group("转向设置")
@export var turn: bool = false
@export var target_direction: LevelManager.Direction = LevelManager.Direction.First

func _on_triggered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var final_position: Vector3

		match teleport_mode:
			TeleportMode.Target:
				if not target_node:
					return
				final_position = target_node.global_position
			TeleportMode.Position:
				final_position = teleport_position
			TeleportMode.Offset:
				final_position = body.global_position + Vector3(tp_x, tp_y, tp_z)

		LevelManager.init_player_position(body, final_position, force_camera_follow, turn, target_direction)
