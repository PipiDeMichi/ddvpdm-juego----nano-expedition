class_name TouchJoystick extends Control

## Maximum distance the knob can travel from center
@export var max_radius: float = 60.0

## Is the joystick currently being touched
var is_active: bool = false

## Current joystick value (-1 to 1 on each axis)
var _value: Vector2 = Vector2.ZERO

## Touch index being tracked
var _touch_index: int = -1

## Base/background reference
@onready var _base: TextureRect = $Base
@onready var _knob: TextureRect = $Knob

## Base center position (set on ready)
var _base_center: Vector2 = Vector2.ZERO


func _ready() -> void:
	_base_center = _base.position + _base.size * 0.5
	reset_knob()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Check if touch is within our base area
		var inside: bool = _base.get_global_rect().grow(50.0).has_point(event.position)
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
	var offset: Vector2 = touch_position - _base.global_position - _base.size * 0.5
	offset = offset.limit_length(max_radius)
	_knob.position = _base_center + offset - _knob.size * 0.5

	# Compute normalized value (-1 to 1)
	_value = offset / max_radius
	_value = _value.limit_length(1.0)


func reset_knob() -> void:
	_knob.position = _base_center - _knob.size * 0.5
	_value = Vector2.ZERO


func get_value() -> Vector2:
	return _value
