extends Node2D
## Barra de progreso de recarga que flota sobre la cabeza del jugador.
## Se llena mientras dura la recarga y hace un destello verde breve al completarla.
## Lee el estado directamente del WeaponManager (no requiere señales adicionales).

const BAR_SIZE: Vector2 = Vector2(44.0, 6.0)
const BAR_OFFSET: Vector2 = Vector2(-22.0, -94.0)
const FLASH_DURATION: float = 0.18

const COLOR_START: Color = Color(1.0, 0.35, 0.25, 1.0)
const COLOR_END: Color = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_DONE: Color = Color(0.35, 1.0, 0.5, 1.0)

## Desplazamiento vertical extra (la mano secundaria usa uno negativo para quedar sobre la barra principal).
var offset_y: float = 0.0

var _weapon_manager: WeaponManager = null
var _was_reloading: bool = false
var _flash_left: float = 0.0
var _progress: float = 0.0


func setup(weapon_manager: WeaponManager) -> void:
	_weapon_manager = weapon_manager


func _ready() -> void:
	z_index = 50
	set_process(true)


func _process(delta: float) -> void:
	if _weapon_manager == null or not is_instance_valid(_weapon_manager):
		return

	var weapon: WeaponData = _weapon_manager.current_weapon
	var reloading: bool = _weapon_manager.is_reloading and weapon != null and weapon.reload_time > 0.0

	if reloading:
		_progress = clampf(1.0 - _weapon_manager.reload_timer / weapon.reload_time, 0.0, 1.0)
		_flash_left = 0.0
	elif _was_reloading:
		# Terminó: destello solo si el cargador quedó lleno (no si se canceló al cambiar de arma)
		if weapon != null and _weapon_manager.get_weapon_ammo(weapon) >= weapon.magazine_size:
			_progress = 1.0
			_flash_left = FLASH_DURATION
	elif _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)

	_was_reloading = reloading
	queue_redraw()


func _draw() -> void:
	var showing_flash: bool = _flash_left > 0.0
	if not _was_reloading and not showing_flash:
		return

	var fill_color: Color = COLOR_START.lerp(COLOR_END, _progress)
	if showing_flash:
		fill_color = COLOR_DONE
		fill_color.a = _flash_left / FLASH_DURATION

	var origin: Vector2 = BAR_OFFSET + Vector2(0.0, offset_y)
	draw_rect(Rect2(origin - Vector2.ONE, BAR_SIZE + Vector2(2.0, 2.0)), Color(0.0, 0.0, 0.0, 0.75))
	draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * _progress, BAR_SIZE.y)), fill_color)
