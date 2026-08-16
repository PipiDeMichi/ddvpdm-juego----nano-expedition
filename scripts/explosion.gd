class_name Explosion extends Node2D
## One-shot particle burst effect used for enemy, obstacle and boss destruction.
## Emits a single burst of colored particles that scatter outward and fade, then
## frees itself.

## Number of particles in the burst
@export var particle_count: int = 24
## Particle lifetime (seconds)
@export var particle_lifetime: float = 0.55
## How far particles scatter (roughly, px) - drives the initial velocity
@export var scatter: float = 60.0
## Global particle size scale
@export var particle_scale: float = 1.0
## Particle tint
@export var particle_color: Color = Color(1.0, 0.6, 0.25)

## Whether to also emit the "rebound" debris burst (pops up, then falls back)
@export var rebound: bool = true

## Whether to also emit an "outward nova" burst: fast particles that blast from
## the center outward and decelerate, reading like a radial shockwave expanding out.
@export var outward_burst: bool = false


func _ready() -> void:
	_add_particles()
	# Free once the burst has fully played out
	var tw := create_tween()
	tw.tween_interval(particle_lifetime + 0.2)
	tw.tween_callback(queue_free)


func _add_particles() -> void:
	var p := CPUParticles2D.new()
	p.name = "Burst"
	p.amount = particle_count
	p.lifetime = particle_lifetime
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.direction = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = scatter * 3.0
	p.initial_velocity_max = scatter * 6.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.5 * particle_scale
	p.scale_amount_max = 1.5 * particle_scale
	p.color = particle_color
	p.texture = _make_particle_texture()
	p.z_index = 50
	add_child(p)

	# Post-death "rebound" debris: a second burst that pops upward and then falls
	# back down with gravity, like chunks bouncing off the ground after impact.
	if rebound:
		var r := CPUParticles2D.new()
		r.name = "Rebound"
		r.amount = maxi(6, int(particle_count * 0.7))
		r.lifetime = 0.7
		r.one_shot = true
		r.emitting = true
		r.explosiveness = 1.0
		r.direction = Vector2.UP
		r.spread = 160.0
		r.initial_velocity_min = scatter * 2.0
		r.initial_velocity_max = scatter * 5.0
		r.gravity = Vector2(0.0, 560.0)
		r.scale_amount_min = 0.4 * particle_scale
		r.scale_amount_max = 1.2 * particle_scale
		r.color = particle_color
		r.texture = _make_particle_texture()
		r.z_index = 50
		add_child(r)

	# "Outward nova": high-velocity particles blasting out from the center and
	# decelerating via damping, so it reads like a shockwave expanding outward.
	if outward_burst:
		var o := CPUParticles2D.new()
		o.name = "Outward"
		o.amount = maxi(8, int(particle_count * 1.1))
		o.lifetime = particle_lifetime
		o.one_shot = true
		o.emitting = true
		o.explosiveness = 1.0
		o.direction = Vector2.ZERO
		o.spread = 180.0
		o.initial_velocity_min = scatter * 6.0
		o.initial_velocity_max = scatter * 10.0
		o.gravity = Vector2.ZERO
		o.damping_min = 5.0
		o.damping_max = 5.0
		o.scale_amount_min = 0.5 * particle_scale
		o.scale_amount_max = 1.3 * particle_scale
		o.color = particle_color
		o.texture = _make_particle_texture()
		o.z_index = 50
		add_child(o)


## Build a small soft-edged white circle texture used as the particle sprite.
func _make_particle_texture() -> Texture2D:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = (float(size) - 1.0) * 0.5
	for x in range(size):
		for y in range(size):
			var d: float = Vector2(x - c, y - c).length()
			if d <= c:
				var a: float = clampf((c - d) / c, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
