extends Checkpoint

@export var aura_color: Color = Color(1, 0.972549, 0, 1)
@export var aura_duration: float = 1.25
@export var aura_extra_time: float = 0.5
@export var crown_shrink_duration: float = 0.2

@export var light_texture: Texture2D

var _crown_mesh: MeshInstance3D
var _crown_sprite: Sprite3D
var _aura_particles: GPUParticles3D

func _ready() -> void:
	super._ready()
	_crown_mesh = get_node_or_null("Crown")
	_crown_sprite = get_node_or_null("CrownSprite")
	_aura_particles = get_node_or_null("FX_CrownAura")
	if _aura_particles:
		_init_particles()

func _process(delta: float) -> void:
	if _crown_mesh:
		_crown_mesh.rotate_y(delta)

func _init_particles() -> void:
	pass

func _on_checkpoint_body_entered(body: Node3D) -> void:
	if used:
		return
	if not body is Player:
		return
	used = true
	_take_crown()
	_enter_trigger(body)

func _take_crown() -> void:
	if not _aura_particles or not _crown_mesh or not _crown_sprite:
		return

	_refresh_particles_color()
	_set_particles_lifetime(aura_duration + aura_extra_time)
	_aura_particles.global_position = _crown_mesh.global_position
	_aura_particles.restart()
	_aura_particles.emitting = true

	var target_pos := _crown_sprite.position
	var half_duration := aura_duration / 2.0

	_crown_mesh_shrink()

	var tw := create_tween()
	tw.set_parallel(true)

	tw.tween_property(_aura_particles, "position:x", target_pos.x, aura_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_aura_particles, "position:z", target_pos.z, aura_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_aura_particles, "position:y", target_pos.y + 5.0, half_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

	tw.set_parallel(false)
	tw.tween_callback(_crown_sprite_fade)
	tw.tween_property(_aura_particles, "position:y", target_pos.y, half_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_aura_particles.emitting = false
	)

func _crown_mesh_shrink() -> void:
	#var tw := create_tween()
	#tw.tween_property(_crown_mesh, "scale", Vector3.ZERO, crown_shrink_duration)
	$Crown.queue_free()

func _crown_sprite_fade() -> void:
	var tw := create_tween()
	tw.tween_property(_crown_sprite, "modulate:a", 0.0, aura_duration * 0.5)
	tw.tween_callback(func() -> void:
		if light_texture:
			_crown_sprite.texture = light_texture
	)
	tw.tween_property(_crown_sprite, "modulate:a", 1.0, aura_duration * 0.5)

func _refresh_particles_color() -> void:
	pass

func _set_particles_lifetime(duration: float) -> void:
	var systems := _aura_particles.get_children()
	systems.append(_aura_particles)
	for system in systems:
		if system is GPUParticles3D:
			system.lifetime = duration
