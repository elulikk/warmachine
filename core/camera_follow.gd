class_name CameraFollow
extends Camera2D
## Controlador de cámara 2D con interpolación suave (smoothing) hacia el Jugador.
## Mantiene al personaje centrado con un ligero offset vertical para anticipar saltos y caídas.

## Nodo al que seguirá la cámara (normalmente la instancia de Player).
@export var target: Node2D

## Velocidad de interpolación lineal (mayor = más rígido, menor = más suave).
@export var smooth_speed: float = 6.0

## Desplazamiento respecto a la posición global del objetivo.
@export var target_offset: Vector2 = Vector2(0, -32)


var _base_offset: Vector2 = Vector2.ZERO
## Zoom del nivel (.tscn). La escala de interfaz agranda todo el lienzo: la cámara la compensa para que se vea
## la misma porción del mundo (ver `ui_scale` en core/settings.gd).
var _base_zoom: Vector2 = Vector2.ONE
var _applied_ui_scale: float = -1.0
## Zoom que pide el jugador con Ctrl + rueda (1.0 = el del nivel).
const ZOOM_STEP: float = 1.1
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 2.5
var _user_zoom: float = 1.0
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_time_left: float = 0.0
## Bloqueo horizontal (encuentros de arena): mientras está activo, la cámara no sigue al jugador en X.
var _x_locked: bool = false
var _locked_x: float = 0.0


func _ready() -> void:
	add_to_group(&"game_camera")
	_base_offset = offset
	_base_zoom = zoom
	_sync_ui_scale()

	# Si no fue asignado en el Inspector, buscar la primera entidad del grupo 'player'
	if target == null:
		target = get_tree().get_first_node_in_group(&"player")
	
	# Posicionar inmediatamente en el primer frame para evitar paneo abrupto al spawnear
	if target != null and is_instance_valid(target):
		global_position = target.global_position + target_offset


## Inicia una sacudida de cámara. Una sacudida más débil no pisa a una más fuerte en curso.
func shake(strength_in: float, duration: float = 0.18) -> void:
	var strength: float = strength_in * float((load("res://core/settings.gd") as GDScript).call("get_float", "screen_shake"))
	if strength <= 0.01:
		return
	if strength < _get_current_shake_amplitude():
		return
	_shake_strength = strength
	_shake_duration = maxf(duration, 0.01)
	_shake_time_left = _shake_duration


func _get_current_shake_amplitude() -> float:
	if _shake_time_left <= 0.0:
		return 0.0
	return _shake_strength * (_shake_time_left / _shake_duration)


func _sync_ui_scale() -> void:
	var ui_scale: float = get_tree().root.content_scale_factor
	if is_equal_approx(ui_scale, _applied_ui_scale):
		return
	_applied_ui_scale = ui_scale
	_apply_zoom()


## Zoom final: base del nivel, compensado por la escala de interfaz, multiplicado por el zoom del jugador.
func _apply_zoom() -> void:
	var ui_scale: float = get_tree().root.content_scale_factor
	zoom = _base_zoom / maxf(ui_scale, 0.1) * _user_zoom


## Congela la cámara en horizontal, centrada en `center_x` (acotada a los límites del nivel).
## Devuelve el borde izquierdo y derecho de lo que se ve, para ubicar ahí las paredes.
func lock_horizontal(center_x: float) -> Vector2:
	var half_width: float = get_viewport_rect().size.x / zoom.x * 0.5
	_locked_x = clampf(center_x, limit_left + half_width, limit_right - half_width)
	_x_locked = true
	return get_horizontal_view()


## Borde izquierdo y derecho de lo que muestra la cámara en horizontal (en mundo).
## Con el bloqueo activo usa el punto fijo, así sirve aunque la cámara todavía esté deslizándose hacia él.
func get_horizontal_view() -> Vector2:
	var center_x: float = _locked_x if _x_locked else global_position.x
	var half_width: float = get_viewport_rect().size.x / zoom.x * 0.5
	return Vector2(center_x - half_width, center_x + half_width)


func is_horizontal_locked() -> bool:
	return _x_locked


## Libera la cámara para que vuelva a seguir al jugador.
func unlock_horizontal() -> void:
	_x_locked = false


## Ctrl + rueda acerca (arriba) o aleja (abajo) la cámara. Mantener Ctrl es lo que lo activa.
## Con la cámara bloqueada no se hace zoom: las paredes de la arena ya están puestas para el zoom actual.
func _unhandled_input(event: InputEvent) -> void:
	var wheel: InputEventMouseButton = event as InputEventMouseButton
	if wheel == null or not wheel.pressed or not Input.is_key_pressed(KEY_CTRL) or _x_locked:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_user_zoom = clampf(_user_zoom * ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_user_zoom = clampf(_user_zoom / ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	else:
		return
	_apply_zoom()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_sync_ui_scale()
	if _shake_time_left <= 0.0:
		return

	# Tiempo real: el hit stop ralentiza delta y la sacudida debe seguir viéndose durante él
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	_shake_time_left = maxf(0.0, _shake_time_left - real_delta)

	if _shake_time_left <= 0.0:
		offset = _base_offset
		return

	var amplitude: float = _get_current_shake_amplitude()
	offset = _base_offset + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude


func _physics_process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var destination: Vector2 = target.global_position + target_offset
		if _x_locked:
			destination.x = _locked_x
		global_position = global_position.lerp(destination, smooth_speed * delta)
