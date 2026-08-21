class_name CameraShakeTrigger
extends Node

## CameraShakeTrigger - 相机震动触发器（模式 1 纯组件）
## 作为 BaseTrigger 的子节点使用，由父节点负责碰撞检测。
## 与 Unity CameraShakeTrigger.cs 一致。

@export var power: float = 1.0
@export var duration: float = 2.0


func trigger(body: Node3D) -> void:
	if body is CharacterBody3D:
		var follower: CameraFollower = CameraFollower.instance
		if follower:
			follower.DoShake(power, duration)
		else:
			var oldFollower: OldCameraFollower = OldCameraFollower.instance
			if oldFollower:
				oldFollower.DoShake(power, duration)

