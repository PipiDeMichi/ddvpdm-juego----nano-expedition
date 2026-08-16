class_name Mine extends Node2D
## Mine dropped by the boss. Sits for a short fuse (blinking a warning) then
## explodes, damaging the player if they are close enough.

## Distinct particle-only explosion for the mine blast (NOT the bomb's ring)
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

## Seconds before the mine detonates
@export var fuse_time: float = 2.0
## Radius (px) within which the explosion damages the player
@export var explosion_radius: float = 80.0
## Damage dealt to the player by the blast
@export var explosion_damage: int = 1
## Visual radius of the mine body
@export var base_radius: float = 18.0

var _t: float = 0.0

@onready var _visual: Sprite2D = $Visual


func _ready() -> void:
	# Size the virus-bomb sprite to match the mine's body. A touch larger than the
	# hit radius so the dark blob stays readable against the dark arena.
	if _visual and _visual.texture:
		var s: float = base_radius * 2.4 / _visual.texture.get_size().x
		_visual.scale = Vector2(s, s)


func _physics_process(delta: float) -> void:
	_t += delta
	# Blink faster the closer it gets to detonation
	var blink_rate: float = 3.0 + 7.0 * (_t / fuse_time)
	modulate.a = 0.45 if fmod(_t * blink_rate, 1.0) < 0.5 else 1.0
	if _t >= fuse_time:
		_explode()
		queue_free()


func _explode() -> void:
	# Hurt the player if within the blast radius
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and is_instance_valid(p) and global_position.distance_to(p.global_position) <= explosion_radius:
			(p as Player).take_damage(explosion_damage)

	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return

	# Mine blast sound (synthesized low rumble — distinct from the player's bomb)
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = _make_mine_blast_audio()
	sfx.global_position = global_position
	sfx.volume_db = -4.0
	sfx.finished.connect(sfx.queue_free)
	container.add_child(sfx)
	sfx.play()

	# Distinct particle burst (purple/red, no ring) so it reads differently from
	# the player's bomb
	if EXPLOSION_SCENE:
		var boom: Explosion = EXPLOSION_SCENE.instantiate() as Explosion
		boom.global_position = global_position
		boom.particle_count = 26
		boom.scatter = 70.0
		boom.particle_lifetime = 0.6
		boom.particle_scale = 1.1
		# Matches the virus_bomb texture's actual color (a vivid magenta — the
		# alpha-weighted average of its opaque pixels)
		boom.particle_color = Color(0.57, 0.02, 0.58)
		boom.outward_burst = true
		container.add_child(boom)


## Build a short decaying-noise burst as the mine explosion audio, so the mine
## has its own sound instead of reusing the player's bomb blast sample.
func _make_mine_blast_audio() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.45
	var n := int(rate * dur)
	var samples := PackedByteArray()
	samples.resize(n * 2)
	var seedv := randi()
	for i in range(n):
		var t: float = float(i) / float(rate)
		var env: float = pow(1.0 - t / dur, 2.0)
		var noise: float = (hash(seedv + i) % 2000) / 1000.0 - 1.0
		var s: float = (noise * 0.6 + sin(TAU * 55.0 * t) * 0.5) * env
		var v: int = int(clamp(s, -1.0, 1.0) * 32767.0)
		samples.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = samples
	return wav
