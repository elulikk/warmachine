extends Area2D
## Boomerang (arrojadizo táctico). Sale hacia el cursor, daña a los enemigos que toca en la ida y en la vuelta
## (un enemigo golpeado en cada pasada cuenta dos veces) y regresa solo a la mano del jugador.
## Si choca con el terreno en la ida, vuelve de inmediato. Al atraparlo reinicia casi toda la recarga del arrojadizo.
## Lo instancia el ThrowableManager y lo lanza con `launch()`. Sin class_name: se carga por escena.

const SfxScript = preload("res://core/sfx.gd")

@export var damage: float = 26.0
@export var knockback_force: float = 140.0
## Alcance de la ida (px) y velocidades: sale rápido y se frena; vuelve acelerando.
@export var reach: float = 380.0
@export var out_speed: float = 620.0
@export var return_speed: float = 700.0
@export var catch_distance: float = 34.0
@export var max_lifetime: float = 4.0
## Recarga que queda en el ThrowableManager al atraparlo.
@export var cooldown_after_catch: float = 0.4

var thrower: Node2D = null

var _direction: Vector2 = Vector2.RIGHT
var _move_dir: Vector2 = Vector2.RIGHT
var _traveled: float = 0.0
var _returning: bool = false
var _age: float = 0.0
var _hit: Dictionary = {}
var _spin: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3 # Terreno (1) y enemigos (2)
	monitoring = true
	monitorable = false
	z_index = 6
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 16.0
	shape_node.shape = circle
	add_child(shape_node)


## Lo llama el ThrowableManager. La velocidad solo aporta la dirección: el boomerang no sigue una parábola.
func launch(origin: Vector2, initial_velocity: Vector2, p_thrower: Node2D) -> void:
	global_position = origin
	thrower = p_thrower
	if initial_velocity.length_squared() > 1.0:
		_direction = initial_velocity.normalized()
	elif thrower != null and "facing_direction" in thrower:
		_direction = Vector2(float(thrower.facing_direction), 0.0)


func _physics_process(delta: float) -> void:
	_age += delta
	_spin += delta * 18.0
	if _age >= max_lifetime or thrower == null or not is_instance_valid(thrower):
		queue_free()
		return

	var target_point: Vector2 = thrower.global_position + Vector2(0.0, -32.0)
	if _returning:
		var to_player: Vector2 = target_point - global_position
		if to_player.length() <= catch_distance:
			_caught()
			return
		_move_dir = to_player.normalized()
		global_position += _move_dir * return_speed * delta
	else:
		# Frena de a poco hasta el final de la ida
		var left: float = clampf(1.0 - _traveled / reach, 0.0, 1.0)
		var step: float = maxf(out_speed * (0.35 + 0.65 * left), 120.0) * delta
		_move_dir = _direction
		global_position += _direction * step
		_traveled += step
		if _traveled >= reach:
			_start_return()

	_strike_overlaps()
	queue_redraw()


func _start_return() -> void:
	if _returning:
		return
	_returning = true
	_hit.clear() # En la vuelta vuelve a golpear a los mismos enemigos


func _strike_overlaps() -> void:
	if not _returning:
		for body: Node2D in get_overlapping_bodies():
			if body is StaticBody2D:
				_start_return()
				break
	for target: Node2D in ThrowableUtil.collect_hostile_targets(self):
		if not is_instance_valid(target):
			continue
		var key: int = target.get_instance_id()
		if _hit.has(key):
			continue
		_hit[key] = true
		var payload: HitPayload = HitPayload.new(damage, knockback_force, _move_dir, thrower, [], 1, 0.0, 0.0)
		ThrowableUtil.deliver_hit(target, payload)
		SfxScript.play(self, &"hit_blade", global_position, -6.0, 1.1)


func _caught() -> void:
	var manager: Node = thrower.get_node_or_null("ThrowableManager") if thrower != null else null
	if manager != null and "cooldown_left" in manager:
		manager.cooldown_left = minf(float(manager.cooldown_left), cooldown_after_catch)
	SfxScript.play(self, &"pickup_gear", global_position, -6.0, 1.2)
	queue_free()


func _draw() -> void:
	# Dos aspas en ángulo que giran
	var color: Color = Color(0.75, 0.55, 0.3, 1.0)
	var rim: Color = Color(1.0, 0.85, 0.55, 1.0)
	var tip: Vector2 = Vector2(cos(_spin), sin(_spin)) * 14.0
	var wing: Vector2 = Vector2(cos(_spin + 1.3), sin(_spin + 1.3)) * 14.0
	draw_line(Vector2.ZERO, tip, color, 5.0)
	draw_line(Vector2.ZERO, wing, color, 5.0)
	draw_line(Vector2.ZERO, tip, rim, 1.5)
	draw_line(Vector2.ZERO, wing, rim, 1.5)
