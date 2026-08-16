class_name GameManager extends Node

## Sound played when the boss appears
const BOSS_SPAWN_SOUND := preload("res://assets/Audios/boss_spawn.wav")

## Explosion effect shown when the bomb vaporizes enemies
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")

## Border texture stretched over the combat arena (the arena boundary)
const LIMIT_TEXTURE := preload("res://assets/limit.png")

## How many times bigger than the screen the combat arena is (per axis). The
## player can roam a large area; the boundary wall sits far off-screen.
@export var arena_scale: float = 2.5
## The player-allowed combat rectangle (centered on screen), computed at startup
var combat_rect := Rect2()

## Parallax background script, attached to a Background node created at startup
const BACKGROUND_SCRIPT := preload("res://scripts/background.gd")
## Reference to the parallax background node
var _background: Node = null

## Reference to the player scene for respawning
@export var player_scene: PackedScene

## Reference to the enemy scene
@export var enemy_scene: PackedScene

## Reference to the obstacle scene
@export var obstacle_scene: PackedScene

## Reference to the item (pickup) scene
@export var item_scene: PackedScene

## Reference to the boss scene
@export var boss_scene: PackedScene

## Score at which the boss warning sequence triggers
@export var boss_threshold: int = 7000
## How long the warning + darkening lasts before the boss spawns (seconds)
@export var boss_sequence_duration: float = 5.0

## Number of obstacle cover blocks to spawn
@export var obstacle_count: int = 8

## Extra breakable cover obstacles scattered across the WHOLE arena at startup,
## so the map is populated even far outside the starting area. They stay fixed
## in place (stationary) and are separate from the ~8 view-following obstacles.
@export var scatter_obstacle_count: int = 45

## Seconds between respawning a broken obstacle (flies in from off-screen)
@export var obstacle_respawn_interval: float = 1.5

## How often (seconds) a rare healing item may spawn
@export var heal_spawn_interval: float = 25.0

## Seconds between enemy spawns
@export var spawn_interval: float = 2.0

## Minimum spawn interval (gets faster over time)
@export var min_spawn_interval: float = 0.5

## How much spawn rate increases per second
@export var spawn_rate_increase: float = 0.02

## Maximum enemies on screen at once
@export var max_enemies: int = 15

## Initial spawn interval
var _current_spawn_interval: float = 2.0

## Spawn timer
var _spawn_timer: float = 0.0

## Heal item spawn timer
var _heal_timer: float = 0.0

## Obstacle replenishment timer
var _obstacle_respawn_timer: float = 0.0

## Game time elapsed
var _game_time: float = 0.0

## Current score
var score: int = 0

## ---------- Run stats (shown on the end-of-run scoreboard) ----------
## Total enemies killed by the player (bullets, bomb, boss-defeat explosion)
var enemies_killed: int = 0
## Total number of times the player dashed
var dash_uses: int = 0
## Total health lost to damage
var damage_taken: int = 0
## Total number of bombs used
var bombs_used: int = 0
## Total number of grenades thrown
var grenades_thrown: int = 0
## Longest kill-streak (max combo) reached during the run
var max_combo: int = 0
## Current active kill streak
var _current_combo: int = 0
## Timer that resets the kill streak once it expires
var _combo_timer: SceneTreeTimer = null
## Seconds a kill must follow the previous one to keep the streak alive
const COMBO_WINDOW := 2.5

## Seconds between automatic checkpoints (so "Continue" always has a recent save)
@export var save_interval: float = 15.0
## Countdown to the next automatic save
var _save_timer: float = 0.0


## Register one enemy kill: bump the counter and update the kill streak.
func register_enemy_killed() -> void:
	enemies_killed += 1
	_current_combo += 1
	if _current_combo > max_combo:
		max_combo = _current_combo
	if _combo_timer:
		_combo_timer.timeout.disconnect(_reset_combo)
	_combo_timer = get_tree().create_timer(COMBO_WINDOW)
	_combo_timer.timeout.connect(_reset_combo)


func _reset_combo() -> void:
	_current_combo = 0
	_combo_timer = null


## The persistent music autoload (survives scene changes), or null if unavailable.
func _music() -> Music:
	return get_node_or_null("/root/MusicPlayer") as Music


## Is the game over
var is_game_over: bool = false

## Player reference
var player: Player = null

## Boss-state flags
var _boss_sequence: bool = false
var _boss_active: bool = false
var _boss: Boss = null
## True during the brief boss-defeat cinematic, to keep spawning paused
var _boss_defeat: bool = false
## Score threshold to next boss fight (advanced each time one is beaten)
var _next_boss_threshold: int = 7000

## Maximum heal pickups the boss fight can produce (from boss-spawned enemies)
@export var boss_heal_cap: int = 10
## Heal drops already produced during the current boss fight
var _boss_heal_drops: int = 0

## Signals
signal score_changed(new_score: int)
signal game_over(final_score: int)
signal player_spawned(player: Player)


func _ready() -> void:
	add_to_group("game_manager")
	# Keep the HUD in screen space (a CanvasLayer) so it stays aligned to the
	# view and follows the player, instead of scrolling around the world with
	# the panning camera.
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	add_child(hud_layer)
	var hud_node: Node = get_node_or_null("HUD")
	if hud_node:
		hud_node.reparent(hud_layer)
	# Crossfade to the gameplay theme (the menu theme is playing in the main menu)
	var m := _music()
	if m:
		m.play_game_music()
	# Create the parallax scrolling background (drawn behind everything)
	_background = BACKGROUND_SCRIPT.new()
	_background.name = "Background"
	add_child(_background)
	_current_spawn_interval = spawn_interval
	_heal_timer = heal_spawn_interval
	_save_timer = save_interval
	# Combat arena: a large, centered rectangle the player is kept inside. It is
	# several times the screen size, so its boundary sits far off-screen.
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var arena: Vector2 = vs * arena_scale
	combat_rect = Rect2(vs * 0.5 - arena * 0.5, arena)
	_setup_boundary()
	_spawn_player()
	_spawn_obstacles()
	_scatter_arena_obstacles()

	# If the main menu asked us to continue a saved run, restore its full state.
	if SaveSystem.pending_resume and SaveSystem.has_save():
		SaveSystem.pending_resume = false
		_restore_run(SaveSystem.read_save())


func _process(delta: float) -> void:
	if is_game_over:
		return

	# During the boss warning sequence, the boss fight, or the brief boss-defeat
	# cinematic, normal spawning and obstacle replenishment are paused.
	if _boss_sequence or _boss_active or _boss_defeat:
		return

	_game_time += delta

	# Autosave a checkpoint periodically so "Continue" can resume an in-progress run.
	_save_timer -= delta
	if _save_timer <= 0.0:
		_save_timer = save_interval
		SaveSystem.save_run(self)

	# Gradually decrease spawn interval
	_current_spawn_interval = max(min_spawn_interval, spawn_interval - _game_time * spawn_rate_increase)

	# Spawn enemies
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _current_spawn_interval
		_try_spawn_enemy()

	# Spawn a rare healing item
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_heal_timer = heal_spawn_interval
		_spawn_heal_item()

	# Replenish obstacles broken by enemies: keep the view-following pool topped
	# up, with new ones flying in from off-screen. Triggers when the pool has
	# fewer than the target or whenever the count drops (always at least a
	# couple). The scattered arena cover is excluded so it doesn't keep the pool
	# permanently full and stop replenishment.
	_obstacle_respawn_timer -= delta
	if _obstacle_respawn_timer <= 0.0:
		_obstacle_respawn_timer = obstacle_respawn_interval
		var obs_count: int = 0
		for n in get_tree().get_nodes_in_group("obstacle"):
			if is_instance_valid(n) and not n.is_in_group("scatter_obstacle"):
				obs_count += 1
		if obs_count < obstacle_count:
			_spawn_incoming_obstacle()


## Build the combat-arena boundary: a nearest-filtered limit.png border stretched
## over the arena, plus a fixed physical wall of stationary, indestructible
## obstacles around the edge that keeps the player (and enemies) inside.
func _setup_boundary() -> void:
	if obstacle_scene == null or LIMIT_TEXTURE == null:
		return

	var boundary := Node2D.new()
	boundary.name = "Boundary"
	boundary.z_index = -40
	add_child(boundary)

	# Border texture (limit.png) stretched to cover the whole arena, nearest-filtered
	var border := Sprite2D.new()
	border.name = "Border"
	border.texture = LIMIT_TEXTURE
	border.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Draw the border OVER the world content (player, enemies, obstacles) so it
	# acts as a visible arena frame that overlays anything touching the edge.
	# The HUD lives on a CanvasLayer, which always renders above this, so the
	# border never covers the HUD.
	border.z_index = 100
	border.position = combat_rect.get_center()
	var bz: Vector2 = LIMIT_TEXTURE.get_size()
	border.scale = Vector2(combat_rect.size.x / bz.x, combat_rect.size.y / bz.y)
	boundary.add_child(border)

	# Physical wall: a ring of stationary, indestructible obstacles just outside
	# the arena edge (40px squares, so centers are placed every 40px).
	var half := 20.0
	for y in range(int(combat_rect.position.y), int(combat_rect.end.y) + 1, 40):
		_spawn_wall_obstacle(boundary, Vector2(combat_rect.position.x - half, y))
		_spawn_wall_obstacle(boundary, Vector2(combat_rect.end.x + half, y))
	for x in range(int(combat_rect.position.x), int(combat_rect.end.x) + 1, 40):
		_spawn_wall_obstacle(boundary, Vector2(x, combat_rect.position.y - half))
		_spawn_wall_obstacle(boundary, Vector2(x, combat_rect.end.y + half))


## Create one stationary, indestructible boundary obstacle under `boundary`.
## It lives on its own collision layer (4) so it only ever blocks the player,
## while enemies (and the boss) can pass straight through it — this lets enemies
## that spawn outside the arena wall fly in to reach the player.
func _spawn_wall_obstacle(boundary: Node2D, pos: Vector2) -> void:
	var ob: Obstacle = obstacle_scene.instantiate() as Obstacle
	ob.position = pos
	ob.collision_layer = 8  # layer 4: wall only; enemies mask 1+2, player masks 1+2+4
	ob.collision_mask = 0
	ob.stationary = true
	ob.indestructible = true
	ob.max_hp = 999
	ob.hp = 999
	boundary.add_child(ob)


func _spawn_player() -> void:
	if player_scene == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	player = player_scene.instantiate() as Player
	player.global_position = viewport_size * 0.5
	player.clamp_rect = combat_rect
	player.add_to_group("player")
	player.player_died.connect(_on_player_died)
	add_child(player)
	player_spawned.emit(player)

	# Connect virtual joysticks (deferred to ensure HUD is ready)
	call_deferred("_assign_virtual_joysticks")


func _assign_virtual_joysticks() -> void:
	var move_joy: TouchJoystick = get_node_or_null("HUDLayer/HUD/MoveJoystick") as TouchJoystick
	var aim_joy: TouchJoystick = get_node_or_null("HUDLayer/HUD/AimJoystick") as TouchJoystick

	if player:
		player.move_joystick = move_joy
		player.aim_joystick = aim_joy

	# Show/hide based on touch capability
	var has_touch: bool = DisplayServer.is_touchscreen_available()
	if move_joy:
		move_joy.visible = has_touch
	if aim_joy:
		aim_joy.visible = has_touch


func _try_spawn_enemy() -> void:
	if enemy_scene == null:
		return

	# Count existing enemies
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	if enemies.size() >= max_enemies:
		return

	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	enemy.global_position = _get_spawn_position()
	enemy.add_to_group("enemy")
	add_child(enemy)


## Spawn a large wave of standard enemies, each from just off a visible screen
## edge (camera-relative). Used by the boss on enrage to flood the arena.
func spawn_enemy_wave(count: int) -> void:
	if enemy_scene == null:
		return
	for i in range(count):
		var enemy: Enemy = enemy_scene.instantiate() as Enemy
		enemy.global_position = _get_spawn_position()
		enemy.add_to_group("enemy")
		add_child(enemy)


## Fly a number of fresh breakable-cover obstacles in from off-screen. Used by
## the boss on enrage to introduce new cover into the arena.
func introduce_obstacles(count: int) -> void:
	for i in range(count):
		_spawn_incoming_obstacle()


## Return `count` positions just like the normal enemy spawn points (off the
## visible screen edges). Used by the boss to deploy its enrage machine gun
## right where enemies charge in from.
func get_enemy_spawn_positions(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(count):
		out.append(_get_spawn_position())
	return out


## The world-space rectangle currently visible on screen (camera-relative).
## Used so spawned objects (enemies, items, obstacles) appear at/around what
## the player can actually see, regardless of where the camera has panned.
func _view_rect() -> Rect2:
	var vs := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(Vector2.ZERO, vs)
	return Rect2(cam.get_screen_center_position() - vs * 0.5, vs)


func _get_spawn_position() -> Vector2:
	# Spawn just off the visible screen edge (camera-relative). The arena is far
	# larger than the screen, so the boundary wall is well beyond these spawns
	# and never traps enemies.
	var view: Rect2 = _view_rect()
	var margin: float = 50.0

	# Pick a random edge: 0=top, 1=right, 2=bottom, 3=left
	var edge: int = randi() % 4
	match edge:
		0:  # Top
			return Vector2(randf_range(view.position.x + margin, view.end.x - margin), view.position.y - margin)
		1:  # Right
			return Vector2(view.end.x + margin, randf_range(view.position.y + margin, view.end.y - margin))
		2:  # Bottom
			return Vector2(randf_range(view.position.x + margin, view.end.x - margin), view.end.y + margin)
		_:  # Left
			return Vector2(view.position.x - margin, randf_range(view.position.y + margin, view.end.y - margin))


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
	_check_boss_trigger()


## Start the boss encounter once the score reaches the current threshold.
func _check_boss_trigger() -> void:
	if is_game_over or _boss_sequence or _boss_active:
		return
	if score >= _next_boss_threshold:
		_start_boss_sequence()


## Clear the arena, show the warning + darkening, then spawn the boss.
func _start_boss_sequence() -> void:
	_boss_sequence = true

	# Remove all obstacles and enemies so the arena is clear for the boss
	for node in get_tree().get_nodes_in_group("obstacle"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(node):
			node.queue_free()

	var hud: Control = get_node_or_null("HUDLayer/HUD") as Control
	if hud and hud.has_method("start_boss_warning"):
		hud.start_boss_warning(boss_sequence_duration)

	get_tree().create_timer(boss_sequence_duration).timeout.connect(
		_finish_boss_sequence, CONNECT_ONE_SHOT)


func _finish_boss_sequence() -> void:
	_boss_sequence = false
	if boss_scene == null:
		return

	var view: Rect2 = _view_rect()
	_boss = boss_scene.instantiate() as Boss
	_boss.global_position = Vector2(view.get_center().x, view.position.y - 250.0)
	_boss.health_changed.connect(_on_boss_health)
	_boss.died.connect(_on_boss_died)
	add_child(_boss)
	_boss_active = true
	# Fresh heal budget for this boss fight
	_boss_heal_drops = 0

	_play_boss_spawn_sound()
	# Fade the normal music out and switch to the boss theme
	var m := _music()
	if m:
		m.play_boss_music()

	var hud: Control = get_node_or_null("HUDLayer/HUD") as Control
	if hud and hud.has_method("on_boss_spawned"):
		hud.on_boss_spawned(_boss)


## Play the boss entrance sound (a global one-shot, auto-frees when done).
func _play_boss_spawn_sound() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = BOSS_SPAWN_SOUND
	sfx.volume_db = -3.0
	sfx.finished.connect(sfx.queue_free)
	add_child(sfx)
	sfx.play()


func _on_boss_health(hp: int, max_hp: int) -> void:
	var hud: Control = get_node_or_null("HUDLayer/HUD") as Control
	if hud and hud.has_method("set_boss_health"):
		hud.set_boss_health(hp, max_hp)


func _on_boss_died() -> void:
	if _boss:
		score += _boss.score_value
		score_changed.emit(score)
	_boss = null
	_boss_active = false
	_boss_defeat = true

	# Explode every remaining enemy on screen as the boss is destroyed
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node):
			_spawn_bomb_kill_explosion(node.global_position)
			node.queue_free()
			register_enemy_killed()

	_next_boss_threshold = score + boss_threshold

	# Wait a few seconds so the boss + enemy explosions play out, then show the
	# level-complete screen and freeze the game.
	get_tree().create_timer(BOSS_DEFEAT_DELAY).timeout.connect(
		_show_level_complete, CONNECT_ONE_SHOT)


## Show the level-complete screen and freeze the game until the player chooses
## an option. Called after the boss-defeat explosion plays out.
func _show_level_complete() -> void:
	_show_scoreboard()
	var hud: Control = get_node_or_null("HUDLayer/HUD") as Control
	if hud and hud.has_method("show_level_complete"):
		hud.show_level_complete()
	# Freeze the game until the player picks an option (Play Again / Continue).
	get_tree().paused = true


## "Continue to infinity": resume endless play (obstacles respawn, spawning
## resumes) and allow another boss fight at the next score threshold.
func continue_game() -> void:
	_boss_defeat = false
	get_tree().paused = false
	var hud: Control = get_node_or_null("HUDLayer/HUD") as Control
	if hud and hud.has_method("hide_level_complete"):
		hud.hide_level_complete()
	_spawn_obstacles()
	_scatter_arena_obstacles()
	_spawn_timer = 0.0


func _spawn_obstacles() -> void:
	if obstacle_scene == null:
		return

	for i in range(obstacle_count):
		var ob: Obstacle = obstacle_scene.instantiate() as Obstacle
		var s: float = randf_range(0.7, 2.2)
		ob.scale = Vector2(s, s)
		ob.global_position = _get_obstacle_position()
		ob.add_to_group("obstacle")
		add_child(ob)


## Scatter fixed, breakable cover obstacles across the WHOLE combat arena so the
## map is populated even far outside the starting area. They are stationary
## (they stay put as terrain cover, unlike the drifting view-following pool),
## are broken by enemy ramming, and are kept in a separate "scatter_obstacle"
## group so they don't interfere with the ~8 view-following obstacles.
func _scatter_arena_obstacles() -> void:
	if obstacle_scene == null or combat_rect.size == Vector2.ZERO:
		return
	var rect := combat_rect
	var margin: float = 110.0  # keep them well inside the boundary wall
	var center := rect.get_center()
	var placed: int = 0
	var tries: int = 0
	while placed < scatter_obstacle_count and tries < scatter_obstacle_count * 10:
		tries += 1
		var pos := Vector2(
			randf_range(rect.position.x + margin, rect.end.x - margin),
			randf_range(rect.position.y + margin, rect.end.y - margin)
		)
		# Keep the player's spawn area clear
		if pos.distance_to(center) < 240.0:
			continue
		var ob: Obstacle = obstacle_scene.instantiate() as Obstacle
		var s: float = randf_range(0.7, 1.8)
		ob.scale = Vector2(s, s)
		ob.position = pos
		ob.stationary = true  # fixed map cover, no drifting
		ob.max_hp = 3         # breakable by enemy ramming
		ob.add_to_group("obstacle")
		ob.add_to_group("scatter_obstacle")
		add_child(ob)
		placed += 1


## Spawn a replacement obstacle off-screen and have it fly into the arena
func _spawn_incoming_obstacle() -> void:
	if obstacle_scene == null:
		return
	var ob: Obstacle = obstacle_scene.instantiate() as Obstacle
	var s: float = randf_range(0.7, 2.2)
	ob.scale = Vector2(s, s)
	var view: Rect2 = _view_rect()
	var pos: Vector2 = _get_incoming_obstacle_position()
	ob.global_position = pos
	var center: Vector2 = view.get_center()
	ob.set_incoming((center - pos).normalized())
	ob.add_to_group("obstacle")
	add_child(ob)


## Return a random point just outside one of the four visible screen edges
func _get_incoming_obstacle_position() -> Vector2:
	var r: Rect2 = _view_rect()
	var edge: int = randi() % 4
	var off: float = randf_range(60.0, 140.0)
	match edge:
		0:  # Top
			return Vector2(randf_range(r.position.x, r.end.x), r.position.y - off)
		1:  # Right
			return Vector2(r.end.x + off, randf_range(r.position.y, r.end.y))
		2:  # Bottom
			return Vector2(randf_range(r.position.x, r.end.x), r.end.y + off)
		_:  # Left
			return Vector2(r.position.x - off, randf_range(r.position.y, r.end.y))


## Pick a position that avoids the player spawn area and the bottom-right HUD buttons
func _get_obstacle_position() -> Vector2:
	var r: Rect2 = _view_rect()
	for attempt in range(20):
		var pos := Vector2(
			randf_range(r.position.x + 90.0, r.end.x - 90.0),
			randf_range(r.position.y + 90.0, r.end.y - 90.0)
		)
		# Avoid the center area (player spawn)
		if pos.distance_to(r.get_center()) < 130.0:
			continue
		# Avoid the bottom-right HUD button area
		if pos.x > r.end.x - 320.0 and pos.y > r.end.y - 220.0:
			continue
		return pos
	return r.position + Vector2(150.0, 150.0)


## Spawn a heal dropped by a boss-spawned enemy, but only up to `boss_heal_cap`
## picks during the boss fight (so healing doesn't pile up endlessly).
func spawn_boss_minion_heal(pos: Vector2) -> void:
	if _boss_heal_drops >= boss_heal_cap:
		return
	_boss_heal_drops += 1
	spawn_item(Item.ItemType.HEAL, pos)


func spawn_item(item_type: int, pos: Vector2) -> void:
	if item_scene == null:
		return

	var it: Item = item_scene.instantiate() as Item
	it.item_type = item_type
	it.global_position = pos
	# Deferred add_child because this can be called from a collision callback
	call_deferred("_finish_spawn_item", it)


func _finish_spawn_item(it: Item) -> void:
	if is_instance_valid(it):
		add_child(it)


func _spawn_heal_item() -> void:
	# Limit how many healing items can exist at once
	var existing: Array = get_tree().get_nodes_in_group("heal_item")
	if existing.size() >= 2:
		return

	var r: Rect2 = _view_rect()
	var pos := Vector2(
		randf_range(r.position.x + 80.0, r.end.x - 80.0),
		randf_range(r.position.y + 80.0, r.end.y - 80.0)
	)
	var it: Item = item_scene.instantiate() as Item
	it.item_type = Item.ItemType.HEAL
	it.global_position = pos
	it.add_to_group("heal_item")
	add_child(it)


func clear_enemies() -> void:
	# Free all enemies (bomb effect). Give each a bigger "vaporized by bomb" burst.
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if is_instance_valid(e):
			_spawn_bomb_kill_explosion(e.global_position)
			e.queue_free()
			register_enemy_killed()

	# The bomb also wipes out enemy projectiles (boss bullets / machine-gun fire)
	var projectiles: Array = get_tree().get_nodes_in_group("enemy_projectile")
	for b in projectiles:
		if is_instance_valid(b):
			b.queue_free()

	# The bomb also stuns the boss for a short time (cannot move or attack)
	var bosses: Array = get_tree().get_nodes_in_group("boss")
	var has_boss: bool = false
	for b in bosses:
		if b is Boss and is_instance_valid(b):
			(b as Boss).stun(BOSS_STUN_DURATION)
			has_boss = true

	# The stun warning only appears when the boss is actually present
	if has_boss:
		var hud: Control = get_node_or_null("HUDLayer/HUD") as Control
		if hud and hud.has_method("show_boss_stunned"):
			hud.show_boss_stunned(BOSS_STUN_DURATION)


## Spawn a larger, denser explosion where the bomb vaporized an enemy.
func _spawn_bomb_kill_explosion(pos: Vector2) -> void:
	var boom: Explosion = EXPLOSION_SCENE.instantiate() as Explosion
	boom.global_position = pos
	boom.particle_count = 42
	boom.scatter = 90.0
	boom.particle_lifetime = 0.7
	boom.particle_scale = 1.2
	boom.particle_color = Color(1.0, 0.7, 0.2)
	add_child(boom)


## How long the bomb's effect stuns the boss (seconds)
const BOSS_STUN_DURATION := 5.0

## Seconds to wait after the boss dies (while the explosion plays) before showing
## the level-complete screen and freezing the game.
const BOSS_DEFEAT_DELAY := 3.0


func _on_player_died() -> void:
	is_game_over = true
	game_over.emit(score)

	# The run is over - discard the checkpoint so "Continue" is disabled.
	SaveSystem.clear_save()

	# Show game over screen after a short delay
	get_tree().create_timer(2.0).timeout.connect(_show_game_over)


## Populate and show the end-of-run scoreboard with the collected run stats.
func _show_scoreboard() -> void:
	var hud: Control = get_node_or_null("HUDLayer/HUD") as Control
	if hud and hud.has_method("show_scoreboard"):
		hud.show_scoreboard(score, enemies_killed, dash_uses, damage_taken,
			bombs_used, grenades_thrown, max_combo, _game_time)


func _show_game_over() -> void:
	_show_scoreboard()
	var hud: Control = get_node_or_null("HUDLayer/HUD") as Control
	if hud:
		var game_over_label: Label = hud.get_node_or_null("GameOverLabel") as Label
		if game_over_label:
			game_over_label.visible = true

		var restart_button: Button = hud.get_node_or_null("RestartButton") as Button
		if restart_button:
			restart_button.visible = true


## Pressing ESC toggles the in-game pause menu (which also offers "Save & Menu").
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle_pause()


## Open/close the in-game pause menu.
func toggle_pause() -> void:
	if is_game_over or _boss_defeat or _boss_sequence:
		return
	var paused: bool = not get_tree().paused
	get_tree().paused = paused
	var hud: Control = get_node_or_null("HUDLayer/HUD") as Control
	if hud and hud.has_method("set_paused"):
		hud.set_paused(paused)


## Save the current run to disk (used by the pause menu's "Save & Menu").
func save_current_run() -> void:
	SaveSystem.save_run(self)


## Save the run and return to the main menu (from the pause menu).
func save_and_quit_to_menu() -> void:
	SaveSystem.save_run(self)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


## Restore the full state of a saved run (score, stats, player, boss).
func _restore_run(data: Dictionary) -> void:
	if data.is_empty():
		return
	score = int(data.get("run_score", 0))
	enemies_killed = int(data.get("run_enemies_killed", 0))
	dash_uses = int(data.get("run_dash_uses", 0))
	damage_taken = int(data.get("run_damage_taken", 0))
	bombs_used = int(data.get("run_bombs_used", 0))
	grenades_thrown = int(data.get("run_grenades_thrown", 0))
	max_combo = int(data.get("run_max_combo", 0))
	_game_time = float(data.get("run_game_time", 0.0))
	_next_boss_threshold = int(data.get("run_next_boss_threshold", boss_threshold))

	if player:
		player.global_position = Vector2(
			float(data.get("player_pos_x", player.global_position.x)),
			float(data.get("player_pos_y", player.global_position.y)))
		player.rotation = float(data.get("player_rotation", 0.0))
		player.max_health = maxi(1, int(data.get("player_max_health", player.max_health)))
		player.health = clampi(int(data.get("player_health", player.max_health)), 0, player.max_health)
		player.max_dashes = maxi(1, int(data.get("player_max_dashes", player.max_dashes)))
		player.dashes = clampi(int(data.get("player_dashes", player.max_dashes)), 0, player.max_dashes)
		player.bomb_charges = clampi(int(data.get("player_bomb_charges", player.bomb_charges)), 0, player.total_bomb_charges)
		player.grenade_remaining = float(data.get("player_grenade_remaining", 0.0))
		player.grenade_cooldown = float(data.get("player_grenade_cooldown", player.grenade_cooldown))

	# Re-engage the boss fight if one was in progress when the run was saved.
	if bool(data.get("boss_active", false)):
		_restore_boss(int(data.get("boss_health", 240)), bool(data.get("boss_enraged", false)))

	# Refresh the HUD once its deferred signal binding has run (this deferred call
	# is enqueued after HUD._setup schedules its own, so it runs afterwards).
	call_deferred("_refresh_resumed_ui")


## Bring a saved boss fight back to life (the boss re-engages from mid-fight).
func _restore_boss(health_left: int, enraged: bool) -> void:
	if boss_scene == null:
		return
	var center: Vector2 = player.global_position if player else Vector2(640.0, 360.0)
	_boss = boss_scene.instantiate() as Boss
	_boss.global_position = center + Vector2(0, -250.0)
	_boss.health_changed.connect(_on_boss_health)
	_boss.died.connect(_on_boss_died)
	add_child(_boss)
	_boss.health = clampi(health_left, 1, _boss.max_health)
	_boss._enraged = enraged
	_boss_active = true
	_boss_heal_drops = 0
	var m := _music()
	if m:
		m.play_boss_music()

	var hud: Control = get_node_or_null("HUDLayer/HUD") as Control
	if hud and hud.has_method("on_boss_spawned"):
		hud.on_boss_spawned(_boss)
	else:
		_boss.health_changed.emit(_boss.health, _boss.max_health)


## Push the restored state into the HUD (called after it has bound its signals).
func _refresh_resumed_ui() -> void:
	score_changed.emit(score)
	var hp: Player = player
	if hp:
		hp.dashes_changed.emit(hp.dashes, hp.max_dashes)
		hp.bomb_charges_changed.emit(hp.bomb_charges)
		hp.health_changed.emit(hp.health)


func restart_game() -> void:
	SaveSystem.pending_resume = false
	SaveSystem.clear_save()
	get_tree().paused = false
	get_tree().reload_current_scene()
