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
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_time_left: float = 0.0


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
	zoom = _base_zoom / maxf(ui_scale, 0.1)


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
		global_position = global_position.lerp(destination, smooth_speed * delta)
