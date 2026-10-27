class_name ProjectilePool
extends Node
## Gestor de reserva y reciclaje continuo de proyectiles (Object Pooling).
## Preinstancia balas al arrancar y las reutiliza dinámicamente eliminando
## las interrupciones del recolector de basura (garbage collection).

signal projectile_spawned(projectile: Projectile)
signal projectile_recycled(projectile: Projectile)

@export var projectile_scene: PackedScene = preload("res://combat/projectile.tscn")
@export var initial_pool_size: int = 60

var _pool: Array[Projectile] = []
## Proyectiles en reposo listos para usar (el más recientemente devuelto sale primero).
var _free: Array[Projectile] = []


func _ready() -> void:
	add_to_group(&"projectile_pool")
	_initialize_pool()


func _initialize_pool() -> void:
	if projectile_scene == null:
		return
	
	for i in range(initial_pool_size):
		var proj: Projectile = _create_new_projectile()
		_deactivate_projectile(proj)
		_pool.append(proj)
		_free.append(proj)


func _create_new_projectile() -> Projectile:
	var node: Node = projectile_scene.instantiate()
	var proj: Projectile = node as Projectile
	proj.pool = self
	add_child(proj)
	return proj


## Extrae una bala inactiva de la reserva o instancia una de soporte si está agotada.
func get_projectile(
	global_pos: Vector2,
	direction: Vector2,
	payload: HitPayload,
	speed: float = 520.0,
	bounces: int = 0,
	pierces: int = 0,
	forks: int = 0,
	sprite: Texture2D = null
) -> Node2D:
	var proj: Projectile = null
	
	# Sacar de la lista de libres (los liberados por cambio de escena se descartan)
	while not _free.is_empty():
		var candidate: Variant = _free.pop_back()
		if is_instance_valid(candidate) and (candidate as Projectile).process_mode == Node.PROCESS_MODE_DISABLED:
			proj = candidate as Projectile
			break
	
	# Si la reserva se agotó por ráfagas intensas, instanciar uno de soporte adicional
	if proj == null:
		proj = _create_new_projectile()
		_pool.append(proj)
	
	_activate_projectile(proj, global_pos, direction, payload, speed, bounces, pierces, forks, sprite)
	projectile_spawned.emit(proj)
	return proj


func _activate_projectile(
	proj: Projectile,
	global_pos: Vector2,
	direction: Vector2,
	payload: HitPayload,
	speed: float,
	bounces: int = 0,
	pierces: int = 0,
	forks: int = 0,
	sprite: Texture2D = null
) -> void:
	proj.global_position = global_pos
	proj.rotation = direction.angle()
	proj.setup(speed, payload, bounces, pierces, forks, sprite)
	proj.visible = true
	proj.process_mode = Node.PROCESS_MODE_INHERIT
	proj.set_deferred("monitoring", true)
	proj.set_deferred("monitorable", true)
	proj.reset_state()


func _deactivate_projectile(proj: Projectile) -> void:
	proj.visible = false
	proj.process_mode = Node.PROCESS_MODE_DISABLED
	proj.set_deferred("monitoring", false)
	proj.set_deferred("monitorable", false)
	proj.set_physics_process(false)




## Devuelve un proyectil al estado de reposo en la reserva.
func recycle_projectile(proj: Projectile) -> void:
	if proj == null:
		return
	# Solo vuelve a la lista de libres si estaba en uso (un reciclaje doble no lo duplica)
	var was_active: bool = proj.process_mode != Node.PROCESS_MODE_DISABLED
	_deactivate_projectile(proj)
	if was_active:
		_free.append(proj)
	projectile_recycled.emit(proj)
