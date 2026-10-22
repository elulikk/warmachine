extends CanvasLayer
## Mira del juego: sigue al ratón, cambia de forma según el arma en mano (ver core/crosshair_data.gd) y se abre o se
## cierra según la precisión del arma: cuanta más dispersión tiene (y cuanto más sostenida es la ráfaga), más grande
## es, siempre entre el radio mínimo y el máximo de esa arma. Verde fluorescente, gruesa y con contorno negro.
## Solo está activa jugando: sobre ventanas, botones o menús (y en pausa) vuelve el cursor chico de siempre.
## Sin class_name a propósito: lo agrega el autoload GameManager por preload.

const CrosshairData = preload("res://core/crosshair_data.gd")
const CrosshairCursor = preload("res://core/crosshair_cursor.gd")

const COLOR_MAIN: Color = Color(0.3, 1.0, 0.15, 1.0)
const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.9)
const THICKNESS: float = 3.0
## Cuánto se abre la mira al disparar (px) y qué tan rápido se cierra.
const SHOT_PULSE_PX: float = 5.0
const PULSE_DECAY: float = 9.0
const RADIUS_SMOOTHING: float = 16.0

var _canvas: Control = null
var _player: Player = null
var _weapon: WeaponData = null
var _data: Dictionary = CrosshairData.NO_WEAPON
var _radius: float = 6.0
var _pulse: float = 0.0
var _active: bool = false
var _forced: int = -1  # -1: automático, 0: fuerza el cursor del sistema, 1: fuerza la mira (solo pruebas)


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_reticle)
	add_child(_canvas)
	_canvas.visible = false


func _process(delta: float) -> void:
	var active: bool = _should_be_active()
	if active != _active:
		_active = active
		_canvas.visible = active
		CrosshairCursor.set_hidden(active)
	if not _active:
		return
	_update_weapon()
	var target: float = CrosshairData.radius_for(_data, _current_spread_deg()) + _pulse * SHOT_PULSE_PX
	_radius = lerpf(_radius, target, minf(1.0, delta * RADIUS_SMOOTHING))
	_pulse = maxf(0.0, _pulse - delta * PULSE_DECAY)
	_canvas.queue_redraw()


func _should_be_active() -> bool:
	if _forced >= 0:
		return _forced == 1
	if DisplayServer.get_name() == "headless" or get_tree().paused:
		return false
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
		_weapon = null
		if _player != null and _player.weapon_manager != null and not _player.weapon_manager.weapon_fired.is_connected(_on_weapon_fired):
			_player.weapon_manager.weapon_fired.connect(_on_weapon_fired)
	if _player == null:
		return false
	var vp: Viewport = get_viewport()
	if not DisplayServer.window_is_focused() or not Rect2(Vector2.ZERO, vp.get_visible_rect().size).has_point(vp.get_mouse_position()):
		return false
	# Sobre un botón, una ventana o la barra de acceso rápido: cursor normal
	return vp.gui_get_hovered_control() == null


func _update_weapon() -> void:
	var weapon: WeaponData = _player.weapon_manager.current_weapon if _player != null and _player.weapon_manager != null else null
	if weapon != _weapon:
		_weapon = weapon
		_data = CrosshairData.for_weapon(weapon)


## Dispersión total del arma (grados) más la que suma la ráfaga sostenida.
func _current_spread_deg() -> float:
	if _weapon == null:
		return 0.0
	var spread: float = _weapon.spread_angle_degrees
	if _player != null and _player.weapon_manager != null:
		spread += _player.weapon_manager.get_aim_bloom_degrees()
	return spread


func _on_weapon_fired(_w: WeaponData) -> void:
	_pulse = 1.0


func _draw_reticle() -> void:
	var c: Vector2 = _canvas.get_local_mouse_position()
	var r: float = _radius
	var arm: float = float(_data.get("arm", 7.0))
	match str(_data.get("style", "cross")):
		"ring":
			_arc(c, r)
			_dot(c)
			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT]:
				_line(c + dir * (r - arm * 0.5), c + dir * (r + arm * 0.5))
		"brackets":
			arm = minf(arm, r * 0.8)
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					var corner: Vector2 = c + Vector2(sx * r, sy * r)
					_line(corner, corner + Vector2(-sx * arm, 0.0))
					_line(corner, corner + Vector2(0.0, -sy * arm))
			_dot(c)
		"tee":
			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
				_line(c + dir * r, c + dir * (r + arm))
			_dot(c)
		"scope":
			_arc(c, r, 1.5)
			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_line(c + dir * (r + 2.0), c + dir * (r + 2.0 + arm))
			_dot(c)
		"diamond":
			var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0), c + Vector2(0.0, r), c + Vector2(-r, 0.0), c + Vector2(0.0, -r)])
			_polyline(pts)
			_dot(c)
		"chevrons":
			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var tip: Vector2 = c + dir * r
				var back: Vector2 = dir * arm
				var side: Vector2 = Vector2(-dir.y, dir.x) * arm * 0.7
				_line(tip, tip + back + side)
				_line(tip, tip + back - side)
			_dot(c)
		"dot":
			_arc(c, r)
			_dot(c)
		_:
			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				_line(c + dir * r, c + dir * (r + arm))
			_dot(c)


func _line(a: Vector2, b: Vector2, width: float = THICKNESS) -> void:
	_canvas.draw_line(a, b, Color(COLOR_MAIN, 0.22), width + 6.0)
	_canvas.draw_line(a, b, COLOR_OUTLINE, width + 3.0)
	_canvas.draw_line(a, b, COLOR_MAIN, width)


func _polyline(points: PackedVector2Array, width: float = THICKNESS) -> void:
	_canvas.draw_polyline(points, Color(COLOR_MAIN, 0.22), width + 6.0)
	_canvas.draw_polyline(points, COLOR_OUTLINE, width + 3.0)
	_canvas.draw_polyline(points, COLOR_MAIN, width)


func _arc(c: Vector2, radius: float, width: float = THICKNESS) -> void:
	_canvas.draw_arc(c, radius, 0.0, TAU, 40, Color(COLOR_MAIN, 0.22), width + 6.0, true)
	_canvas.draw_arc(c, radius, 0.0, TAU, 40, COLOR_OUTLINE, width + 3.0, true)
	_canvas.draw_arc(c, radius, 0.0, TAU, 40, COLOR_MAIN, width, true)


func _dot(c: Vector2) -> void:
	_canvas.draw_circle(c, 3.5, COLOR_OUTLINE)
	_canvas.draw_circle(c, 2.0, COLOR_MAIN)
