extends Node2D
## Rayo en cadena del Mjolnir. Nace en el enemigo que recibió el golpe melee y salta de blanco en blanco
## (el más cercano en rango) hasta agotar los rebotes, dañando a cada uno. Si no quedan enemigos sin tocar,
## vuelve a golpear a los ya alcanzados (nunca al mismo dos veces seguidas, y al anterior solo si no hay otro). Dibuja un zigzag y se borra solo.
## Sin class_name a propósito: se carga por preload desde WeaponManager.

const SfxScript = preload("res://core/sfx.gd")

const ENEMY_MASK: int = 2
const HOP_INTERVAL: float = 0.07
const FADE_TIME: float = 0.22
const KNOCKBACK: float = 90.0
const ARMOR_PENETRATION: float = 0.5
const BOLT_COLOR: Color = Color(0.65, 0.85, 1.0)
const CORE_COLOR: Color = Color(1.0, 1.0, 1.0)

var _source: Node2D = null
var _damage: float = 0.0
var _bounces_left: int = 0
var _range: float = 260.0
var _current: Node2D = null
## Punto desde donde salta el próximo rayo (el blanco inicial puede morir con el golpe y liberarse antes del primer salto).
var _current_pos: Vector2 = Vector2.ZERO
var _last: Node2D = null
var _visited: Dictionary = {}
var _segments: Array[PackedVector2Array] = []
var _hop_left: float = 0.0
var _fade: float = 0.0
var _finished: bool = false


## Crea la cadena empezando en `first_target` (que ya recibió el golpe directo).
static func spawn(ctx: Node, first_target: Node2D, source: Node2D, damage: float, bounces: int, hop_range: float) -> void:
	if ctx == null or first_target == null or bounces <= 0 or not ctx.is_inside_tree():
		return
	var container: Node = ctx.get_tree().current_scene
	if container == null:
		return
	var bolt: Node2D = (load("res://combat/chain_lightning.gd") as GDScript).new() as Node2D
	bolt.top_level = true
	bolt.z_index = 25
	container.add_child(bolt)
	bolt.call("_start", first_target, source, damage, bounces, hop_range)


func _start(first_target: Node2D, source: Node2D, damage: float, bounces: int, hop_range: float) -> void:
	_current = first_target
	_current_pos = _aim_point(first_target)
	_source = source
	_damage = damage
	_bounces_left = bounces
	_range = hop_range
	_visited[first_target.get_instance_id()] = true
	_hop_left = 0.0
	SfxScript.play(self, &"chain_lightning", first_target.global_position, -4.0)


func _process(delta: float) -> void:
	if _finished:
		_fade += delta
		if _fade >= FADE_TIME:
			queue_free()
		queue_redraw()
		return
	_hop_left -= delta
	if _hop_left <= 0.0:
		_hop_left = HOP_INTERVAL
		_hop()
	queue_redraw()


func _hop() -> void:
	if _bounces_left <= 0:
		_finished = true
		return
	var next: Node2D = _find_next()
	if next == null:
		_finished = true
		return
	_bounces_left -= 1
	var from: Vector2 = _current_pos
	var to: Vector2 = _aim_point(next)
	_segments.append(_zigzag(from, to))
	_visited[next.get_instance_id()] = true
	var dir: Vector2 = (to - from).normalized()
	var payload: HitPayload = HitPayload.new(_damage, KNOCKBACK, dir, _source, [], 1, 0.0, ARMOR_PENETRATION)
	ThrowableUtil.deliver_hit(next, payload)
	SfxScript.play(self, &"chain_lightning", to, -8.0, randf_range(0.9, 1.15))
	_last = _current
	_current = next
	_current_pos = to


## Blanco hostil más cercano al actual: prefiere los que aún no recibieron rayo; solo vuelve al anterior si no hay otro.
func _find_next() -> Node2D:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = _range
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, _current_pos)
	query.collision_mask = ENEMY_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var best_fresh: Node2D = null
	var best_fresh_d: float = INF
	var best_old: Node2D = null
	var best_old_d: float = INF
	var best_last: Node2D = null
	var origin: Vector2 = _current_pos
	for result: Dictionary in space.intersect_shape(query, 32):
		var t: Node2D = ThrowableUtil.resolve_hostile_target(result.get("collider") as Node)
		if t == null or not is_instance_valid(t) or t == _current:
			continue
		var d: float = origin.distance_squared_to(_aim_point(t))
		if t == _last:
			best_last = t
		elif _visited.has(t.get_instance_id()):
			if d < best_old_d:
				best_old_d = d
				best_old = t
		elif d < best_fresh_d:
			best_fresh_d = d
			best_fresh = t
	if best_fresh != null:
		return best_fresh
	return best_old if best_old != null else best_last


func _aim_point(n: Node2D) -> Vector2:
	return n.global_position + Vector2(0.0, -20.0)


func _zigzag(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = maxi(3, int(a.distance_to(b) / 24.0))
	var normal: Vector2 = (b - a).normalized().orthogonal()
	pts.append(a)
	for i: int in range(1, steps):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		pts.append(p + normal * randf_range(-9.0, 9.0))
	pts.append(b)
	return pts


func _draw() -> void:
	var alpha: float = 1.0 - clampf(_fade / FADE_TIME, 0.0, 1.0)
	var reduce: bool = bool((load("res://core/settings.gd") as GDScript).call("reduce_flashes"))
	for seg: PackedVector2Array in _segments:
		draw_polyline(seg, Color(BOLT_COLOR.r, BOLT_COLOR.g, BOLT_COLOR.b, 0.45 * alpha), 7.0)
		draw_polyline(seg, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, (0.5 if reduce else 1.0) * alpha), 2.5)
