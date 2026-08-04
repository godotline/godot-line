extends Checkpoint

@export var rotator: Node3D

var _frame: Node3D
var _core: Node3D

func _ready() -> void:
	super._ready()
	if not rotator:
		rotator = _checkpoint_container.get_node_or_null("Rotator") as Node3D
	if rotator:
		_frame = rotator.get_node_or_null("Frame") as Node3D
		_core = rotator.get_node_or_null("Core") as Node3D

func _process(delta: float) -> void:
	if not _checkpoint_container or not _checkpoint_container.visible:
		return
	if _frame:
		_frame.rotate_y(delta * deg_to_rad(-18.0))
	if _core:
		_core.rotate_y(delta * deg_to_rad(60.0))

func _on_checkpoint_body_entered(body: Node3D) -> void:
	if used or not body is Player:
		return
	if rotator:
		var tw: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(rotator, "scale", Vector3.ONE, 0.5)
	_enter_trigger(body)

func _on_Crown_body_entered(_line: Node3D) -> void:
	if used:
		return
	#$AnimationPlayer.play("crown")
	var anim_player: AnimationPlayer = _checkpoint_container.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player:
		await anim_player.animation_finished
	else:
		push_error("HeartCheckpoint.gd: AnimationPlayer 子节点未找到")
