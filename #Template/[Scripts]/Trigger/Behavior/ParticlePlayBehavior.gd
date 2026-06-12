@tool
extends TriggerBehavior
class_name ParticlePlayBehavior

## ParticlePlayBehavior - 粒子播放行为组件
## 当父 BaseTrigger 被触发时播放指定粒子系统

@export_group("粒子设置")
## 目标粒子节点路径
@export var particle_path: NodePath
## 是否使用 one_shot 模式（播放一次）
@export var one_shot: bool = true

func _on_triggered(_body: Node3D) -> void:
	if not particle_path:
		return

	var particle := get_node_or_null(particle_path)
	if not is_instance_valid(particle):
		return

	if particle is GPUParticles3D:
		var gp := particle as GPUParticles3D
		gp.restart()
		gp.emitting = true
	elif particle is CPUParticles3D:
		var cp := particle as CPUParticles3D
		cp.restart()
		cp.emitting = true
