extends Node3D
class_name TTFCheckPointTrigger

## Pure trigger component. Place below a BaseTrigger and either assign the
## checkpoint or nest that BaseTrigger below a TTFCheckPoint.

@export var checkpoint: Checkpoint

func trigger(body: Node3D) -> bool:
	if not body is Player:
		return false
	var target: Checkpoint = checkpoint
	if not target:
		target = _find_checkpoint_parent()
	if not target:
		push_error("TTFCheckPointTrigger.gd: TTFCheckPoint target not found")
		return false
	if not target.has_method("EnterTrigger"):
		push_error("TTFCheckPointTrigger.gd: target does not implement EnterTrigger")
		return false
	target.call("EnterTrigger", body)
	return true

func _find_checkpoint_parent() -> Checkpoint:
	var current: Node = get_parent()
	while current:
		if current is Checkpoint and current.has_method("EnterTrigger"):
			return current as Checkpoint
		current = current.get_parent()
	return null