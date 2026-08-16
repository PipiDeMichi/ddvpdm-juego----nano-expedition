class_name SpaceBackground extends Node2D
## Parallax-scrolling repeating space background.
## The texture is scaled up to fill the screen and tiled in a 2x2 grid. It drifts
## opposite to the player's movement by a fraction (the "delay" that sells depth)
## and wraps seamlessly back to the start when it reaches the edge.

const TEXTURE := preload("res://assets/TEST/space_bg.png")

## How much of the player's movement is applied to the background. 0 = static,
## 1 = moves the same distance (no parallax). Lower values give more "delay".
@export var parallax_factor: float = 0.3

var _wrap: Node2D = null
## One tile size on screen (whole multiple of the texture, covers the viewport)
var _tile := Vector2.ZERO


func _ready() -> void:
	# Draw behind everything (enemies, player, zones, trails - those sit at >= -1)
	z_index = -50
	if TEXTURE == null:
		return
	var vp := get_viewport_rect().size
	var base: Vector2 = TEXTURE.get_size()
	# Scale the texture up so one tile covers the whole screen (a "large"
	# background). Nearest filtering keeps the upscaled pixels crisp.
	var s := maxf(vp.x / base.x, vp.y / base.y)
	_tile = base * s

	_wrap = Node2D.new()
	_wrap.name = "Wrap"
	# This node is repositioned every physics tick and anchored to the camera's
	# moving screen-center. Automatic physics interpolation would smear it
	# against that moving reference (a one-frame blur as it drifts), so disable
	# it here — the background tracks the camera correctly at physics tick rate.
	_wrap.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_wrap)

	# 3x3 grid of full-screen tiles, extending one tile beyond the anchor in
	# every direction. Because the tile is at least the size of the viewport and
	# the anchor (the parallax lag point) always sits inside the visible view,
	# this guarantees the screen is ALWAYS fully covered however far the camera
	# pans (a 2x2 grid could leave an uncovered stripe whenever its top-left
	# corner landed inside the view).
	var offsets: Array = []
	for ix in range(-1, 2):
		for iy in range(-1, 2):
			offsets.append(Vector2(ix, iy) * _tile)
	for off in offsets:
		var sp := Sprite2D.new()
		sp.texture = TEXTURE
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.scale = Vector2(s, s)
		# Sprites are centered; shift so the scaled tile starts at `off`
		sp.position = off + _tile * 0.5
		_wrap.add_child(sp)


func _physics_process(_delta: float) -> void:
	if _wrap == null:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var cpos: Vector2 = cam.get_screen_center_position()
	# Parallax: the background pattern tracks a fraction of the camera movement,
	# so it lags behind the camera and sells depth while it pans. As the camera
	# moves, the pattern shifts more slowly, then wraps seamlessly.
	var lag := cpos * parallax_factor
	# Anchor the tile grid to the parallax lag point, snapped down onto the tile
	# grid, and let the 3x3 grid extend a full tile beyond it in every direction.
	# The parallax lag always stays inside the visible view for this setup, so
	# one tile is always between the anchor and each screen edge.
	_wrap.position.x = lag.x - fposmod(lag.x, _tile.x)
	_wrap.position.y = lag.y - fposmod(lag.y, _tile.y)
	# Gameplay objects live in world space and pan with the camera naturally;
	# no per-frame manual world-shift is applied anymore.
