class_name TouchJoystick extends Control

## Maximum distance the knob can travel from center
@export var max_radius: float = 95.0

## Is the joystick currently being touched
var is_active: bool = false

## Current joystick value (-1 to 1 on each axis)
var _value: Vector2 = Vector2.ZERO

## Touch index being tracked
var _touch_index: int = -1

## Knob offset from the center of the control (pixels)
var _knob_offset: Vector2 = Vector2.ZERO

## Drawn joystick colors (cyan, matching the game's neon/TRON theme)
const BASE_FILL := Color(0.16, 0.22, 0.4, 0.35)
const BASE_RING := Color(0.45, 0.85, 1.0, 0.9)
const KNOB_COLOR := Color(0.68, 0.82, 1.0, 1.0)


func _ready() -> void:
	reset_knob()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Grab the joystick if the touch lands in or near its area
		var inside: bool = get_global_rect().grow(60.0).has_point(event.position)
		if inside and _touch_index == -1:
			_touch_index = event.index
			is_active = true
			_update_knob_position(event.position)
	else:
		if event.index == _touch_index:
			_touch_index = -1
			is_active = false
			reset_knob()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _touch_index:
		_update_knob_position(event.position)


func _update_knob_position(touch_position: Vector2) -> void:
	var local: Vector2 = touch_position - get_global_position()
	var offset: Vector2 = local - size * 0.5
	offset = offset.limit_length(max_radius)
	_knob_offset = offset
	_value = offset / max_radius
	_value = _value.limit_length(1.0)
	queue_redraw()


func reset_knob() -> void:
	_knob_offset = Vector2.ZERO
	_value = Vector2.ZERO
	queue_redraw()


func get_value() -> Vector2:
	return _value


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var base_radius: float = min(size.x, size.y) * 0.42

	# Translucent base disc
	draw_circle(center, base_radius, BASE_FILL)
	# Bright outline ring
	draw_arc(center, base_radius, 0.0, TAU, 48, BASE_RING, 4.0, true)
	# Inner guide ring
	draw_arc(center, base_radius * 0.42, 0.0, TAU, 40, Color(BASE_RING, 0.4), 2.0, true)

	# Knob
	var knob_radius: float = min(size.x, size.y) * 0.16
	draw_circle(center + _knob_offset, knob_radius, KNOB_COLOR)
