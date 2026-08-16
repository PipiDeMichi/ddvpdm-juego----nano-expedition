class_name Player extends CharacterBody2D

## Randomly-picked shooting sounds (heard on every shot)
const SHOOT_SOUNDS: Array = [
	preload("res://assets/Audios/shoot1.wav"),
	preload("res://assets/Audios/shoot2.wav"),
	preload("res://assets/Audios/shoot3.wav"),
]

## Sound played when the player throws a bomb
const BOMB_SOUND := preload("res://assets/Audios/bomb_blast.wav")

## Shader used for the white hit-flash when the player takes damage
const FLASH_SHADER := preload("res://shaders/hit_flash.gdshader")

## "Water drop" screen distortion spawned when the player uses the bomb
const WATER_DISTORTION_SCENE := preload("res://scenes/water_distortion.tscn")

## TRON-style neon tail that trails behind the player while moving
const TRAIL_SCENE := preload("res://scenes/trail.tscn")

## Sound played when the player throws a grenade
const GRENADE_SOUND := preload("res://assets/Audios/grunh.wav")

## Randomly-picked sounds heard when the player heals
const HEAL_SOUNDS: Array = [
	preload("res://assets/Audios/heal1.wav"),
	preload("res://assets/Audios/heal2.wav"),
	preload("res://assets/Audios/heal3.wav"),
]

## Randomly-picked dash sounds (heard on every dash)
const DASH_SOUNDS: Array = [
	preload("res://assets/Audios/stryder_dash_2ch_v1_01.wav"),
	preload("res://assets/Audios/stryder_dash_2ch_v1_02.wav"),
	preload("res://assets/Audios/stryder_dash_2ch_v1_03.wav"),
	preload("res://assets/Audios/stryder_dash_2ch_v1_04.wav"),
]

## Movement speed in pixels per second
@export var move_speed: float = 300.0

## How many seconds between each auto-shot
@export var fire_rate: float = 0.25

## Reference to the bullet scene
@export var bullet_scene: PackedScene

## Reference to the grenade scene
@export var grenade_scene: PackedScene

## Maximum health
@export var max_health: int = 3

## Absolute upper limit the max health can grow to via heal pickups
@export var max_life_cap: int = 10

## Invincibility time after taking damage (seconds)
@export var invincibility_time: float = 1.5

## ---- Dash ----
## Maximum number of dashes (refilled by picking up the dash-recharge item/pan)
@export var max_dashes: int = 5
## Dash speed
@export var dash_speed: float = 900.0
## How long a dash lasts (seconds)
@export var dash_duration: float = 0.18
## Window (ms) in which a second tap counts as a double-tap
@export var double_tap_window_ms: int = 250
## Speed granted right after a dash finishes (speed boost)
@export var dash_boost_speed: float = 520.0
## How long the post-dash speed boost lasts. No new dash while it's active.
@export var dash_boost_duration: float = 3.0

## ---- Dash trail ----
## How often (s) a trail afterimage is spawned while dashing
@export var trail_spawn_interval: float = 0.03
## How long (s) a trail afterimage takes to fade out
@export var trail_fade_time: float = 0.4
## Tint of the dash trail afterimages
@export var trail_color: Color = Color(0.782, 0.974, 1.0, 1.0)

## ---- Bomb ----
## Total bomb charges (never replenish by default)
@export var total_bomb_charges: int = 3
## Seconds to reclaim one bomb charge after using one (0 = no recharge)
@export var bomb_recharge_time: float = 60.0

## ---- Bomb effect ----
## Expanding ring shown at the player when a bomb is used
@export var ring_scene: PackedScene

## ---- Grenade ----
## Grenade cooldown in seconds
@export var grenade_cooldown: float = 10.0

## Current health
var health: int = 3

## Current dashes remaining
var dashes: int = 5

## Current bomb charges remaining
var bomb_charges: int = 3

## Countdown until the next bomb charge is reclaimed
var _bomb_recharge_timer: float = 0.0

## Virtual joystick reference for movement (set by Game)
var move_joystick: TouchJoystick = null

## Virtual joystick reference for aiming (set by Game)
var aim_joystick: TouchJoystick = null

## Optional rectangle (the combat arena) the player is clamped inside. If empty
## (zero size) it falls back to clamping within the full screen.
var clamp_rect: Rect2 = Rect2()

## Internal fire timer
var _fire_timer: float = 0.0

## Invincibility timer
var _invincibility_timer: float = 0.0

## Is player invincible right now
var _is_invincible: bool = false

## Dash state
var _is_dashing: bool = false
var _dash_dir: Vector2 = Vector2.ZERO
var _dash_time: float = 0.0

## Player's ship sprite (used to copy into trail afterimages)
var _sprite: Sprite2D = null
## Tween driving the white hit-flash (killed before restarting)
var _flash_tween: Tween = null
## Timer controlling how often trail afterimages spawn
var _trail_timer: float = 0.0

## TRON-style neon tail node (created at spawn, added to the game world)
var _trail: Trail2D = null

## Time left on the post-dash speed boost. While > 0, no new dash allowed.
var _boost_time: float = 0.0

## Number of active slow zones (from boss slow bombs). 0 = normal speed.
var slow_sources: int = 0

## Speed multiplier while inside a player slow zone
const PLAYER_SLOW_FACTOR := 0.45

## Last WASD press time per direction
var _last_dir_press: Dictionary = {"W": 0, "A": 0, "S": 0, "D": 0}

## Joystick double-tap detection
var _joy_edge: String = "idle"
var _joy_last_time: int = 0
var _joy_last_dir: Vector2 = Vector2.ZERO

## Grenade cooldown remaining
var grenade_remaining: float = 0.0

## Signals
signal player_died()
signal health_changed(new_health: int)
signal dashes_changed(dashes: int, max_dashes: int)
signal bomb_charges_changed(count: int)


func _ready() -> void:
	health = max_health
	dashes = max_dashes
	bomb_charges = total_bomb_charges
	bomb_charges_changed.emit(bomb_charges)
	dashes_changed.emit(dashes, max_dashes)
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	# The player collides with the arena boundary wall, which is on its own
	# collision layer (4, value 8) so that enemies can pass through it. Mask on
	# enemies/players (1) + cover obstacles (2) + the boundary wall (4).
	collision_mask = 1 | 2 | 8
	_setup_camera()
	_setup_trail()


## Create the TRON-style neon tail that follows the player while moving.
func _setup_trail() -> void:
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var trail: Trail2D = TRAIL_SCENE.instantiate() as Trail2D
	trail.target = self
	container.add_child(trail)
	_trail = trail


## Create a follow camera that keeps the player on screen, clamped to the combat
## arena so the view stops at the map boundary (the player can never pan past it).
func _setup_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.limit_smoothed = true
	if clamp_rect.size != Vector2.ZERO:
		cam.limit_left = int(clamp_rect.position.x)
		cam.limit_top = int(clamp_rect.position.y)
		cam.limit_right = int(clamp_rect.end.x)
		cam.limit_bottom = int(clamp_rect.end.y)
	add_child(cam)


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard handling: WASD double-tap dash + skill keys
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_A, KEY_S, KEY_D:
				_handle_dir_press(event.keycode)
			KEY_Q:
				use_bomb()
			KEY_E:
				use_grenade()


func _handle_dir_press(code: Key) -> void:
	var dir_name := ""
	match code:
		KEY_W: dir_name = "W"
		KEY_A: dir_name = "A"
		KEY_S: dir_name = "S"
		KEY_D: dir_name = "D"
	if dir_name == "":
		return

	var now: int = Time.get_ticks_msec()
	if now - int(_last_dir_press[dir_name]) < double_tap_window_ms:
		_trigger_dash(_key_dir(code))
	_last_dir_press[dir_name] = now


func _key_dir(code: Key) -> Vector2:
	match code:
		KEY_W: return Vector2.UP
		KEY_A: return Vector2.LEFT
		KEY_S: return Vector2.DOWN
		KEY_D: return Vector2.RIGHT
	return Vector2.ZERO


func _physics_process(delta: float) -> void:
	# Handle invincibility. Blinks the ship's alpha (visible invulnerability
	# feedback). Independent of the white damage-flash, which only tints the
	# ship material — so both effects coexist. Blinks FASTER as the remaining
	# invulnerability time runs out, so the player can gauge how much is left.
	if _is_invincible:
		_invincibility_timer -= delta
		if _invincibility_timer <= 0.0:
			_is_invincible = false
		var remaining: float = maxf(_invincibility_timer, 0.0)
		var frac: float = clampf(1.0 - remaining / invincibility_time, 0.0, 1.0)
		var rate: float = lerpf(4.0, 16.0, frac)
		modulate.a = 0.2 if fmod(remaining * rate, 1.0) < 0.5 else 1.0
	else:
		modulate.a = 1.0

	# Movement: dash overrides normal movement
	if _is_dashing:
		velocity = _dash_dir * dash_speed
		_dash_time -= delta
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = trail_spawn_interval
			_spawn_dash_trail()
		if _dash_time <= 0.0:
			# Dash finished: grant a temporary speed boost
			_is_dashing = false
			_boost_time = dash_boost_duration
	else:
		var move_input: Vector2 = _get_move_input()
		var spd: float = dash_boost_speed if _boost_time > 0.0 else move_speed
		if slow_sources > 0:
			spd *= PLAYER_SLOW_FACTOR
		velocity = move_input * spd
		if _boost_time > 0.0:
			_boost_time -= delta
			# Trail continues for the full duration of the dash speed boost
			_trail_timer -= delta
			if _trail_timer <= 0.0:
				_trail_timer = trail_spawn_interval
				_spawn_dash_trail()
		_detect_joystick_dash(move_input)

	move_and_slide()

	# Aim input
	var aim_dir: Vector2 = _get_aim_direction()
	if aim_dir.length() > 0.1:
		rotation = aim_dir.angle()

	# Auto-fire
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_rate
		_shoot(aim_dir)

	# Grenade cooldown tick
	if grenade_remaining > 0.0:
		grenade_remaining = max(0.0, grenade_remaining - delta)

	# Bomb recharge: reclaim one charge every `bomb_recharge_time` seconds
	if bomb_recharge_time > 0.0 and bomb_charges < total_bomb_charges:
		_bomb_recharge_timer += delta
		if _bomb_recharge_timer >= bomb_recharge_time:
			_bomb_recharge_timer = 0.0
			bomb_charges = min(total_bomb_charges, bomb_charges + 1)
			bomb_charges_changed.emit(bomb_charges)

## Clamp to screen bounds
	_clamp_to_screen()


## Seconds remaining until the next bomb charge is reclaimed (0 if not recharging).
func get_bomb_recharge_remaining() -> float:
	if bomb_recharge_time <= 0.0 or bomb_charges >= total_bomb_charges:
		return 0.0
	return max(0.0, bomb_recharge_time - _bomb_recharge_timer)


func _get_move_input() -> Vector2:
	var input := Vector2.ZERO

	# WASD keyboard input
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.y += 1.0

	# Virtual joystick input (overrides if active)
	if move_joystick and move_joystick.is_active:
		input = move_joystick.get_value()

	return input.normalized() if input.length() > 1.0 else input


func _detect_joystick_dash(input: Vector2) -> void:
	if move_joystick == null or not move_joystick.is_active:
		_joy_edge = "idle"
		return

	var mag: float = input.length()
	if mag < 0.25:
		_joy_edge = "idle"
	elif mag >= 0.6:
		if _joy_edge == "idle":
			# New activation of the stick
			_joy_edge = "active"
			var now: int = Time.get_ticks_msec()
			var dir: Vector2 = input.normalized()
			if now - _joy_last_time < double_tap_window_ms and dir.dot(_joy_last_dir) > 0.8:
				_trigger_dash(dir)
			_joy_last_time = now
			_joy_last_dir = dir


func _trigger_dash(dir: Vector2) -> void:
	if _is_dashing:
		return
	# Can't dash again while the previous dash's speed boost is still active
	if _boost_time > 0.0:
		return
	if dashes <= 0:
		return
	if dir.length() < 0.1:
		return

	dashes -= 1
	dashes_changed.emit(dashes, max_dashes)

	# Record the dash for the end-of-run scoreboard
	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.dash_uses += 1

	_play_dash_sound()

	_dash_dir = dir.normalized()
	_is_dashing = true
	_dash_time = dash_duration


## Play a random one of the four dash sounds at the player's position.
func _play_dash_sound() -> void:
	if DASH_SOUNDS.is_empty():
		return
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var stream: AudioStream = DASH_SOUNDS[randi() % DASH_SOUNDS.size()] as AudioStream
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.global_position = global_position
	sfx.volume_db = -5.0
	sfx.finished.connect(sfx.queue_free)
	container.add_child(sfx)
	sfx.play()


func refill_dashes(count: int = -1) -> void:
	# count < 0 = fully refill; otherwise add that many charges (e.g. 1 per pan)
	if count < 0:
		dashes = max_dashes
	else:
		dashes = min(max_dashes, dashes + count)
	dashes_changed.emit(dashes, max_dashes)


## Spawn a fading afterimage behind the player (the dash trail). It copies the
## ship sprite, then fades out and frees itself, so the trail appears during
## the dash and vanishes shortly after it ends.
func _spawn_dash_trail() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.global_position = global_position
	ghost.rotation = rotation
	ghost.scale = _sprite.scale
	ghost.modulate = trail_color
	ghost.z_index = -1
	_spawn_to_scene(ghost)
	var tw := create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, trail_fade_time)
	tw.tween_callback(ghost.queue_free)


func heal(amount: int) -> void:
	if health < max_health:
		# Normal heal: restore up to the current max
		health = min(max_health, health + amount)
	elif max_health < max_life_cap:
		# At full health: expand the max-health pool by 1 each pickup (up to cap)
		max_health = min(max_life_cap, max_health + 1)
		health = max_health
	health_changed.emit(health)
	_play_heal_sound()


## Play a random one of the three heal sounds at the player's position.
func _play_heal_sound() -> void:
	if HEAL_SOUNDS.is_empty():
		return
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var stream: AudioStream = HEAL_SOUNDS[randi() % HEAL_SOUNDS.size()] as AudioStream
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.global_position = global_position
	sfx.volume_db = -6.0
	sfx.finished.connect(sfx.queue_free)
	container.add_child(sfx)
	sfx.play()


func _get_aim_direction() -> Vector2:
	if aim_joystick and aim_joystick.is_active:
		return aim_joystick.get_value()

	var mouse_pos: Vector2 = get_global_mouse_position()
	return (mouse_pos - global_position).normalized()


func _shoot(direction: Vector2) -> void:
	if direction.length() < 0.01:
		direction = Vector2.UP

	if bullet_scene == null:
		return

	var bullet: Bullet = bullet_scene.instantiate() as Bullet
	bullet.global_position = global_position + direction * 24.0
	bullet.direction = direction
	_spawn_to_scene(bullet)

	_play_shoot_sound()


## Play a random one of the three shoot sounds at the player's position.
func _play_shoot_sound() -> void:
	if SHOOT_SOUNDS.is_empty():
		return
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var stream: AudioStream = SHOOT_SOUNDS[randi() % SHOOT_SOUNDS.size()] as AudioStream
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.global_position = global_position
	sfx.volume_db = -8.0
	sfx.finished.connect(sfx.queue_free)
	container.add_child(sfx)
	sfx.play()


func take_damage(amount: int = 1) -> void:
	if _is_invincible or _is_dashing:
		return

	health -= amount
	health_changed.emit(health)
	_flash_hit()

	# Record damage taken for the end-of-run scoreboard
	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.damage_taken += amount

	if health <= 0:
		player_died.emit()
		queue_free()
	else:
		_is_invincible = true
		_invincibility_timer = invincibility_time


## Flash the ship white for a brief moment when it takes damage.
func _flash_hit() -> void:
	if _sprite == null:
		return
	var mat := _sprite.material as ShaderMaterial
	if mat == null or mat.shader != FLASH_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = FLASH_SHADER
		_sprite.material = mat
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	mat.set_shader_parameter("flash", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(mat, "shader_parameter/flash", 0.0, 0.15)


func use_bomb() -> void:
	if bomb_charges <= 0:
		return
	bomb_charges -= 1
	bomb_charges_changed.emit(bomb_charges)

	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.bombs_used += 1
		gm.clear_enemies()

	# Spawn the expanding shockwave ring at the player
	if ring_scene:
		var ring: ExpandingRing = ring_scene.instantiate() as ExpandingRing
		ring.global_position = global_position
		_spawn_to_scene(ring)

	# Spawn the "water drop" screen distortion
	_spawn_water_distortion()

	_play_bomb_sound()


## Play the bomb blast sound at the player's position.
func _play_bomb_sound() -> void:
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = BOMB_SOUND
	sfx.global_position = global_position
	sfx.volume_db = -3.0
	sfx.finished.connect(sfx.queue_free)
	container.add_child(sfx)
	sfx.play()


## Spawn the "water drop" screen distortion, emanating from the player's position.
func _spawn_water_distortion() -> void:
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var wd: WaterDistortion = WATER_DISTORTION_SCENE.instantiate() as WaterDistortion
	wd.center_world = global_position
	container.add_child(wd)


func use_grenade() -> void:
	if grenade_remaining > 0.0 or grenade_scene == null:
		return
	if not get_tree().current_scene:
		return

	grenade_remaining = grenade_cooldown

	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		gm.grenades_thrown += 1

	var aim_dir: Vector2 = _get_aim_direction()
	if aim_dir.length() < 0.1:
		aim_dir = Vector2.UP

	var grenade: Grenade = grenade_scene.instantiate() as Grenade
	grenade.global_position = global_position
	grenade.direction = aim_dir
	_spawn_to_scene(grenade)

	_play_grenade_sound()


## Play the grenade throw sound at the player's position.
func _play_grenade_sound() -> void:
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = GRENADE_SOUND
	sfx.global_position = global_position
	sfx.volume_db = -3.0
	sfx.finished.connect(sfx.queue_free)
	container.add_child(sfx)
	sfx.play()


## Add a node to a stable scene container (game manager or current scene).
func _spawn_to_scene(node: Node) -> void:
	if node == null:
		return
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container:
		container.add_child(node)
	else:
		# Last resort: parent to this player
		node.queue_free()


func _clamp_to_screen() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = 16.0
	# Clamp within the combat arena when one is set, otherwise the full screen.
	var area: Rect2 = clamp_rect
	if area.size == Vector2.ZERO:
		area = Rect2(0, 0, viewport_size.x, viewport_size.y)
	global_position = global_position.clamp(
		area.position + Vector2(margin, margin),
		area.position + area.size - Vector2(margin, margin)
	)
