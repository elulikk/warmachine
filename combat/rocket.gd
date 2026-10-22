extends Projectile
## Cohete de bazuca: acelera, deja estela de humo y estalla (`impact_scene` del arma) al chocar o al agotar su vida.
## `guided` = bazuca dirigida: el cohete gira hacia el cursor a `turn_rate` rad/s (con mando sigue derecho).

@export var guided: bool = false
@export var turn_rate: float = 3.4
@export var acceleration: float = 900.0
@export var max_speed: float = 980.0
@export var trail_interval: float = 0.04
@export var smoke_trail: bool = true
## Busca solo al enemigo más cercano (Gungnir, la lanza que nunca falla).
@export var homing_enemies: bool = false
@export var homing_range: float = 900.0

var _homing_target: Node2D = null
var _retarget_left: float = 0.0

var _trail_left: float = 0.0


func _physics_process(delta: float) -> void:
	if guided:
		_steer(delta)
	elif homing_enemies:
		_home(delta)
	speed = minf(max_speed, speed + acceleration * delta)
	_trail_left -= delta
	if smoke_trail and _trail_left <= 0.0:
		_trail_left = trail_interval
		ShotFx.muzzle_smoke(self, global_position - transform.x * 10.0, -transform.x)
	# Sin blanco al final de su vida: estalla igual, en el aire
	if current_lifetime + delta >= max_lifetime and not _has_impacted:
		_has_impacted = true
		set_physics_process(false)
		_spawn_impact_scene()
		call_deferred("recycle")
		return
	super._physics_process(delta)


func _steer(delta: float) -> void:
	var to_target: Vector2 = get_global_mouse_position() - global_position
	if to_target.length() < 14.0:
		return
	rotation = rotate_toward(rotation, to_target.angle(), turn_rate * delta)


func _home(delta: float) -> void:
	_retarget_left -= delta
	if _retarget_left <= 0.0 or _homing_target == null or not is_instance_valid(_homing_target) \
			or _homing_target.get("is_dead") == true:
		_retarget_left = 0.2
		_homing_target = _nearest_enemy()
	if _homing_target == null:
		return
	var to_target: Vector2 = _homing_target.global_position + Vector2(0.0, -28.0) - global_position
	rotation = rotate_toward(rotation, to_target.angle(), turn_rate * delta)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist: float = homing_range
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or enemy.get("is_dead") == true or enemy.is_in_group(&"charmed") or _pierced_targets.has(enemy):
			continue
		var dist: float = enemy.global_position.distance_to(global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best
