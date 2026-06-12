@tool
extends TriggerBehavior
class_name GravityChangeBehavior

## GravityChangeBehavior - 重力变化行为组件
## 当父 BaseTrigger 被触发时改变场景重力

@export var gravity_vector: Vector3 = Vector3(0, -9.8, 0)

var _original_gravity: Vector3

func _on_triggered(_body: Node3D) -> void:
	_original_gravity = ProjectSettings.get_setting("physics/3d/default_gravity_vector") * ProjectSettings.get_setting("physics/3d/default_gravity")
	
	var space := get_world_3d().space
	if space:
		PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, gravity_vector.length())
		PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, gravity_vector.normalized() if gravity_vector.length() > 0 else Vector3.DOWN)
	
	_register_revive()

func _on_revive() -> void:
	var space := get_world_3d().space
	if space:
		PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, _original_gravity.length())
		PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, _original_gravity.normalized() if _original_gravity.length() > 0 else Vector3.DOWN)
