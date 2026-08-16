class_name EnemyStain extends Sprite2D
# Ground "stain" left behind by a dying enemy. Fades out over its lifetime and
# frees itself, so enemies leaving moco stains behind as they die.

## How long the stain lingers (seconds) before it fades out and disappears
@export var lifetime: float = 2.0
## How long the fade-out lasts (seconds)
@export var fade_time: float = 0.6

## Render-size multiplier (over moco's native 32px) tuned to the dying entity's
## size, so bigger enemies leave proportionally bigger stains.
@export var base_scale: float = 4.0

## Tint matching the dying entity's texture color.
@export var color: Color = Color(1.0, 1.0, 1.0, 1.0)

## Time the stain has existed
var _life: float = 0.0


func _ready() -> void:
	# Render just above the ground/background but below enemy/player sprites
	z_index = -20
	randomize_visual()


func _process(delta: float) -> void:
	_life += delta
	if _life >= lifetime - fade_time:
		var t: float = clampf((lifetime - _life) / fade_time, 0.0, 1.0)
		modulate.a = t
	if _life >= lifetime:
		queue_free()


## Add random rotation and a slight size/opacity variance so repeated kills
## don't leave identical stains. scale/color reflect the dying entity's size/col.
func randomize_visual() -> void:
	rotation = randf_range(0.0, TAU)
	var s: float = base_scale * randf_range(0.8, 1.3)
	scale = Vector2(s, s)
	modulate = color
	modulate.a *= randf_range(0.7, 1.0)
