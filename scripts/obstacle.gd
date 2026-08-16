class_name Obstacle extends StaticBody2D
# Drifting cover obstacle. Blocks player and enemy movement.
# Enemies can break it by ramming it: each ram deals take_hit() damage, and
# when its (player-invisible) HP reaches 0 the obstacle breaks and is freed.
# NOTE: Kept as a StaticBody2D (moved via translation) because using a
# kinematic body here caused a physics-solver deadlock when enemies rammed it.

## Base drift speed (px/s)
@export var drift_speed: float = 30.0
## Approximate seconds between random direction changes
@export var change_interval: float = 2.0

## Hits required to break this obstacle. Not shown to the player.
@export var max_hp: int = 2

## If true, this obstacle never drifts (used for the fixed arena boundary wall).
@export var stationary: bool = false

## If true, this obstacle cannot be damaged/broken by enemy ramming
## (used for the indestructible arena boundary wall).
var indestructible: bool = false

## Explosion effect shown when the obstacle is destroyed
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

## Current HP (invisible)
var hp: int = 2

var _timer: float = 0.0
var _dir: Vector2 = Vector2.ZERO
var _rot_speed: float = 0.0

## True while this obstacle was just spawned off-screen and is flying in
var _entering: bool = false


func _ready() -> void:
	hp = max_hp
	_pick_new_direction()
	_rot_speed = randf_range(-0.6, 0.6)


## Make this obstacle fly in from off-screen toward a given direction.
func set_incoming(enter_dir: Vector2) -> void:
	_dir = enter_dir.normalized()
	_timer = 0.0
	_entering = true


## Deal damage (from an enemy ram). Breaks and frees when HP runs out.
func take_hit(amount: int = 1) -> void:
	# The arena boundary wall is indestructible: enemy ram damage does nothing.
	if indestructible:
		return
	hp -= amount
	if hp <= 0:
		_spawn_destroy_explosion()
		queue_free()


## The world-space rectangle currently visible on screen (camera-relative in
## world coordinates), so obstacles steer toward where the player can see them.
func _view_rect() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(Vector2.ZERO, vs)
	return Rect2(cam.get_screen_center_position() - vs * 0.5, vs)


## Spawn a rock/stone-colored particle burst where the obstacle breaks apart.
func _spawn_destroy_explosion() -> void:
	var container: Node = get_tree().get_first_node_in_group("game_manager")
	if container == null:
		container = get_tree().current_scene
	if container == null:
		return
	var boom: Explosion = EXPLOSION_SCENE.instantiate() as Explosion
	boom.global_position = global_position
	boom.particle_count = 14
	boom.scatter = 40.0
	boom.particle_scale = 1.2
	boom.particle_color = Color(0.55, 0.55, 0.6)
	container.add_child(boom)


func _physics_process(delta: float) -> void:
	# Boundary wall obstacles are fixed in place (no drifting, no rotation).
	if stationary:
		return

	# Stop drifting once the player is dead (game over)
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return

	var view: Rect2 = _view_rect()

	# Entering obstacle: head inward at a brisk pace until inside the arena
	if _entering:
		global_position += _dir * drift_speed * 2.5 * delta
		var pad_e: float = 60.0
		if global_position.x > view.position.x + pad_e and global_position.x < view.end.x - pad_e and \
		   global_position.y > view.position.y + pad_e and global_position.y < view.end.y - pad_e:
			_entering = false
			_pick_new_direction()
		rotation += _rot_speed * delta
		return

	_timer -= delta
	if _timer <= 0.0:
		_pick_new_direction()

	# Softly steer back into the arena near the visible edges
	var margin: float = 40.0
	var steer := Vector2.ZERO
	if global_position.x < view.position.x + margin:
		steer.x = 1.0
	elif global_position.x > view.end.x - margin:
		steer.x = -1.0
	if global_position.y < view.position.y + margin:
		steer.y = 1.0
	elif global_position.y > view.end.y - margin:
		steer.y = -1.0

	var dir: Vector2 = _dir
	if steer.length() > 0.0:
		dir = dir.lerp(steer.normalized(), 0.2).normalized()

	global_position += dir * drift_speed * delta
	rotation += _rot_speed * delta


func _pick_new_direction() -> void:
	_timer = randf_range(change_interval * 0.5, change_interval * 1.5)
	_dir = Vector2.from_angle(randf_range(0.0, TAU))
