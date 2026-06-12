extends BaseTrigger
## @deprecated: 此脚本保持向后兼容，推荐使用 Behavior 组合模式
## PyramidTrigger - 金字塔子触发器（向后兼容包装）

@export var type: Pyramid.TriggerType = Pyramid.TriggerType.Open

@export_group("Final设置")
@export var change_direction := false
@export var final_direction := Vector3.ZERO

func _on_triggered(_body: Node3D) -> void:
	var pyramid := get_parent() as Pyramid
	if pyramid:
		pyramid.trigger(type)
	if type == Pyramid.TriggerType.Final and change_direction:
		var player := Player.instance
		if player:
			player.firstDirection = final_direction
			player.secondDirection = final_direction
			player.turn()
