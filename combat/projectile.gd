class_name Projectile
extends Area2D
## Proyectil cinético 2D que avanza en base a su rotación transportando un HitPayload.
## Diseñado para trabajar con ProjectilePool y el Sistema de Runas (Rebote, Perforación, Bifurcación).

const ShotFx = preload("res://combat/shot_fx.gd")

@export var speed: float = 520.0
@export var max_lifetime: float = 3.0
@export var is_hostile: bool = false

var payload: HitPayload = null
var current_lifetime: float = 0.0
var _has_impacted: bool = false
var is_parried: bool = false
var pool: Node = null

# Contadores de modificadores de Runas
var bounces_left: int = 0
var pierces_left: int = 0
var forks_left: int = 0
var _pierced_targets: Array[Node] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_update_appearance()


## Reinicia el estado interno del proyectil al ser activado por el pool.
func reset_state() -> void:
	current_lifetime = 0.0
	_has_impacted = false
	is_parried = false
	is_hostile = false
	_pierced_targets.clear()
	visible = true
	modulate = Color.WHITE
	collision_layer = 4
	collision_mask = 3
	set_physics_process(true)
	_update_appearance()


## Desvía el proyectil balísticamente en sentido opuesto, amplificando su daño y asignando nuevo dueño.
func deflect(new_source: Node2D, damage_multiplier: float = 1.5) -> void:
	is_parried = true
	is_hostile = false
	current_lifetime = 0.0
	rotation += PI
	
	if payload != null:
		payload.source_node = new_source
		payload.knockback_direction = -payload.knockback_direction
		payload.base_damage *= damage_multiplier
	
	collision_layer = 4
	collision_mask = 3
	_update_appearance()


func _physics_process(delta: float) -> void:
	# Movimiento en base a la rotación local (eje X transformado)
	global_position += transform.x * speed * delta
	
	current_lifetime += delta
	if current_lifetime >= max_lifetime:
		recycle()


## Inicializa la velocidad, payload de combate y parámetros de Runas (rebotes, perforación, bifurcación).
func setup(
	p_speed: float,
	p_payload: HitPayload,
	p_bounces: int = 0,
	p_pierces: int = 0,
	p_forks: int = 0
) -> void:
	speed = p_speed
	payload = p_payload
	bounces_left = p_bounces
	pierces_left = p_pierces
	forks_left = p_forks
	reset_state()
	_update_appearance()


func _on_body_entered(body: Node2D) -> void:
	_handle_collision(body)


func _on_area_entered(area: Area2D) -> void:
	_handle_collision(area)


## Evalúa el impacto contra una entidad receptora de daño o geometría estática del mundo.
func _handle_collision(target: Node) -> void:
	if _has_impacted:
		return
	
	# Evitar autodaño con el nodo emisor
	if payload != null and payload.source_node != null and (target == payload.source_node or target.get_parent() == payload.source_node):
		return
	
	# 1. Comprobar si impactó con geometría sólida del mundo (pared/piso/techo)
	if target is StaticBody2D or target is TileMap or target.is_in_group("world"):
		GameFeel.sfx(self, &"hit_world", global_position, -10.0)
		var normal: Vector2 = _get_bounce_normal()
		ShotFx.wall_impact(self, global_position, normal, ShotFx.COLD if is_parried else ShotFx.WARM)
		if bounces_left > 0:
			bounces_left -= 1
			var new_dir: Vector2 = transform.x.bounce(normal).normalized()
			if new_dir == Vector2.ZERO:
				new_dir = -transform.x
			rotation = new_dir.angle()
			global_position += transform.x * 6.0 # Despegar del muro
			_spawn_impact_fx(global_position)
			return
		else:
			_has_impacted = true
			set_physics_process(false)
			call_deferred("recycle")
			return
	
	# 2. Buscar receptor de daño (enemigos / dummies)
	var receiver: Node = target
	if not receiver.has_method("take_hit"):
		var parent: Node = target.get_parent()
		if parent != null and parent.has_method("take_hit"):
			receiver = parent
	
	if receiver != null and receiver.has_method("take_hit") and payload != null:
		# Evitar golpear repetidamente al mismo objetivo si está atravesándolo por perforación
		if _pierced_targets.has(receiver):
			return
		# Fuego amigo: un proyectil de aliado (dron) pasa de largo sobre el Jugador y sobre otros aliados
		if _is_friendly_fire(receiver):
			return
		_pierced_targets.append(receiver)
		receiver.take_hit(payload)
		_spawn_impact_fx(global_position)
		
		# Hook de Perforación (Pierce)
		if pierces_left > 0:
			pierces_left -= 1
			return # Continúa volando
		
		# Hook de Bifurcación (Fork)
		if forks_left > 0:
			_execute_fork()
		
		_has_impacted = true
		set_physics_process(false)
		call_deferred("recycle")


## Verdadero si el emisor es un jugador o aliado y el receptor es el Jugador o un aliado.
func _is_friendly_fire(receiver: Node) -> bool:
	var src: Node = payload.source_node
	if src == null or not (src.is_in_group(&"player") or src.is_in_group(&"allies")):
		return false
	return receiver.is_in_group(&"player") or receiver.is_in_group(&"allies")


## Actualiza la paleta visual (Glow, Núcleo y Sprite2D) según el estado elemental, si es hostil o desviado.
func _update_appearance() -> void:
	var sprite_node: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite_node != null:
		# Seleccionar sub-región según el proyectil:
		# 0: Balística estándar [0, 0, 16, 16]
		# 1: Plasma / cian [16, 0, 16, 16]
		# 2: Perdigón [32, 0, 16, 16]
		if payload != null and (payload.status_effects.has("ICE") or payload.status_effects.has("FIRE")):
			sprite_node.region_rect = Rect2(16, 0, 16, 16)
			if payload.status_effects.has("FIRE"):
				sprite_node.modulate = Color(1.0, 0.45, 0.2, 1.0)
			else:
				sprite_node.modulate = Color(0.3, 0.9, 1.0, 1.0)
		elif is_hostile:
			sprite_node.region_rect = Rect2(0, 0, 16, 16)
			sprite_node.modulate = Color(1.0, 0.3, 0.3, 1.0)
		elif is_parried:
			sprite_node.region_rect = Rect2(16, 0, 16, 16)
			sprite_node.modulate = Color(0.2, 1.0, 1.0, 1.0)
		elif speed < 510.0 and payload != null and payload.base_damage <= 15.0:
			# Perdigón de escopeta
			sprite_node.region_rect = Rect2(32, 0, 16, 16)
			sprite_node.modulate = Color.WHITE
		elif bounces_left > 0 or forks_left > 0 or pierces_left > 0:
			sprite_node.region_rect = Rect2(16, 0, 16, 16)
			sprite_node.modulate = Color(0.85, 0.4, 1.0, 1.0) # Púrpura runas
		else:
			sprite_node.region_rect = Rect2(0, 0, 16, 16)
			sprite_node.modulate = Color.WHITE

	var glow: ColorRect = get_node_or_null("Glow") as ColorRect
	var core: ColorRect = get_node_or_null("ColorRect") as ColorRect
	if core == null and glow == null:
		return
	
	if is_hostile:
		if glow != null: glow.color = Color(1.0, 0.15, 0.15, 0.55) # Rojo hostil
		if core != null: core.color = Color(1.0, 0.65, 0.65, 1.0)
	elif is_parried:
		if glow != null: glow.color = Color(0.15, 0.95, 1.0, 0.7) # Cian brillante parry
		if core != null: core.color = Color(0.95, 1.0, 1.0, 1.0)
	elif payload != null and payload.status_effects.has("ICE"):
		if glow != null: glow.color = Color(0.15, 0.75, 1.0, 0.65) # Celeste hielo criogénico
		if core != null: core.color = Color(0.85, 0.95, 1.0, 1.0)
	elif payload != null and payload.status_effects.has("FIRE"):
		if glow != null: glow.color = Color(1.0, 0.35, 0.05, 0.65) # Naranja ígneo
		if core != null: core.color = Color(1.0, 0.92, 0.45, 1.0)
	elif bounces_left > 0 or forks_left > 0 or pierces_left > 0:
		if glow != null: glow.color = Color(0.75, 0.3, 1.0, 0.65) # Púrpura runas arcanas
		if core != null: core.color = Color(0.96, 0.85, 1.0, 1.0)
	else:
		if glow != null: glow.color = Color(1.0, 0.75, 0.15, 0.55) # Ámbar dorado cinético
		if core != null: core.color = Color(1.0, 1.0, 0.88, 1.0)


## Calcula la normal de colisión mediante raycast contra la capa del mundo (Layer 1).
func _get_bounce_normal() -> Vector2:
	if not is_inside_tree():
		return -transform.x
	var tree: SceneTree = get_tree()
	if tree == null:
		return -transform.x
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var move_dir: Vector2 = transform.x
	var from_pos: Vector2 = global_position - move_dir * 16.0
	var to_pos: Vector2 = global_position + move_dir * 28.0
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 1)
	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty() and result.has("normal"):
		return result["normal"]
	return -move_dir


## Divide el proyectil en dos ramas a +/-30° con la mitad del daño base.
func _execute_fork() -> void:
	forks_left -= 1
	var pool_ref: Node = pool
	if pool_ref == null or not is_instance_valid(pool_ref):
		if is_inside_tree() and get_tree() != null:
			pool_ref = get_tree().get_first_node_in_group(&"projectile_pool")
	
	var base_angle: float = rotation
	var angles: Array[float] = [base_angle + deg_to_rad(30.0), base_angle - deg_to_rad(30.0)]
	
	for fork_ang in angles:
		var fork_dir: Vector2 = Vector2.from_angle(fork_ang)
		var fork_payload: HitPayload = payload.duplicate_payload() if payload != null else null
		if fork_payload != null:
			fork_payload.base_damage = payload.base_damage * 0.5
			fork_payload.knockback_direction = fork_dir
		
		if pool_ref != null and pool_ref.has_method("get_projectile"):
			pool_ref.get_projectile(
				global_position,
				fork_dir,
				fork_payload,
				speed,
				bounces_left,
				pierces_left,
				0 # Los proyectiles hijos no bifurcan en cascada infinita
			)
		else:
			# Fallback de reserva si no existe pool
			var container: Node = get_parent()
			if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
				container = get_tree().current_scene
			if container != null:
				var scene_res: PackedScene = load("res://combat/projectile.tscn")
				if scene_res != null:
					var child_proj: Projectile = scene_res.instantiate() as Projectile
					container.add_child(child_proj)
					child_proj.global_position = global_position
					child_proj.rotation = fork_ang
					child_proj.setup(speed, fork_payload, bounces_left, pierces_left, 0)



## Genera un efecto visual sutil de impacto / chispas en el punto de contacto.
func _spawn_impact_fx(pos: Vector2) -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var spark: Node2D = Node2D.new()
	spark.global_position = pos
	var rect: ColorRect = ColorRect.new()
	rect.custom_minimum_size = Vector2(8, 8)
	rect.offset_left = -4.0
	rect.offset_top = -4.0
	rect.offset_right = 4.0
	rect.offset_bottom = 4.0
	rect.color = Color(1.0, 0.9, 0.4, 0.9)
	spark.add_child(rect)
	
	var container: Node = tree.current_scene
	if container == null:
		container = get_parent()
	if container != null:
		container.add_child(spark)
		var tw: Tween = spark.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "scale", Vector2(1.8, 1.8), 0.08)
		tw.tween_property(rect, "modulate:a", 0.0, 0.08)
		tw.finished.connect(spark.queue_free)


## Devuelve el proyectil al pool de reserva desactivándolo sin destruir la instancia.
func recycle() -> void:
	_has_impacted = false
	current_lifetime = 0.0
	payload = null
	speed = 0.0
	bounces_left = 0
	pierces_left = 0
	forks_left = 0
	_pierced_targets.clear()
	set_physics_process(false)
	visible = false
	
	if pool != null and is_instance_valid(pool) and pool.has_method("recycle_projectile"):
		pool.recycle_projectile(self)
	else:
		# Fallback de seguridad si fue instanciado manualmente fuera del pool
		visible = false
		set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
