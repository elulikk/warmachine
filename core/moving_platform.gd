class_name MovingPlatform
extends AnimatableBody2D
## Plataforma móvil / ascensor bidireccional entre dos posiciones o altura configurable.

@export var move_offset: Vector2 = Vector2(0, -600)
@export var speed: float = 140.0
@export var wait_time: float = 1.0

var _start_pos: Vector2
var _target_pos: Vector2
var _going_to_target: bool = true
var _wait_timer: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	_start_pos = global_position
	_target_pos = _start_pos + move_offset


func _physics_process(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait_timer -= delta
		return
	
	var dest: Vector2 = _target_pos if _going_to_target else _start_pos
	var current: Vector2 = global_position
	var step: float = speed * delta
	
	if current.distance_to(dest) <= step:
		global_position = dest
		_going_to_target = not _going_to_target
		_wait_timer = wait_time
	else:
		var dir: Vector2 = (dest - current).normalized()
		global_position += dir * step
