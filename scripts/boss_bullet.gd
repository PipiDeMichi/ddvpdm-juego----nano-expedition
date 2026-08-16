class_name BossBullet extends Area2D
# Bullet fired by the boss toward the player. Damages the player on contact.

## Travel speed (px/s)
@export var speed: float = 280.0
## Damage dealt to the player
@export var damage: int = 1
## Lifetime before it fades out
@export var lifetime: float = 6.0

## Direction the bullet flies
var direction: Vector2 = Vector2.UP

## Random spin rate (rad/s) applied while the bullet flies, tuned per bullet
## so each ranged attack tumbles at its own speed/direction when thrown.
var spin_speed: float = 0.0

var _age: float = 0.0


func _ready() -> void:
	add_to_group("enemy_projectile")
	body_entered.connect(_on_body_entered)
	spin_speed = randf_range(-7.0, 7.0)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	rotation += spin_speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.take_damage(damage)
		queue_free()
