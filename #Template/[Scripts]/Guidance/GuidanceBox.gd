extends Node3D

var _pending_body: CharacterBody3D = null
var _is_waiting: bool = false

func _ready() -> void:
	$"..".visible = true

func _on_taper_entered(body: Node3D) -> void:
	if body is CharacterBody3D and not _is_waiting:
		_pending_body = body
		_is_waiting = true
		await body.onturn
		if _pending_body == null:
			# body 在等待期间离开了，不执行任何动作
			return
		$"../AnimationPlayer".play("taper")
		await $"../AnimationPlayer".animation_finished
		queue_free()

func _on_taper_exited(body: Node3D) -> void:
	if body is CharacterBody3D and body == _pending_body:
		_pending_body = null
