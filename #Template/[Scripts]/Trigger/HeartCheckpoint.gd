extends Checkpoint

@export var rotator: Node3D

var frame: Node3D
var core: Node3D

func _ready() -> void:
	super._ready()
	if not rotator:
		rotator = checkpointContainer.get_node_or_null("Rotator") as Node3D
	if rotator:
		frame = rotator.get_node_or_null("Frame") as Node3D
		core = rotator.get_node_or_null("Core") as Node3D

func _process(delta: float) -> void:
	if not checkpointContainer or not checkpointContainer.visible:
		return
	if frame:
		frame.rotate_y(delta * deg_to_rad(-18.0))
	if core:
		core.rotate_y(delta * deg_to_rad(60.0))

func _on_checkpoint_body_entered(body: Node3D) -> bool:
	if used or not body is Player:
		return false
	if rotator:
		var tw: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(rotator, "scale", Vector3.ONE, 0.5)
	_enter_trigger(body)
	return true

func _on_Crown_body_entered(line: Node3D) -> void:
	if used:
		return
	#$AnimationPlayer.play("crown")
	var animPlayer: AnimationPlayer = checkpointContainer.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animPlayer:
		await animPlayer.animation_finished
	else:
		push_error("HeartCheckpoint.gd: AnimationPlayer 子节点未找到")