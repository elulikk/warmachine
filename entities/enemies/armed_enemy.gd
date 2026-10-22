extends "res://entities/enemies/basic_runner.gd"
## Enemigo humano armado del presente (asaltante, sicarios, Agente del Tiempo).
## Hereda vida, botín, parpadeo y muerte del corredor, pero mantiene la distancia y dispara
## proyectiles hostiles en vez de embestir. El arte lo pone `art_kind` (ver enemy_art.gd).

@export_enum("pistol", "shotgun", "smg") var gun: String = "pistol"
@export var shot_damage: float = 8.0
@export var fire_interval: float = 1.8
@export var shoot_range: float = 460.0
## Si el jugador se acerca más que esto, retrocede; si está más lejos que `keep_distance + 90`, avanza.
@export var keep_distance: float = 200.0
@export var projectile_speed: float = 560.0
## Altura de la boca del arma sobre los pies (con el arte a 1.5x, la pistola queda a ~65 px) y cuánto sale hacia adelante.
@export var muzzle_height: float = 65.0
@export var muzzle_forward: float = 28.0
@export var shot_tint: Color = Color(1.0, 0.75, 0.3, 1.0)

var _fire_timer: float = 0.0
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _facing: float = 1.0


func _ready() -> void:
	melee_enabled = false # solo dispara; tocarlo no lastima
	super._ready()
	_fire_timer = randf_range(0.4, fire_interval)


func _physics_process(delta: float) -> void:
	delta = FarStepScript.delta_for(self, delta)
	if delta <= 0.0:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group(&"player") as Player

	var stunned: bool = status_receiver != null and status_receiver.is_stunned
	var speed: float = move_speed
	if status_receiver != null:
		speed *= status_receiver.get_speed_multiplier()
	speed *= ZoneModifierManager.get_world_mult("enemy_speed_mult", 1.0)

	var want_x: float = 0.0
	if target_player != null and is_instance_valid(target_player) and not stunned:
		var diff_x: float = target_player.global_position.x - global_position.x
		var dist: float = absf(diff_x)
		if target_player.is_invisible:
			is_aggroed = false
		elif dist <= maxf(aggro_range, shoot_range):
			is_aggroed = true
		elif is_aggroed and AggroLeash.should_drop(self, dist, maxf(aggro_range, shoot_range)):
			is_aggroed = false
		if is_aggroed:
			_facing = signf(diff_x) if dist > 4.0 else _facing
			if visuals != null:
				visuals.scale.x = _facing
			if dist < keep_distance * 0.7:
				want_x = -_facing * speed * 0.8
			elif dist > keep_distance + 90.0:
				want_x = _facing * speed
			if dist <= shoot_range:
				_update_fire(delta)
	velocity.x = move_toward(velocity.x, want_x, CHASE_ACCEL * delta)
	if contact_cooldown > 0.0:
		contact_cooldown = maxf(0.0, contact_cooldown - delta)
	HopScript.try_hop(self, signf(velocity.x))
	move_and_slide()


func _update_fire(delta: float) -> void:
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_shoot_one(0.07)
			_burst_left -= 1
			_burst_timer = 0.08
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = fire_interval * randf_range(0.85, 1.2)
	match gun:
		"shotgun":
			for i in range(5):
				_shoot_one(0.12, -0.2 + 0.1 * float(i), 0.45)
			contact_cooldown = 1.0 # dispara la animación de ataque del arte
		"smg":
			_burst_left = 4
			_burst_timer = 0.0
		_:
			_shoot_one(0.04)


## Apunta al centro del cuerpo en la postura actual: si el jugador se agacha o se tira al piso, los tiros en vuelo pasan por encima.
func _aim_point(target: Node2D) -> Vector2:
	if target.has_method("get_body_center"):
		return target.call("get_body_center") as Vector2
	return target.global_position + Vector2(0.0, -30.0)


## Un disparo hacia el jugador. `spread` = dispersión aleatoria (rad), `fixed_angle` = desvío fijo, `dmg_mult` = fracción del daño.
func _shoot_one(spread: float, fixed_angle: float = 0.0, dmg_mult: float = 1.0) -> void:
	if target_player == null or not is_instance_valid(target_player) or not is_inside_tree():
		return
	var origin: Vector2 = global_position + Vector2(_facing * muzzle_forward, -muzzle_height)
	var aim: Vector2 = _aim_point(target_player) - origin
	var angle: float = aim.angle() + fixed_angle + randf_range(-spread, spread)
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var payload: HitPayload = HitPayload.new(shot_damage * dmg_mult, 90.0, dir, self, [], 1, 3.0, 0.0)
	var proj_scene: PackedScene = preload("res://combat/projectile.tscn")
	var proj: Projectile = proj_scene.instantiate() as Projectile
	proj.global_position = origin
	proj.rotation = dir.angle()
	proj.setup(projectile_speed, payload)
	proj.is_hostile = true
	proj.modulate = shot_tint
	var container: Node = get_tree().current_scene
	if container == null:
		container = get_parent()
	container.add_child(proj)
	var sound: StringName = &"shot_shotgun" if gun == "shotgun" else &"shot_enemy_gun"
	GameFeel.sfx(self, sound, origin, -8.0, randf_range(0.9, 1.1))
