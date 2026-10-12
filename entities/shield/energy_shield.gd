extends Node2D
## Escudo de energía: elipse translúcida celeste que envuelve a un personaje (jugador o enemigo).
## Se lee del HealthComponent cada cuadro: aparece cuando hay escudo y se atenúa con lo que queda.
## Cuando el escudo absorbe daño, un anillo brillante se expande y se desvanece; al romperse, se desvanece.
## Sin class_name a propósito: se carga por preload (ver class-name-cache-gotcha).
## Lo crea Player y ShieldedSentinel en `_ready` con `setup()`.

const FILL_COLOR: Color = Color(0.3, 0.85, 1.0, 0.18)
const RIM_COLOR: Color = Color(0.3, 0.85, 1.0, 0.9)
const HIT_COLOR: Color = Color(0.85, 1.0, 1.0, 1.0)
const POINTS: int = 40
const MIN_ALPHA: float = 0.35
const HIT_TIME: float = 0.35
const HIT_GROW: float = 0.2
const BREAK_TIME: float = 0.3

var _health: HealthComponent = null
var _radii: Vector2 = Vector2(24.0, 32.0)
var _last_shield: float = 0.0
var _hit_left: float = 0.0
var _break_left: float = 0.0
var _settings: GDScript = load("res://core/settings.gd") as GDScript


## Une el escudo a la vida de su dueño. `center` es el centro de la elipse en el espacio del padre.
func setup(health: HealthComponent, center: Vector2, radii: Vector2) -> void:
	_health = health
	position = center
	_radii = radii
	_last_shield = health.current_shield if health != null else 0.0
	visible = false


func _process(delta: float) -> void:
	if _health == null or not is_instance_valid(_health):
		return
	var shield: float = _health.current_shield
	if shield < _last_shield and shield > 0.0:
		_hit_left = HIT_TIME
	elif _last_shield > 0.0 and shield <= 0.0:
		_break_left = BREAK_TIME
	_last_shield = shield
	_hit_left = maxf(0.0, _hit_left - delta)
	_break_left = maxf(0.0, _break_left - delta)

	visible = shield > 0.0 or _break_left > 0.0
	if visible:
		queue_redraw()


func _draw() -> void:
	var fraction: float = 0.0
	if _health.max_shield > 0.0:
		fraction = clampf(_health.current_shield / _health.max_shield, 0.0, 1.0)
	var alpha: float = lerpf(MIN_ALPHA, 1.0, fraction)
	if _break_left > 0.0:
		alpha *= _break_left / BREAK_TIME

	var reduce_flashes: bool = bool(_settings.call("reduce_flashes"))
	var flash: float = 0.0 if reduce_flashes else _hit_left / HIT_TIME

	var fill: Color = FILL_COLOR
	fill.a *= alpha
	draw_colored_polygon(_ellipse(1.0), fill)

	var rim: Color = RIM_COLOR
	rim.a *= alpha
	draw_polyline(_closed(_ellipse(1.0)), rim, 2.0, true)

	# Anillo de impacto: arranca sobre el borde y se expande mientras se desvanece
	if flash > 0.0:
		var ring: Color = HIT_COLOR
		ring.a = flash * alpha
		var grow: float = 1.0 + HIT_GROW * (1.0 - flash)
		draw_polyline(_closed(_ellipse(grow)), ring, 3.0, true)
		var glow: Color = HIT_COLOR
		glow.a = 0.25 * flash * alpha
		draw_colored_polygon(_ellipse(1.0), glow)


func _ellipse(size_mult: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in POINTS:
		var a: float = TAU * float(i) / float(POINTS)
		pts.append(Vector2(cos(a) * _radii.x * size_mult, sin(a) * _radii.y * size_mult))
	return pts


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = pts.duplicate()
	out.append(pts[0])
	return out
