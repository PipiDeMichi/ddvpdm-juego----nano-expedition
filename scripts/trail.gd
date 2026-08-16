class_name Trail2D extends Node2D
## TRON-style neon tail that traces the target's path and fades out shortly after
## it is left behind. Cyan-blue glow with a bright core.

@export var trail_time: float = 0.7      # seconds each point survives
@export var min_speed: float = 60.0      # only trail while the target moves at/above this
@export var sample_distance: float = 5.0 # min px between recorded points
@export var core_width: float = 2.5
@export var glow_width: float = 9.0
@export var color: Color = Color(0.25, 0.95, 1.0, 1.0)

## How far behind the ship (opposite its movement) each new tail point is anchored,
## so the neon trail streams out from the ship's rear instead of its center.
@export var rear_offset: float = 18.0

## The moving node to trace (set before adding to the tree).
var target: Node2D = null

var _points: Array[Vector2] = []
var _times: Array[float] = []
var _last: Vector2 = Vector2.ZERO
var _has_last: bool = false


func _ready() -> void:
	# Render behind enemies/player but above the scrolling background.
	z_index = -1


func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var now: float = Time.get_ticks_msec() / 1000.0

	# Prune points that have lived past trail_time (this is what makes the tail
	# "disappear after a short time").
	while _times.size() > 0 and now - _times[0] > trail_time:
		_points.pop_front()
		_times.pop_front()

	# Record a new point only while moving fast enough and far enough apart.
	var vel: Vector2 = target.velocity
	if vel.length() >= min_speed:
		# Anchor the sample at the ship's REAR (opposite its heading) so the neon
		# tail streams out from behind the ship rather than from its center.
		var p: Vector2 = target.global_position - vel.normalized() * rear_offset
		if not _has_last or p.distance_to(_last) >= sample_distance:
			_points.push_back(p)
			_times.push_back(now)
			_last = p
			_has_last = true

	queue_redraw()


func _draw() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for i in range(_points.size() - 1):
		var a: Vector2 = _points[i]
		var b: Vector2 = _points[i + 1]
		# Alpha fades with the age of the newer endpoint -> bright at the head,
		# transparent near the tail.
		var t: float = clampf(1.0 - (now - _times[i + 1]) / trail_time, 0.0, 1.0)
		if t <= 0.001:
			continue
		var col: Color = color
		col.a *= t
		# Wide faint glow pass, then a thin bright core (classic Tron look).
		draw_line(a, b, Color(col.r, col.g, col.b, col.a * 0.28), glow_width, true)
		draw_line(a, b, col, core_width, true)
