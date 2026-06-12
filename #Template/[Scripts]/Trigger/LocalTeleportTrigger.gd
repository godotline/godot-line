extends BaseTrigger
## @deprecated: 推荐使用 TeleportBehavior 作为 BaseTrigger 的子节点
## LocalTeleportTrigger - 传送触发器（向后兼容包装）
class_name LocalTeleportTrigger

enum TeleportMode {
	Offset,    # Relative offset from current position (backward compatible)
	Position,  # Absolute world position
	Target     # Target node's position
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

func _ready():
	super._ready()

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
