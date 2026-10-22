extends Projectile
## Hacha Leviatán: vuela girando, se frena y vuelve sola a la mano. Atraviesa a todos los enemigos a la ida y
## a la vuelta (los puede golpear dos veces) y aplica los estados del arma (hielo).
## Si choca una pared a la ida empieza a volver; a la vuelta atraviesa el terreno.

@export var out_time: float = 0.42
@export var return_speed: float = 780.0
@export var spin_speed: float = 22.0
## Tope de vida por si el dueño desaparece.
@export var max_flight: float = 4.0

var _returning: bool = false
var _flight: float = 0.0


func _physics_process(delta: float) -> void:
	_flight += delta
	var sprite: Node2D = get_node_or_null("Sprite2D") as Node2D
	if sprite != null:
		sprite.rotation += spin_speed * delta
	var owner_node: Node2D = payload.source_node if payload != null else null
	if _flight >= max_flight or owner_node == null or not is_instance_valid(owner_node):
		_finish()
		return
	if not _returning:
		speed = maxf(140.0, speed - speed * 2.4 * delta)
		if _flight >= out_time:
			_start_return()
	else:
		var to_hand: Vector2 = owner_node.global_position + Vector2(0.0, -40.0) - global_position
		if to_hand.length() < 30.0:
			GameFeel.sfx(self, &"axe_catch", global_position, -3.0)
			_finish()
			return
		rotation = to_hand.angle()
		speed = minf(return_speed * 1.6, speed + return_speed * 3.0 * delta)
	global_position += transform.x * speed * delta


func _start_return() -> void:
	_returning = true
	# A la vuelta puede volver a cortar a los mismos
	_pierced_targets.clear()
	speed = 220.0


func _handle_collision(target: Node) -> void:
	if target is StaticBody2D or target is TileMap or target.is_in_group(&"world"):
		if not _returning:
			GameFeel.sfx(self, &"hit_world", global_position, -6.0)
			_start_return()
		return
	# Que la perforación no se acabe nunca: corta a todos los que cruza
	pierces_left = maxi(pierces_left, 99)
	super._handle_collision(target)
	_has_impacted = false
	set_physics_process(true)


func _finish() -> void:
	_has_impacted = true
	set_physics_process(false)
	call_deferred("recycle")
