class_name SlowBomb extends Node2D
# Bomb lobbed by the boss. On detonation it leaves a zone that slows the PLAYER.

## Zone scene to spawn on detonation
@export var slow_zone_scene: PackedScene

## Direction of travel
var direction: Vector2 = Vector2.DOWN

## When true (boss enraged), the resulting slow zone expands larger toward the player
var enlarged: bool = false

## Speed (px/s)
@export var speed: float = 200.0
## How long it travels before detonating
@export var travel_time: float = 0.9

var _time: float = 0.0


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	rotation += delta * 8.0
	_time += delta
	if _time >= travel_time:
		_detonate()


func _detonate() -> void:
	if slow_zone_scene:
		var zone: PlayerSlowZone = slow_zone_scene.instantiate() as PlayerSlowZone
		zone.global_position = global_position
		zone.enlarged = enlarged
		var container: Node = get_tree().get_first_node_in_group("game_manager")
		if container == null:
			container = get_tree().current_scene
		if container:
			container.add_child(zone)
	queue_free()
