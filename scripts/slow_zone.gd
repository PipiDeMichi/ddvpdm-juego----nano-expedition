class_name SlowZone extends Area2D

## By how much enemies inside are slowed (1.0 = normal speed)
@export var slow_factor: float = 0.4

## How long the zone lasts (seconds)
@export var duration: float = 5.0

## Radius within which the zone blocks (destroys) boss projectiles
@export var block_radius: float = 140.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Auto-remove after duration
	get_tree().create_timer(duration).timeout.connect(queue_free)


func _physics_process(_delta: float) -> void:
	# Shield: destroy any boss projectile that enters the zone's radius
	for b in get_tree().get_nodes_in_group("boss_bullet"):
		if is_instance_valid(b) and b is Node2D:
			var d: float = global_position.distance_to((b as Node2D).global_position)
			if d <= block_radius:
				(b as Node).queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		body.slow_sources += 1


func _on_body_exited(body: Node2D) -> void:
	if body is Enemy and is_instance_valid(body):
		body.slow_sources = max(0, body.slow_sources - 1)
