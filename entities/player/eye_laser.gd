extends Node2D
## Rayo láser del Casco Láser (Fase de ideas a futuro). Lo agrega Player en `_ready`.
## Con `Player.has_eye_laser` (casco equipado) y la acción `eye_laser` mantenida, sale un haz continuo desde los ojos
## hacia donde apunta el jugador. Daña por tick a todos los enemigos que cruza (atraviesa) y se frena en el terreno.
## Gasta una barra de energía que se recarga sola; sin energía el haz se corta hasta juntar un mínimo.
## Sin class_name a propósito: se carga por preload (ver class-name-cache-gotcha).

const SfxScript = preload("res://core/sfx.gd")

const MAX_ENERGY: float = 100.0
const DRAIN_PER_SECOND: float = 40.0
const REGEN_PER_SECOND: float = 22.0
const REGEN_DELAY: float = 0.7
## Energía mínima para empezar a disparar de nuevo después de vaciarla.
const RESTART_ENERGY: float = 20.0

const BEAM_RANGE: float = 560.0
const BEAM_THICKNESS: float = 22.0
const TICK_INTERVAL: float = 0.1
const TICK_DAMAGE: float = 8.0
## Rayo óptico estilo Cíclope: empuja fuerte a lo que toca.
const TICK_KNOCKBACK: float = 140.0
const ARMOR_PENETRATION: float = 0.25
const TERRAIN_MASK: int = 1
const ENEMY_MASK: int = 2

var energy: float = MAX_ENERGY

var _player: Player = null
var _firing: bool = false
var _exhausted: bool = false
var _tick_left: float = 0.0
var _regen_wait: float = 0.0
var _beam_start: Vector2 = Vector2.ZERO
var _beam_end: Vector2 = Vector2.ZERO
var _pulse: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player
	# Coordenadas globales: el haz y la barra se dibujan sin depender de la escala o el giro del jugador
	top_level = true
	z_index = 20


func _physics_process(delta: float) -> void:
	global_position = Vector2.ZERO
	_pulse += delta * 40.0
	var wants: bool = _wants_to_fire()
	if wants and not _exhausted:
		_fire(delta)
	else:
		_firing = false
		if _regen_wait > 0.0:
			_regen_wait -= delta
		elif energy < MAX_ENERGY:
			energy = minf(MAX_ENERGY, energy + REGEN_PER_SECOND * delta)
		if _exhausted and energy >= RESTART_ENERGY:
			_exhausted = false
	queue_redraw()


func _wants_to_fire() -> bool:
	if _player == null or not _player.has_eye_laser or not InputMap.has_action(&"eye_laser"):
		return false
	return Input.is_action_pressed(&"eye_laser")


func _fire(delta: float) -> void:
	_firing = true
	_regen_wait = REGEN_DELAY
	energy = maxf(0.0, energy - DRAIN_PER_SECOND * delta)
	if energy <= 0.0:
		_exhausted = true
		_firing = false
		return

	var dir: Vector2 = _aim_direction()
	_beam_start = _eye_position()
	var far_end: Vector2 = _beam_start + dir * BEAM_RANGE
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(_beam_start, far_end, TERRAIN_MASK)
	var hit: Dictionary = space.intersect_ray(ray)
	_beam_end = hit["position"] as Vector2 if not hit.is_empty() else far_end

	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = TICK_INTERVAL
		_damage_along_beam(space, dir)
		SfxScript.play(self, &"laser_beam", _beam_start, -8.0, randf_range(0.95, 1.05))


func _damage_along_beam(space: PhysicsDirectSpaceState2D, dir: Vector2) -> void:
	var length: float = _beam_start.distance_to(_beam_end)
	if length < 1.0:
		return
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(length, BEAM_THICKNESS)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(dir.angle(), (_beam_start + _beam_end) * 0.5)
	query.collision_mask = ENEMY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var seen: Dictionary = {}
	for result: Dictionary in space.intersect_shape(query, 32):
		var target: Node2D = ThrowableUtil.resolve_hostile_target(result.get("collider") as Node)
		if target == null or not is_instance_valid(target):
			continue
		var key: int = target.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		var payload: HitPayload = HitPayload.new(TICK_DAMAGE, TICK_KNOCKBACK, dir, _player, [], 1, 0.0, ARMOR_PENETRATION)
		ThrowableUtil.deliver_hit(target, payload)


func _aim_direction() -> Vector2:
	if _player.weapon_pivot != null:
		return _player.weapon_pivot.get_aim_direction()
	return Vector2(float(_player.facing_direction), 0.0)


func _eye_position() -> Vector2:
	if _player.is_prone:
		return _player.global_position + Vector2(float(_player.facing_direction) * (30.0 if _player.laser_from_chest else 40.0), -10.0)
	var height: float = -34.0 if _player.is_crouching else -52.0
	if _player.laser_from_chest:
		height = -24.0 if _player.is_crouching else -38.0
	return _player.global_position + Vector2(float(_player.facing_direction) * 8.0, height)


func _draw() -> void:
	if _player == null or not _player.has_eye_laser:
		return
	if _firing:
		var flicker: float = 0.75 + 0.25 * sin(_pulse)
		var dir: Vector2 = (_beam_end - _beam_start).normalized()
		var side: Vector2 = dir.orthogonal()
		# Haz rubí que se abre hacia el final (sale angosto del visor, como el de Cíclope)
		for layer: Array in [[1.9, _tint(Color(0.9, 0.0, 0.08, 0.28 * flicker))], [1.1, _tint(Color(1.0, 0.1, 0.15, 0.75))], [0.45, _tint(Color(1.0, 0.55, 0.5, 0.95))]]:
			var w0: float = BEAM_THICKNESS * 0.25 * float(layer[0])
			var w1: float = BEAM_THICKNESS * 0.5 * float(layer[0]) * (0.9 + 0.1 * flicker)
			draw_colored_polygon(PackedVector2Array([_beam_start + side * w0, _beam_end + side * w1,
				_beam_end - side * w1, _beam_start - side * w0]), layer[1] as Color)
		draw_line(_beam_start, _beam_end, _tint(Color(1.0, 0.95, 0.9, 1.0)), 2.5)
		# Visor encendido sobre los ojos
		var visor: Vector2 = _beam_start - dir * 4.0
		draw_line(visor - side * 7.0, visor + side * 7.0, _tint(Color(1.0, 0.15, 0.2, 0.9)), 5.0)
		draw_circle(_beam_start, 9.0 * flicker, _tint(Color(1.0, 0.3, 0.3, 0.55)))
		# Impacto: destello y chispas
		draw_circle(_beam_end, 10.0 * flicker + 4.0, _tint(Color(1.0, 0.25, 0.2, 0.45)))
		draw_circle(_beam_end, 5.0 * flicker + 2.0, _tint(Color(1.0, 0.85, 0.7, 0.95)))
		for i: int in 5:
			var a: float = dir.angle() + PI + sin(_pulse * 0.37 + float(i) * 2.1) * 1.3
			var l: float = 8.0 + 8.0 * absf(sin(_pulse * 0.5 + float(i)))
			draw_line(_beam_end, _beam_end + Vector2.from_angle(a) * l, _tint(Color(1.0, 0.6, 0.4, 0.9)), 2.0)
	# Barra de energía sobre la cabeza, solo mientras no está llena
	if energy < MAX_ENERGY - 0.5:
		var origin: Vector2 = _player.global_position + Vector2(-20.0, -92.0)
		draw_rect(Rect2(origin, Vector2(40.0, 4.0)), _tint(Color(0.0, 0.0, 0.0, 0.6)))
		var fill: Color = _tint(Color(1.0, 0.3, 0.25, 1.0)) if _exhausted else _tint(Color(1.0, 0.8, 0.3, 1.0))
		draw_rect(Rect2(origin, Vector2(40.0 * energy / MAX_ENERGY, 4.0)), fill)


## Con la Pechera de Hierro el haz es azul: se cambian los canales rojo y azul de cada color del dibujo.
func _tint(c: Color) -> Color:
	if _player == null or not _player.laser_from_chest:
		return c
	return Color(c.b, maxf(c.g, c.b * 0.7), c.r, c.a)
