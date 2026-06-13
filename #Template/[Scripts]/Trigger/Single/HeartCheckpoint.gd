extends Checkpoint

@export var rotator: Node3D

var _frame: Node3D
var _core: Node3D

func _ready() -> void:
	super._ready()
	# Reconnect to our own override
	if body_entered.is_connected(_on_checkpoint_body_entered):
		body_entered.disconnect(_on_checkpoint_body_entered)
	body_entered.connect(_on_checkpoint_body_entered)
	if not rotator:
		rotator = get_node_or_null("Rotator")
	if rotator:
		_frame = rotator.get_node_or_null("Frame")
		_core = rotator.get_node_or_null("Core")

func _process(delta: float) -> void:
	if _frame:
		_frame.rotate_y(delta * deg_to_rad(-18.0))
	if _core:
		_core.rotate_y(delta * deg_to_rad(60.0))

func _on_checkpoint_body_entered(body: Node3D) -> void:
	if used:
		return
	if rotator:
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(rotator, "scale", Vector3.ONE, 0.5)
	_enter_trigger(body)

func _on_Crown_body_entered(_line) -> void:
	if used:
		return
	#$AnimationPlayer.play("crown")
	await $AnimationPlayer.animation_finished
