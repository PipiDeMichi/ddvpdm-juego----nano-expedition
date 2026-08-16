class_name Bullet extends Area2D

## Direction the bullet travels
var direction: Vector2 = Vector2.UP

## Speed in pixels per second
@export var speed: float = 600.0

## Damage dealt to enemies
@export var damage: int = 1

## Lifetime in seconds before auto-destruction
@export var lifetime: float = 2.0

## Maximum distance at which the bullet senses enemies to curve toward
@export var homing_range: float = 260.0

## Max turn rate (radians/second). Higher = locks on harder; low = gentle assist.
@export var homing_rate: float = 5.0

var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	_steer_toward_enemy(delta)
	position += direction * speed * delta

	# Rotate the sprite to face the direction of travel
	$Sprite2D.rotation = direction.angle()

	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	# Free the bullet once it leaves the visible view. This check must be
	# camera-relative (world space) because the camera pans with the player —
	# a fixed screen-size check would instantly kill bullets the moment the
	# player leaves the starting area.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = 80.0
	var cam := get_viewport().get_camera_2d()
	var view: Rect2
	if cam == null:
		view = Rect2(Vector2.ZERO, viewport_size)
	else:
		view = Rect2(cam.get_screen_center_position() - viewport_size * 0.5, viewport_size)
	if global_position.x < view.position.x - margin or \
	   global_position.x > view.end.x + margin or \
	   global_position.y < view.position.y - margin or \
	   global_position.y > view.end.y + margin:
		queue_free()


# Gently curve the bullet toward the nearest nearby enemy OR boss (slight homing assist)
func _steer_toward_enemy(delta: float) -> void:
	var targets: Array = get_tree().get_nodes_in_group("enemy")
	targets.append_array(get_tree().get_nodes_in_group("boss"))
	var best: Node2D = null
	var best_dist: float = homing_range
	for e in targets:
		if not is_instance_valid(e) or e is not Node2D:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e as Node2D

	if best == null:
		return

	var desired: Vector2 = (best.global_position - global_position).normalized()
	var to_turn: float = direction.angle_to(desired)
	var max_turn: float = homing_rate * delta
	var new_angle: float = direction.angle() + clampf(to_turn, -max_turn, max_turn)
	direction = Vector2.from_angle(new_angle)


func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		body.take_damage(damage)
		_destroy()
	elif body is Boss:
		body.take_damage(damage)
		_destroy()


func _on_area_entered(_area: Area2D) -> void:
	# Destroy bullet on hitting another area (enemy hitbox, etc)
	pass


func _destroy() -> void:
	# Could add particle effect here
	queue_free()
