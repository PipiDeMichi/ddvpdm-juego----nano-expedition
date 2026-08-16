class_name PlayerSlowZone extends Area2D
# Zone created by the boss's slow bomb. Slows the player while they stand in it.

## Speed multiplier applied to the player while inside
@export var slow_factor: float = 0.45
## How long the zone lasts (seconds)
@export var duration: float = 5.0
## Starting radius of the slow zone (also drawn visually)
@export var radius: float = 63.0
## How long (s) the zone takes to expand to its final size
@export var grow_time: float = 0.8
## Final radius the zone expands to (normal)
@export var final_radius: float = 120.0
## Final radius when enlarged (boss enraged)
@export var enlarged_final_radius: float = 200.0
## How fast the zone drifts toward the player (px/s)
@export var drift_speed: float = 70.0

## Set true (boss enraged) to make the zone grow larger toward the player
var enlarged: bool = false

## How fast the zone's visual spins (rad/s) while the area exists
@export var spin_speed: float = 0.9
## How long (s) the visual fades out over near the end of its life
@export var fade_time: float = 0.6

var _current_radius: float = 0.0
var _final_radius: float = 0.0
## Total time the zone has existed (for fade-out timing)
var _life: float = 0.0


func _ready() -> void:
	# Render the zone below the boss/enemies so it doesn't cover the sprites
	z_index = -1
	_current_radius = radius
	_final_radius = enlarged_final_radius if enlarged else final_radius
	_apply_radius()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	get_tree().create_timer(duration).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	_life += delta

	# Spin the visual the whole time the area exists
	var visual: Node2D = get_node_or_null("Visual") as Node2D
	if visual:
		visual.rotation += delta * spin_speed

	# Fade the visual out over the last `fade_time` of the zone's life
	if _life >= duration - fade_time:
		var t: float = clampf((duration - _life) / fade_time, 0.0, 1.0)
		modulate.a = t

	# Grow the zone up to its final size
	if _current_radius < _final_radius:
		var growth: float = ((_final_radius - radius) / max(grow_time, 0.01)) * delta
		_current_radius = min(_final_radius, _current_radius + growth)
		_apply_radius()

	# Drift toward the player so the zone extends toward them
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p: Node2D = players[0] as Node2D
		if is_instance_valid(p):
			global_position = global_position.move_toward(p.global_position, drift_speed * delta)


## Update the visual scale and the collision shape to match the current size.
func _apply_radius() -> void:
	var visual: Node2D = get_node_or_null("Visual") as Node2D
	if visual is Sprite2D:
		var sp: Sprite2D = visual as Sprite2D
		var tex: Texture2D = sp.texture
		var half: float = tex.get_size().x * 0.5 if tex else _current_radius
		var s: float = _current_radius / max(half, 1.0)
		sp.scale = Vector2(s, s)
	var shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = _current_radius


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).slow_sources += 1


func _on_body_exited(body: Node2D) -> void:
	if body is Player and is_instance_valid(body):
		(body as Player).slow_sources = max(0, (body as Player).slow_sources - 1)
