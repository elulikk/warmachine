extends ThrowableBase
## Carga de C4: se pega a la primera pared, piso o enemigo que toca y espera. Volver a apretar la tecla del
## arrojadizo la detona (todas las cargas puestas, ver `ThrowableManager._detonate_remote_charges`).
## Si nadie la detona, estalla sola al terminar `fuse_time`.

const GROUP: StringName = &"remote_charges"

var _stuck: bool = false
var _host_target: Node2D = null
var _host_offset: Vector2 = Vector2.ZERO
var _led_on: bool = false
var _led_left: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_c4_body_entered)


func _physics_process(delta: float) -> void:
	if _host_target != null:
		if is_instance_valid(_host_target) and not _host_target.is_queued_for_deletion() \
				and not (_host_target.get("is_dead") == true):
			global_position = _host_target.global_position + _host_offset
		else:
			# El enemigo murió con la carga encima: se cae al piso y sigue armada
			_host_target = null
			_stuck = false
			set_deferred("freeze", false)
	_led_left -= delta
	if _led_left <= 0.0:
		_led_left = 0.35 if _stuck else 0.6
		_led_on = not _led_on
		queue_redraw()
	super._physics_process(delta)


## Detonación remota, con un retraso chico para que varias cargas estallen en cadena.
func remote_detonate(delay: float = 0.0) -> void:
	remove_from_group(GROUP)
	if delay <= 0.0:
		_detonation_requested = true
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void: _detonation_requested = true)


func _on_c4_body_entered(body: Node) -> void:
	if _stuck or _detonated:
		return
	if body is StaticBody2D or body is TileMap or body.is_in_group(&"world"):
		_stick_to(null)


func _on_sensor_target_entered(node: Node) -> void:
	if _stuck or _detonated or _age < arming_time:
		return
	var target: Node2D = ThrowableUtil.resolve_hostile_target(node)
	if target != null:
		_stick_to(target)


func _stick_to(target: Node2D) -> void:
	_stuck = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	set_deferred("freeze", true)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_host_target = target
	if target != null:
		_host_offset = global_position - target.global_position
	GameFeel.sfx(self, &"c4_beep", global_position, -8.0)


func _draw() -> void:
	# Ladrillo de explosivo con cinta y un LED que titila (más rápido cuando ya está pegado)
	draw_rect(Rect2(-7.0, -4.5, 14.0, 9.0), Color(0.16, 0.14, 0.1, 1.0))
	draw_rect(Rect2(-6.0, -3.5, 12.0, 7.0), Color(0.78, 0.7, 0.5, 1.0))
	draw_rect(Rect2(-1.5, -4.5, 3.0, 9.0), Color(0.25, 0.25, 0.28, 1.0))
	draw_rect(Rect2(2.5, -3.0, 3.0, 2.5), Color(1.0, 0.15, 0.1, 1.0) if _led_on else Color(0.3, 0.05, 0.05, 1.0))
