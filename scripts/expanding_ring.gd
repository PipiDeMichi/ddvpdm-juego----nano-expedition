class_name ExpandingRing extends Node2D
## Expanding shockwave ring shown when the bomb is used.
## Spawns at the player's center, expands outward until it covers the visible
## screen edge, then fades and frees itself.

## How long the ring animation lasts (seconds)
@export var duration: float = 0.9
## Ring starts at this radius (px)
@export var start_radius: float = 12.0
## Ring expands up to this radius (px). Treated as a MINIMUM — at runtime it
## grows further if needed so the wave reaches the screen edges from the player.
@export var end_radius: float = 340.0
## Ring color
@export var color: Color = Color(0.35, 0.9, 1.0)
## Stroke thickness
@export var line_width: float = 6.0
## Starting opacity (fades to 0)
@export var base_alpha: float = 0.9

## Number of concentric rings in the shockwave
@export var ring_count: int = 3

var _age: float = 0.0
## Computed target radius that covers the visible screen from the spawn point
var _target_radius: float = 340.0


func _ready() -> void:
	# Expand outward until the shockwave covers the whole visible screen from
	# wherever the player is. Uses the camera's screen center in world space.
	var cam: Camera2D = get_viewport().get_camera_2d()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if cam != null:
		var center: Vector2 = cam.get_screen_center_position()
		var far: float = 0.0
		for c in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
			far = maxf(far, global_position.distance_to(center + c * vs))
		_target_radius = maxf(end_radius, far)
	else:
		_target_radius = end_radius


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= duration:
		queue_free()


func _draw() -> void:
	# Classic shockwave: a few concentric rings trailing behind the main wave
	for i in range(ring_count):
		var t: float = _age / duration - float(i) * 0.06
		if t < 0.0 or t > 1.0:
			continue
		var r: float = lerpf(start_radius, _target_radius, t)
		var c: Color = color
		c.a = (1.0 - t) * base_alpha
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, c, line_width, true)
