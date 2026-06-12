@tool
extends TriggerBehavior
class_name PyramidBehavior

## PyramidBehavior - 金字塔触发行为组件
## 当父 BaseTrigger 被触发时调用父 Pyramid 节点的 trigger 方法

enum TriggerType {
	Open,     ## 开门
	Final,    ## 关卡结束
	Waiting,  ## 等待
	Stop      ## 停止
}

@export var type: TriggerType = TriggerType.Open

@export_group("Final 设置")
@export var change_direction: bool = false
@export var final_direction: Vector3 = Vector3.ZERO

func _on_triggered(_body: Node3D) -> void:
	var pyramid := get_parent()
	# Pyramid 是 Node3D，通过 has_method 动态检查
	if is_instance_valid(pyramid) and pyramid.has_method("trigger"):
		pyramid.trigger(type)

	if type == TriggerType.Final and change_direction:
		var player := Player.instance
		if player:
			player.firstDirection = final_direction
			player.secondDirection = final_direction
			player.turn()
