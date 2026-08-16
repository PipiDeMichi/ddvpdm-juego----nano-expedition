class_name WaterDistortion extends Node2D
## World-anchored "water drop" screen distortion, expanded from a world point.
## Drawn between the game world and the HUD (z_index 50, below the HUD/border at
## 100) so the ripple warps the scene but leaves the HUD text crisp.

## How long the ripple lasts (seconds)
@export var duration: float = 0.9

## World position the ripple originates from (set BEFORE adding to the tree)
var center_world: Vector2 = Vector2.ZERO

var _age: float = 0.0
@onready var _rect: ColorRect = $ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	z_index = 50  # above the world/enemies, below the HUD & screen border (100)
	_mat = _rect.material as ShaderMaterial
	if _mat == null:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", vs.x / maxf(vs.y, 1.0))
	_mat.set_shader_parameter("progress", 0.0)
	_position_over_view()


func _process(delta: float) -> void:
	_position_over_view()
	_age += delta
	if _mat:
		_mat.set_shader_parameter("progress", clampf(_age / duration, 0.0, 1.0))
		_update_center()
	if _age >= duration:
		queue_free()


## Keep the fullscreen quad locked to the camera so it always covers the view.
func _position_over_view() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	var tl: Vector2 = Vector2.ZERO
	if cam != null:
		tl = cam.get_screen_center_position() - vs * 0.5
	position = tl
	_rect.position = Vector2.ZERO
	_rect.size = vs


## Convert the origin world point into normalized screen UV for the shader.
func _update_center() -> void:
	if _mat == null:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	if vs.x <= 0.0 or vs.y <= 0.0:
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	var tl: Vector2 = Vector2.ZERO
	if cam != null:
		tl = cam.get_screen_center_position() - vs * 0.5
	var uv: Vector2 = (center_world - tl) / vs
	_mat.set_shader_parameter("center_uv", uv)
