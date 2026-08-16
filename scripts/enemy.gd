class_name Enemy extends CharacterBody2D

## Sound played when the enemy dies
const DEATH_SOUND := preload("res://assets/Audios/enemy_dead.wav")

## Combined status shader: white hit-flash + cyan "glitch" when slowed by a grenade
const GLITCH_SHADER := preload("res://shaders/enemy_glitch.gdshader")

## Idle enemy animation frames (frame_0 <-> frame_1), the virus sprite set
const FRAME_0 := preload("res://assets/TEST/enemy_virus_frame_0.png")
const FRAME_1 := preload("res://assets/TEST/enemy_virus_frame_1.png")
## Boss second-phase minion animation frames (the "1enemy_virus" sprite set)
const PHASE2_FRAME_0 := preload("res://assets/TEST/1enemy_virus_frame_0.png")
const PHASE2_FRAME_1 := preload("res://assets/TEST/1enemy_virus_frame_1.png")
## Seconds between each frame switch (frame_0 -> frame_1 -> frame_0 -> ...)
const FRAME_INTERVAL := 0.5

## Explosion effect shown when the enemy dies
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

## Short-lived ground "stain" (moco.png) left where the enemy died
const STAIN_SCENE := preload("res://scenes/enemy_stain.tscn")

## Speed in pixels per second
@export var speed: float = 150.0

## Health points
@export var max_health: int = 2

## Damage dealt to player on contact
@export var contact_damage: int = 1

## Points awarded on kill
@export var score_value: int = 100

## Chance to drop a stamina pan on death (0..1)
@export var pan_drop_chance: float = 0.35

## Chance for a boss-spawned minion to drop a healing item on death (0..1)
@export var heal_drop_chance: float = 0.3

## True if this enemy was released by the boss (drops healing occasionally)
var is_boss_minion: bool = false

## Current health
var health: int = 2

## Reference to the player (set on spawn)
var target: Player = null

## Number of active slow sources (from grenade zones). 0 = normal speed.
var slow_sources: int = 0

## Steam multiplier applied while slowed by a grenade zone
const SLOW_FACTOR := 0.4

## Seconds between obstacle ram hits (so "10 hits" = ~4s per enemy)
const OBSTACLE_HIT_INTERVAL := 0.4

## Cooldown before the enemy can chip the next obstacle again
var _obstacle_hit_timer: float = 0.0

## Timer counting down to the next asteroid-frame switch
var _frame_timer: float = FRAME_INTERVAL

## Whether the sprite currently shows frame_1 (else frame_0)
var _use_frame_1: bool = false

## If true, this enemy animates the boss second-phase frame set
## (PHASE2_FRAME_0/1, the "1enemy_virus" sprites) instead of the default set.
var use_phase2_texture: bool = false

## Tween driving the white hit-flash (killed before restarting)
var _flash_tween: Tween = null

## Status ShaderMaterial (flash + glitch) applied to the sprite
var _status_mat: ShaderMaterial = null

## Cached slow-state so we only poke the shader on change
var _was_slowed: bool = false


func _ready() -> void:
	health = max_health
	_frame_timer = FRAME_INTERVAL
	_use_frame_1 = false
	# Ensure the sprite starts on frame_0 of the correct texture set.
	var sp: Sprite2D = $Sprite2D as Sprite2D
	if sp:
		sp.texture = PHASE2_FRAME_0 if use_phase2_texture else FRAME_0
		_status_mat = ShaderMaterial.new()
		_status_mat.shader = GLITCH_SHADER
		sp.material = _status_mat
	# Connect hitbox area signal for contact damage
	var hitbox: Area2D = $Hitbox as Area2D
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		# Find player in scene
		var players: Array = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0] as Player
		else:
			return

	# Slow down if inside a grenade zone
	var effective_speed: float = speed * (SLOW_FACTOR if slow_sources > 0 else 1.0)
	_update_glitch_status()

	# Move toward player
	var direction: Vector2 = (target.global_position - global_position).normalized()
	velocity = direction * effective_speed
	move_and_slide()
	_damage_blocking_obstacles(_delta)
	_animate_frames(_delta)

	# Rotate to face movement direction
	if velocity.length() > 1.0:
		rotation = velocity.angle()


## Break obstacles the enemy is ramming against (collision cooldown based)
func _damage_blocking_obstacles(delta: float) -> void:
	_obstacle_hit_timer -= delta
	if _obstacle_hit_timer > 0.0:
		return
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision2D = get_slide_collision(i)
		var collider: Node = col.get_collider()
		if collider is Obstacle:
			(collider as Obstacle).take_hit(1)
			_obstacle_hit_timer = OBSTACLE_HIT_INTERVAL
			return


## Alternate the enemy sprite between its two frames (frame_0 <-> frame_1)
## every FRAME_INTERVAL seconds. Uses the boss second-phase frame set when
## `use_phase2_texture` is set.
func _animate_frames(delta: float) -> void:
	_frame_timer -= delta
	if _frame_timer <= 0.0:
		_use_frame_1 = not _use_frame_1
		var sp: Sprite2D = $Sprite2D as Sprite2D
		if sp:
			if use_phase2_texture:
				sp.texture = PHASE2_FRAME_1 if _use_frame_1 else PHASE2_FRAME_0
			else:
				sp.texture = FRAME_1 if _use_frame_1 else FRAME_0
		_frame_timer = FRAME_INTERVAL


## Flash the enemy sprite white briefly on damage (uses the shared status shader).
func _flash_hit() -> void:
	if _status_mat == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_status_mat.set_shader_parameter("flash", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_status_mat, "shader_parameter/flash", 0.0, 0.15)


## Toggle the cyan "glitch" while the enemy is slowed by a grenade zone.
func _update_glitch_status() -> void:
	var slowed: bool = slow_sources > 0
	if slowed != _was_slowed and _status_mat:
		_status_mat.set_shader_parameter("glitch", 1.0 if slowed else 0.0)
		_was_slowed = slowed


func take_damage(amount: int) -> void:
	health -= amount
	_flash_hit()
	if health <= 0:
		_die()


func _die() -> void:
	_play_death_sound()
	_spawn_death_explosion()
	_spawn_death_stain()

	# Award score via GameManager and possibly drop a stamina pan
	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.add_score(score_value)
		gm.register_enemy_killed()
		if randf() < pan_drop_chance:
			gm.spawn_item(Item.ItemType.STAMINA, global_position)
		# Boss minions occasionally release a healing item, but the number that
		# can appear during the boss fight is hard-capped (per fight).
		if is_boss_minion and randf() < heal_drop_chance and gm.has_method("spawn_boss_minion_heal"):
			gm.spawn_boss_minion_heal(global_position)

	queue_free()


## Play the death sound at this enemy's position. The enemy frees itself right
## after, so the sound is parented to a persistent container and auto-frees
## once it finishes playing.
func _play_death_sound() -> void:
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = DEATH_SOUND
	sfx.global_position = global_position
	sfx.volume_db = -6.0
	sfx.finished.connect(sfx.queue_free)
	container.add_child(sfx)
	sfx.play()


## Spawn a small particle explosion at the enemy's position.
func _spawn_death_explosion() -> void:
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var boom: Explosion = EXPLOSION_SCENE.instantiate() as Explosion
	boom.global_position = global_position
	boom.particle_count = 40
	boom.scatter = 55.0
	boom.particle_scale = 0.9
	boom.particle_color = _sprite_color()
	container.add_child(boom)


## Average the enemy's current sprite texture color so its explosion matches its
## look (opaque pixels weighted by alpha).
func _sprite_color() -> Color:
	var sp: Sprite2D = $Sprite2D as Sprite2D
	if sp == null or sp.texture == null:
		return Color(1.0, 0.35, 0.2)
	var img: Image = sp.texture.get_image()
	if img == null:
		return Color(1.0, 0.35, 0.2)
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() * img.get_height() > 4096:
		img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	var acc_r := 0.0
	var acc_g := 0.0
	var acc_b := 0.0
	var n := 0.0
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var c: Color = img.get_pixel(x, y)
			var a: float = c.a
			acc_r += c.r * a
			acc_g += c.g * a
			acc_b += c.b * a
			n += a
	if n <= 0.001:
		return Color(1.0, 0.35, 0.2)
	return Color(acc_r / n, acc_g / n, acc_b / n)


## Leave a short-lived "stain" (moco.png visual) on the ground where the enemy
## died. It fades out and frees itself after ~2 seconds.
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


## Size multiplier for this enemy's stain, derived from its on-screen sprite size
## so bigger enemies leave proportionally bigger stains.
func _stain_base_scale() -> float:
	var sp: Sprite2D = $Sprite2D as Sprite2D
	if sp == null or sp.texture == null:
		return 4.0
	var w: float = sp.texture.get_width() * sp.scale.x
	var h: float = sp.texture.get_height() * sp.scale.y
	return maxf(w, h) * 1.6 / 32.0


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player:
		body.take_damage(contact_damage)
		_die()  # Enemy dies on contact too
