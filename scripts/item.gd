class_name Item extends Area2D

## Types of collectible items
enum ItemType { HEAL, STAMINA }

## Which kind of item this is
@export var item_type: int = ItemType.HEAL

## Distance (px) at which the item starts following the player
@export var magnet_range: float = 140.0
## Speed (px/s) at which the item chases the player once it starts following
@export var magnet_speed: float = 340.0
## Seconds the item sits around before it starts its despawn-warning blink
@export var lifetime: float = 15.0
## How many appear/disappear blinks happen as a warning before despawning
@export var blink_cycles: int = 5
## Seconds per blink toggle (each on/off switch takes this long)
@export var blink_interval: float = 0.3

## Textures for each item type
const HEAL_TEXTURE := preload("res://assets/16x16heal_meat.png")
const PAN_TEXTURE := preload("res://assets/16x16pan.png")

## Seconds the item has been alive
var _age: float = 0.0
## Whether the item is in its despawn-warning blink phase
var _blinking: bool = false
var _blink_timer: float = 0.0
var _blink_toggles: int = 0
## Cached reference to the player (for the magnet effect)
var _player: Player = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Set the sprite based on item type
	var sprite: Sprite2D = $Sprite2D as Sprite2D
	match item_type:
		ItemType.HEAL:
			sprite.texture = HEAL_TEXTURE
		ItemType.STAMINA:
			sprite.texture = PAN_TEXTURE


func _physics_process(delta: float) -> void:
	# Magnet: once the player is near, the item follows them until picked up.
	if _player == null or not is_instance_valid(_player):
		var players: Array = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0] as Player
	if _player and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) < magnet_range:
			var dir: Vector2 = (_player.global_position - global_position).normalized()
			global_position += dir * magnet_speed * delta

	# Lifetime + despawn warning: after `lifetime`, blink `blink_cycles` times,
	# then the item disappears if the player still hasn't grabbed it.
	if not _blinking:
		_age += delta
		if _age >= lifetime:
			_blinking = true
			visible = false
			_blink_timer = 0.0
	else:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_timer = blink_interval
			visible = not visible
			_blink_toggles += 1
			if _blink_toggles >= blink_cycles * 2:
				queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		match item_type:
			ItemType.HEAL:
				body.heal(1)
			ItemType.STAMINA:
				body.refill_dashes(1)
		queue_free()
