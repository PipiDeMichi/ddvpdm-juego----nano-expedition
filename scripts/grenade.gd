class_name Grenade extends Node2D

## Slow zone scene to spawn on impact
@export var slow_zone_scene: PackedScene

## Direction the grenade flies
var direction: Vector2 = Vector2.UP

## Speed of the grenade
@export var speed: float = 500.0

## How long it travels before detonating
@export var travel_time: float = 0.22

## Radius within which the grenade blocks (destroys) boss projectiles
@export var block_radius: float = 40.0

var _time: float = 0.0


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	# Spin for effect
	rotation += delta * 8.0

	# Shield: destroy any boss projectile that passes near the grenade
	_block_boss_bullets()

	_time += delta
	if _time >= travel_time:
		_detonate()


## Destroy every boss projectile within `block_radius` of the grenade
func _block_boss_bullets() -> void:
	for b in get_tree().get_nodes_in_group("boss_bullet"):
		if is_instance_valid(b) and b is Node2D:
			var d: float = global_position.distance_to((b as Node2D).global_position)
			if d <= block_radius:
				(b as Node).queue_free()


func _detonate() -> void:
	if slow_zone_scene:
		var zone: SlowZone = slow_zone_scene.instantiate() as SlowZone
		zone.global_position = global_position
		var container: Node = get_tree().get_first_node_in_group("game_manager")
		if container == null:
			container = get_tree().current_scene
		if container:
			container.add_child(zone)
	queue_free()
