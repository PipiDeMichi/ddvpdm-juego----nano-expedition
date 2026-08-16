class_name Boss extends CharacterBody2D
# Large boss that appears after reaching the score threshold. Descends from the
# top toward the center, then hovers and uses three attacks:
#  - a burst of shots toward the player
#  - spawning common enemies
#  - throwing slow bombs that leave zones slowing the player

## Boss HP (each player bullet deals 1, so this is the shot count)
@export var max_health: int = 240
## Hover / chase speed once engaged
@export var move_speed: float = 70.0
## Damage dealt to the player on contact
@export var contact_damage: int = 1
## Points awarded when defeated
@export var score_value: int = 2000

## Randomly-picked hurt sounds (played when the boss takes damage)
const HURT_SOUNDS: Array = [
	preload("res://assets/Audios/acid_stalker_hurt_1.ogg"),
	preload("res://assets/Audios/acid_stalker_hurt_2.ogg"),
]
## Sound volume for boss hurt noises
@export var hurt_sound_volume_db: float = -6.0
## Cooldown bounds (seconds) between hurt sounds so fast hits don't spam audio
@export var hurt_sound_cooldown_min: float = 0.5
@export var hurt_sound_cooldown_max: float = 1.0

## Randomly-picked idle sounds (played periodically while engaged)
const IDLE_SOUNDS: Array = [
	preload("res://assets/Audios/acid_stalker_idle_1.ogg"),
	preload("res://assets/Audios/acid_stalker_idle_2.ogg"),
	preload("res://assets/Audios/acid_stalker_idle_3.ogg"),
	preload("res://assets/Audios/acid_stalker_idle_4.ogg"),
]
## Volume for idle grunts
@export var idle_sound_volume_db: float = -8.0
## Bounds for how often an idle sound plays (seconds)
@export var idle_sound_min: float = 4.0
@export var idle_sound_max: float = 8.0

## Randomly-picked death sounds (played when the boss is destroyed)
const DIE_SOUNDS: Array = [
	preload("res://assets/Audios/acid_stalker_dies_1.ogg"),
	preload("res://assets/Audios/acid_stalker_dies_2.ogg"),
]
## Volume for the death sound
@export var die_sound_volume_db: float = -3.0

## Boss bullet scene (burst shots)
@export var bullet_scene: PackedScene
## Slow bomb scene
@export var slow_bomb_scene: PackedScene
## Normal enemy scene (for the "spawn minions" attack)
@export var enemy_scene: PackedScene

## Mine scene for the "plant mines" attack
const MINE_SCENE := preload("res://scenes/mine.tscn")

## Explosion effect shown on boss destruction
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
## Expanding ring shown on boss destruction
const BOSS_DEATH_RING := preload("res://scenes/expanding_ring.tscn")

## Ground "stain" (moco.png) left where the boss dies
const STAIN_SCENE := preload("res://scenes/enemy_stain.tscn")

## Animated asteroid frames for the boss body (frame_0 <-> frame_1)
const BOSS_FRAME_0 := preload("res://assets/TEST/enemy_asteroid_frame_0.png")
const BOSS_FRAME_1 := preload("res://assets/TEST/enemy_asteroid_frame_1.png")
## Seconds between each boss-body frame switch
const FRAME_INTERVAL := 0.5

## Shader used for the white hit-flash when the boss takes damage
const FLASH_SHADER := preload("res://shaders/hit_flash.gdshader")

## Duration (s) of the once-on-enrage rapid machine-gun burst, which also
## doubles as the aim delay: bullets stream at the player position locked when
## the burst began.
const ENRAGE_MG_DURATION := 0.7
## Seconds between machine-gun shots (rapid cadence)
const ENRAGE_MG_INTERVAL := 0.06
## Random bounds for how many machine-gun emplacements deploy at enemy spawn points
const ENRAGE_MG_EMP_MIN := 2
const ENRAGE_MG_EMP_MAX := 4
## Random seconds between repeated enrage barrages (machine gun + enemy wave)
const ENRAGE_BARRAGE_MIN := 7.0
const ENRAGE_BARRAGE_MAX := 13.0
## Random seconds between standalone machine-gun bursts while enraged, so the
## boss keeps a steady, more consistent machine-gun presence between barrages
const ENRAGE_MG_REPEAT_MIN := 4.0
const ENRAGE_MG_REPEAT_MAX := 8.0
## Random bounds for the enemy wave size spawned on each barrage (phase-2 cap)
const ENRAGE_ENEMY_MIN := 2
const ENRAGE_ENEMY_MAX := 5
## Number of obstacles flown in from off-screen on enrage
const ENRAGE_OBSTACLE_COUNT := 4
## Maximum number of phase-2 minions ("1enemy_virus" enemies) alive at once
const MAX_PHASE2_MINIONS := 5

signal health_changed(hp: int, max_hp: int)
signal died()

var health: int = 240
var target: Player = null

## 0 = descending to center, 1 = engaged (hovering + attacking)
var _phase: int = 0
var _center: Vector2 = Vector2.ZERO
var _hover_target: Vector2 = Vector2.ZERO
var _hover_timer: float = 0.0
var _burst_timer: float = 1.2
var _minion_timer: float = 4.0
var _slow_bomb_timer: float = 3.0
var _mine_timer: float = 5.0

## Time left stunned (boss cannot move or attack while > 0)
var _stun_time: float = 0.0
## Whether the boss has entered its aggressive (half-health) state
var _enraged: bool = false

## Machine-gun burst state (triggered once, on enrage)
var _mg_active: bool = false
## How long the current machine-gun burst has been running
var _mg_elapsed: float = 0.0
## Countdown to the next machine-gun shot
var _mg_fire_timer: float = 0.0
## Player position the burst locks onto at its start (the delayed aim point)
var _mg_aim: Vector2 = Vector2.ZERO
## World positions the machine gun is deployed at (enemy spawn points); one
## bullet fires from each emplacement per tick, aimed at the locked `_mg_aim`.
var _mg_deploy_points: Array[Vector2] = []

## Countdown to the next repeated enrage barrage (machine gun + enemy wave).
## Only active once the boss is enraged; re-rolls to a random interval each time.
var _barrage_timer: float = 0.0
## Countdown to the next standalone machine-gun burst (enraged only). Fires more
## often than the barrage so the machine gun keeps a steady, consistent presence.
var _mg_repeat_timer: float = 0.0

## Time left before the next hurt sound may play (prevents spam)
var _hurt_sound_timer: float = 0.0

## Time left before the next idle sound may play
var _idle_sound_timer: float = 3.0

## Timer counting down to the next boss-body frame switch
var _frame_timer: float = FRAME_INTERVAL
## Whether the boss sprite currently shows frame_1 (else frame_0)
var _use_frame_1: bool = false

## Tween driving the white hit-flash (killed before restarting)
var _flash_tween: Tween = null


func _ready() -> void:
	add_to_group("boss")
	health = max_health
	_center = get_viewport().get_visible_rect().size * 0.5
	_hover_target = _center
	_frame_timer = FRAME_INTERVAL
	_use_frame_1 = false
	var sp: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sp:
		sp.texture = BOSS_FRAME_0
	var hitbox: Area2D = get_node_or_null("Hitbox") as Area2D
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	health_changed.emit(health, max_health)


func take_damage(amount: int = 1) -> void:
	health -= amount
	health_changed.emit(health, max_health)
	_flash_hit()
	# Hurt sound, throttled by a short random cooldown so it isn't spammy
	if _hurt_sound_timer <= 0.0:
		_hurt_sound_timer = randf_range(hurt_sound_cooldown_min, hurt_sound_cooldown_max)
		_play_hurt_sound()
	# At or below half health the boss becomes aggressive (releases more and
	# faster enemies and slow bombs) and starts repeating the machine-gun +
	# enemy-wave barrage on a random cadence.
	if not _enraged and health <= int(max_health * 0.5):
		_enraged = true
		_barrage_timer = randf_range(ENRAGE_BARRAGE_MIN, ENRAGE_BARRAGE_MAX)
		_mg_repeat_timer = randf_range(ENRAGE_MG_REPEAT_MIN, ENRAGE_MG_REPEAT_MAX)
		_on_enrage()
	if health <= 0:
		_play_die_sound()
		_play_death_explosion()
		_spawn_death_stain()
		died.emit()
		queue_free()


## Spawn a large multi-burst destruction explosion at the boss's position.
func _play_death_explosion() -> void:
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	# Big main burst
	var boom: Explosion = EXPLOSION_SCENE.instantiate() as Explosion
	boom.global_position = global_position
	boom.particle_count = 90
	boom.scatter = 220.0
	boom.particle_lifetime = 1.0
	boom.particle_scale = 2.2
	boom.particle_color = Color(1.0, 0.5, 0.15)
	container.add_child(boom)
	# Secondary white-hot inner burst
	var boom2: Explosion = EXPLOSION_SCENE.instantiate() as Explosion
	boom2.global_position = global_position
	boom2.particle_count = 60
	boom2.scatter = 130.0
	boom2.particle_lifetime = 0.7
	boom2.particle_scale = 1.4
	boom2.particle_color = Color(1.0, 0.9, 0.55)
	container.add_child(boom2)
	# Expanding shockwave ring
	var ring: ExpandingRing = BOSS_DEATH_RING.instantiate() as ExpandingRing
	ring.global_position = global_position
	ring.end_radius = 420.0
	ring.ring_count = 4
	ring.color = Color(1.0, 0.6, 0.2)
	container.add_child(ring)


## Spawn a ground stain matching the boss's asteroid texture color and size.
func _spawn_death_stain() -> void:
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var stain: EnemyStain = STAIN_SCENE.instantiate() as EnemyStain
	stain.global_position = global_position
	stain.color = _sprite_color()
	stain.base_scale = _stain_base_scale()
	container.add_child(stain)


## Average the boss's sprite texture color so its stain matches its look.
func _sprite_color() -> Color:
	var sp: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	var tex: Texture2D = BOSS_FRAME_0
	if sp != null and sp.texture != null:
		tex = sp.texture
	var img: Image = tex.get_image()
	if img == null:
		return Color(0.6, 0.6, 0.6)
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() * img.get_height() > 4096:
		img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0.0
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var c: Color = img.get_pixel(x, y)
			var a: float = c.a
			r += c.r * a
			g += c.g * a
			b += c.b * a
			n += a
	if n <= 0.001:
		return Color(0.6, 0.6, 0.6)
	return Color(r / n, g / n, b / n)


## Size multiplier for the boss stain, derived from its large on-screen sprite.
func _stain_base_scale() -> float:
	var w: float = BOSS_FRAME_0.get_width() * 4.0
	var h: float = BOSS_FRAME_0.get_height() * 4.0
	var sp: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sp != null and sp.texture != null:
		w = sp.texture.get_width() * sp.scale.x
		h = sp.texture.get_height() * sp.scale.y
	return maxf(w, h) * 1.3 / 32.0


## Play a random one of the boss idle sounds at its position.
func _play_idle_sound() -> void:
	if IDLE_SOUNDS.is_empty():
		return
	var stream: AudioStream = IDLE_SOUNDS[randi() % IDLE_SOUNDS.size()] as AudioStream
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.global_position = global_position
	sfx.volume_db = idle_sound_volume_db
	sfx.finished.connect(sfx.queue_free)
	_spawn_to_scene(sfx)
	sfx.play()


## Play a random one of the boss death sounds (spawned outside the boss so the
## sound keeps playing after the boss itself is freed).
func _play_die_sound() -> void:
	if DIE_SOUNDS.is_empty():
		return
	var stream: AudioStream = DIE_SOUNDS[randi() % DIE_SOUNDS.size()] as AudioStream
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.global_position = global_position
	sfx.volume_db = die_sound_volume_db
	sfx.finished.connect(sfx.queue_free)
	_spawn_to_scene(sfx)
	sfx.play()


## Play a random one of the boss hurt sounds at its position.
func _play_hurt_sound() -> void:
	if HURT_SOUNDS.is_empty():
		return
	var stream: AudioStream = HURT_SOUNDS[randi() % HURT_SOUNDS.size()] as AudioStream
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.global_position = global_position
	sfx.volume_db = hurt_sound_volume_db
	sfx.finished.connect(sfx.queue_free)
	_spawn_to_scene(sfx)
	sfx.play()


## Stun the boss so it cannot move or attack for the given duration.
func stun(duration: float) -> void:
	if duration > _stun_time:
		_stun_time = duration


## Flash the boss body white for a brief moment when it takes damage.
func _flash_hit() -> void:
	var sp: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sp == null:
		return
	var mat := sp.material as ShaderMaterial
	if mat == null or mat.shader != FLASH_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = FLASH_SHADER
		sp.material = mat
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	mat.set_shader_parameter("flash", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(mat, "shader_parameter/flash", 0.0, 0.15)


## One-shot spectacle that kicks off the machine-gun burst, spawns a random
## wave of standard enemies off-screen, and flies in a few fresh obstacles.
## Runs once when the boss first crosses half health, then repeats at random
## intervals for the rest of the enraged phase.
func _on_enrage() -> void:
	_start_machine_gun()
	var gm: Node = get_tree().get_first_node_in_group("game_manager")
	if gm == null:
		return
	if gm.has_method("spawn_enemy_wave"):
		gm.spawn_enemy_wave(randi_range(ENRAGE_ENEMY_MIN, ENRAGE_ENEMY_MAX))
	if gm.has_method("introduce_obstacles"):
		gm.introduce_obstacles(ENRAGE_OBSTACLE_COUNT)


## Begin the rapid machine-gun burst. The gun is deployed at the normal enemy
## spawn points (off the visible screen edges, where enemies charge in), and
## streams bullets at the player position locked here — a ~0.7s movement delay
## that tracks where the player was as they keep moving.
func _start_machine_gun() -> void:
	if target == null or bullet_scene == null:
		return
	_mg_active = true
	_mg_elapsed = 0.0
	_mg_fire_timer = 0.0
	_mg_aim = target.global_position

	# Deploy the gun at enemy spawn points so the burst rakes in from the edges.
	_mg_deploy_points.clear()
	var gm: Node = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("get_enemy_spawn_positions"):
		_mg_deploy_points = gm.get_enemy_spawn_positions(randi_range(ENRAGE_MG_EMP_MIN, ENRAGE_MG_EMP_MAX))
	# Fallback: fire from the boss itself if no spawn points are available.
	if _mg_deploy_points.is_empty():
		_mg_deploy_points.append(global_position)


## Fire one machine-gun bullet from every deployed emplacement toward the locked
## (delayed) aim point, with a small random rake so the rapid stream isn't a
## perfectly straight laser.
func _fire_machine_gun_shot() -> void:
	if bullet_scene == null:
		return
	for p: Vector2 in _mg_deploy_points:
		var b: BossBullet = bullet_scene.instantiate() as BossBullet
		b.global_position = p
		var dir: Vector2 = (_mg_aim - p).normalized()
		b.direction = dir.rotated(randf_range(-0.05, 0.05))
		b.add_to_group("boss_bullet")
		_spawn_to_scene(b)


func _physics_process(delta: float) -> void:
	# Hurt-sound cooldown always ticks (even during stun)
	if _hurt_sound_timer > 0.0:
		_hurt_sound_timer -= delta
	# Boss body frame animation runs in every state (stun/descend/engaged)
	_animate_frames(delta)

	# While stunned the boss is frozen (still takes damage, just can't act)
	if _stun_time > 0.0:
		_stun_time -= delta
		modulate.a = 0.4 if fmod(_stun_time * 10.0, 1.0) < 0.5 else 1.0
		velocity = Vector2.ZERO
		if _stun_time <= 0.0:
			_stun_time = 0.0
			modulate.a = 1.0
		return

	if target == null or not is_instance_valid(target):
		var players: Array = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as Player
		else:
			return

	if _phase == 0:
		# Descend from the top toward the center
		if global_position.distance_to(_center) > 30.0:
			velocity = (_center - global_position).normalized() * move_speed * 2.0
		else:
			_phase = 1
		move_and_slide()
		rotation = (target.global_position - global_position).angle()
		return

	# Engaged: hover around the center, always facing the player
	_hover(delta)
	move_and_slide()
	rotation = (target.global_position - global_position).angle()

	# Rapid machine-gun burst: stream bullets at the player-position locked when
	# the burst began (a ~0.7s movement delay), then stop.
	if _mg_active:
		_mg_elapsed += delta
		_mg_fire_timer -= delta
		if _mg_fire_timer <= 0.0:
			_mg_fire_timer = ENRAGE_MG_INTERVAL
			_fire_machine_gun_shot()
		if _mg_elapsed >= ENRAGE_MG_DURATION:
			_mg_active = false

	# Once enraged, repeat the combined barrage (machine gun + enemy wave) on a
	# random cadence so the boss keeps applying pressure throughout phase 2.
	if _enraged:
		_barrage_timer -= delta
		if _barrage_timer <= 0.0:
			_barrage_timer = randf_range(ENRAGE_BARRAGE_MIN, ENRAGE_BARRAGE_MAX)
			_on_enrage()

		# Standalone machine-gun bursts on their own (faster) cadence, so the
		# machine gun fires regularly between barrages — more consistent pressure.
		_mg_repeat_timer -= delta
		if _mg_repeat_timer <= 0.0:
			_mg_repeat_timer = randf_range(ENRAGE_MG_REPEAT_MIN, ENRAGE_MG_REPEAT_MAX)
			_start_machine_gun()

	# Periodic idle sounds while engaged
	_idle_sound_timer -= delta
	if _idle_sound_timer <= 0.0:
		_idle_sound_timer = randf_range(idle_sound_min, idle_sound_max)
		_play_idle_sound()

	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_timer = randf_range(1.4, 2.2) if _enraged else randf_range(1.6, 2.6)
		_burst()

	_minion_timer -= delta
	if _minion_timer <= 0.0:
		_minion_timer = randf_range(2.5, 4.0) if _enraged else randf_range(5.0, 8.0)
		_spawn_minions()

	_slow_bomb_timer -= delta
	if _slow_bomb_timer <= 0.0:
		_slow_bomb_timer = randf_range(2.0, 3.5) if _enraged else randf_range(4.0, 7.0)
		_throw_slow_bomb()

	_mine_timer -= delta
	if _mine_timer <= 0.0:
		_mine_timer = randf_range(2.5, 4.5) if _enraged else randf_range(6.0, 9.0)
		_throw_mines()


func _hover(delta: float) -> void:
	_hover_timer -= delta
	if _hover_timer <= 0.0:
		_hover_timer = randf_range(2.0, 4.0)
		_hover_target = _center + Vector2(randf_range(-170.0, 170.0), randf_range(-90.0, 90.0))
	velocity = (_hover_target - global_position).normalized() * move_speed


## Alternate the boss sprite between frame_0 and frame_1 every FRAME_INTERVAL
## seconds.
func _animate_frames(delta: float) -> void:
	_frame_timer -= delta
	if _frame_timer <= 0.0:
		_use_frame_1 = not _use_frame_1
		var sp: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
		if sp:
			sp.texture = BOSS_FRAME_1 if _use_frame_1 else BOSS_FRAME_0
		_frame_timer = FRAME_INTERVAL


func _burst() -> void:
	if bullet_scene == null or target == null:
		return
	var base: float = (target.global_position - global_position).angle()
	var count: int = 10 if _enraged else 8
	var spread: float = 1.3 if _enraged else 1.0
	for i in range(count):
		var b: BossBullet = bullet_scene.instantiate() as BossBullet
		var offset: float = (float(i) - float(count - 1) / 2.0) * (spread / float(count - 1))
		b.global_position = global_position
		b.direction = Vector2.from_angle(base + offset)
		b.add_to_group("boss_bullet")
		_spawn_to_scene(b)


func _spawn_minions() -> void:
	if enemy_scene == null:
		return
	var minion_count: int = 5 if _enraged else 3
	# Cap phase-2 minions ("1enemy_virus" enemies) so no more than
	# MAX_PHASE2_MINIONS are alive at once.
	if _enraged:
		minion_count = mini(minion_count, max(0, MAX_PHASE2_MINIONS - _count_phase2_minions()))
	for i in range(minion_count):
		var e: Enemy = enemy_scene.instantiate() as Enemy
		e.global_position = _center + Vector2(randf_range(-320.0, 320.0), randf_range(-220.0, 220.0))
		# Boss minions are weak (die in one shot) but occasionally drop healing.
		# Once enraged, they become tougher and need 3 shots to bring down.
		e.max_health = 3 if _enraged else 1
		e.is_boss_minion = true
		# Second-phase (enraged) minions wear the "1enemy_virus" texture set.
		e.use_phase2_texture = _enraged
		e.add_to_group("enemy")
		_spawn_to_scene(e)


## Count how many phase-2 boss minions (the "1enemy_virus" enemies) are alive.
func _count_phase2_minions() -> int:
	var n: int = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and is_instance_valid(e) and e.use_phase2_texture:
			n += 1
	return n


func _throw_slow_bomb() -> void:
	if slow_bomb_scene == null:
		return
	var sb: SlowBomb = slow_bomb_scene.instantiate() as SlowBomb
	sb.global_position = global_position
	if target:
		sb.direction = (target.global_position - global_position).normalized()
	# Enraged slow zones grow bigger toward the player
	sb.enlarged = _enraged
	_spawn_to_scene(sb)


## Plant a cluster of mines around the player. They arm for their fuse then blow up.
func _throw_mines() -> void:
	if target == null:
		return
	var count: int = 4 if _enraged else 3
	var tgt: Vector2 = target.global_position
	for i in range(count):
		var m: Mine = MINE_SCENE.instantiate() as Mine
		m.global_position = tgt + Vector2(randf_range(-150.0, 150.0), randf_range(-150.0, 150.0))
		_spawn_to_scene(m)


func _spawn_to_scene(node: Node) -> void:
	if node == null:
		return
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container:
		container.add_child(node)
	else:
		node.queue_free()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).take_damage(contact_damage)
