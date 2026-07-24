extends Checkpoint
class_name TTFCheckPoint

## TTF checkpoint variant. The inherited Checkpoint owns all gameplay snapshots
## and revival behavior; this script adds the TTF presentation and gem pickup.

@export_group("TTF Visuals")
@export var rotator: Node3D
@export var checkpoint_gem: Node3D
@export var checkpoint_text: Node3D
@export var rotation_speed: float = 90.0
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.005
@export var text_target_z: float = 100.0
@export var text_move_duration: float = 1.5

var _rotator_start_position: Vector3 = Vector3.ZERO
var _visual_time: float = 0.0

func _ready() -> void:
	super._ready()
	if not rotator:
		rotator = get_node_or_null("Rotator") as Node3D
	if not checkpoint_gem and rotator:
		checkpoint_gem = rotator.get_node_or_null("CheckPoint_Gem") as Node3D
	if not checkpoint_text:
		checkpoint_text = get_node_or_null("CheckPointText") as Node3D
	if rotator:
		_rotator_start_position = rotator.position

	# Make the inherited Area3D callback resolve to this variant explicitly.
	if body_entered.is_connected(_on_checkpoint_body_entered):
		body_entered.disconnect(_on_checkpoint_body_entered)
	body_entered.connect(_on_checkpoint_body_entered)

func _process(delta: float) -> void:
	if not rotator or not visible:
		return
	_visual_time += delta
	rotator.rotate_y(deg_to_rad(rotation_speed) * delta)
	var offset_y: float = sin(_visual_time * bob_frequency) * bob_amplitude
	rotator.position = _rotator_start_position + Vector3.UP * offset_y

func _on_checkpoint_body_entered(body: Node3D) -> void:
	enter_trigger(body)

func enter_trigger(body: Node3D) -> void:
	if used or not body is Player:
		return

	_enter_trigger(body)
	if checkpoint_gem and checkpoint_gem.has_method("pick_up"):
		checkpoint_gem.call("pick_up", false)
	_move_checkpoint_text()

func _move_checkpoint_text() -> void:
	if not checkpoint_text:
		return
	var tween: Tween = checkpoint_text.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(checkpoint_text, "position:z", text_target_z, text_move_duration)
