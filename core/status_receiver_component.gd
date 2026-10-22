class_name StatusReceiverComponent
extends Node
## Componente receptor y procesador de estados alterados (Fuego con DoT/Stacking y Hielo con Slow).
## Gestiona temporizadores, acumulación progresiva de stacks, alteración de tintes visuales
## y aplicación periódica de daño por fuego sin interferir con la ralentización del hielo.

const CharmControllerScript = preload("res://entities/enemies/charm_controller.gd")

signal burn_stacks_changed(stacks: int, max_stacks: int)
signal burn_expired
signal frozen_state_changed(is_frozen: bool)
signal stunned_state_changed(is_stunned: bool)
signal rooted_state_changed(is_rooted: bool)

const FireVfxScript = preload("res://combat/fire_vfx.gd")

@export_group("Fuego (Burn / DoT)")
@export var max_burn_stacks: int = 10
@export var burn_duration: float = 3.0
@export var burn_tick_interval: float = 0.5
@export var base_burn_tick_damage: float = 3.0

@export_group("Veneno (VENOM)")
@export var max_venom_stacks: int = 5
@export var venom_duration: float = 4.0
@export var venom_tick_interval: float = 0.5
@export var venom_tick_damage: float = 3.0

@export_group("Hielo (Freeze / Slow)")
@export var slow_duration: float = 2.5
@export var slow_multiplier: float = 0.5

@export_group("Arraigo (Root)")
@export var default_root_duration: float = 2.0

@export_group("Referencias")
@export var health_component: HealthComponent
@export var visual_node: CanvasItem
@export var damage_number_scene: PackedScene = preload("res://combat/damage_number.tscn")

# Estado de Fuego
var burn_stacks: int = 0
var burn_timer: float = 0.0
var burn_tick_timer: float = 0.0
# Llama visible sobre la entidad mientras arde (se crea al prenderse y se libera al apagarse)
var _burn_flames: Array[Node2D] = []

# Estado de Hielo
var is_frozen: bool = false
var slow_timer: float = 0.0
var _active_slow_multiplier: float = 0.5

# Estado de Aturdimiento (Stun)
var stun_timer: float = 0.0
var venom_stacks: int = 0
var _venom_timer: float = 0.0
var _venom_tick: float = 0.0
## Hechizo (dardos): el enemigo pelea contra los suyos mientras dura (ver charm_controller.gd).
var is_charmed: bool = false
var is_stunned: bool = false

# Estado de Arraigo (Root): no se mueve, pero puede atacar y recibir daño
var root_timer: float = 0.0
var is_rooted: bool = false

# Caché de color original para restauraciones
var original_color: Color = Color.WHITE
var _has_stored_color: bool = false


func _ready() -> void:
	_ensure_references()
	if visual_node != null and not _has_stored_color:
		original_color = _get_current_visual_color()
		_has_stored_color = true


func _ensure_references() -> void:
	if health_component == null:
		health_component = get_node_or_null("../HealthComponent") as HealthComponent
	if visual_node == null:
		visual_node = get_node_or_null("../Visuals/ColorRect") as CanvasItem
		if visual_node == null:
			visual_node = get_node_or_null("../VisualRect") as CanvasItem


func _physics_process(delta: float) -> void:
	# Lo normal: ningún estado activo (cuatro llamadas por enemigo y por cuadro que no hacen nada)
	if burn_stacks <= 0 and not is_frozen and not is_stunned and stun_timer <= 0.0 and not is_rooted and venom_stacks <= 0:
		return
	_process_venom_status(delta)
	_process_fire_status(delta)
	_process_ice_status(delta)
	_process_stun_status(delta)
	_process_root_status(delta)


## Procesa la cuenta regresiva del fuego y los ciclos periódicos de daño (DoT).
func _process_fire_status(delta: float) -> void:
	if burn_stacks <= 0:
		return
	
	burn_timer -= delta
	burn_tick_timer -= delta
	
	if burn_tick_timer <= 0.0:
		burn_tick_timer = burn_tick_interval
		_trigger_burn_tick()
	
	if burn_timer <= 0.0:
		burn_stacks = 0
		burn_timer = 0.0
		burn_tick_timer = 0.0
		_remove_burn_vfx()
		burn_expired.emit()
		burn_stacks_changed.emit(0, max_burn_stacks)
		_update_visual_tint()


## Procesa la duración de la ralentización por hielo.
func _process_ice_status(delta: float) -> void:
	if not is_frozen:
		return
	
	slow_timer -= delta
	if slow_timer <= 0.0:
		is_frozen = false
		slow_timer = 0.0
		frozen_state_changed.emit(false)
		_update_visual_tint()


## Procesa la duración del aturdimiento e inmoviliza horizontalmente a la entidad.
func _process_stun_status(delta: float) -> void:
	if stun_timer <= 0.0:
		if is_stunned:
			is_stunned = false
			stunned_state_changed.emit(false)
			_update_visual_tint()
		return

	is_stunned = true
	stun_timer = maxf(0.0, stun_timer - delta)

	# Inmovilizar horizontalmente y cancelar ciclos de persecución en la entidad propietaria
	var host: Node = owner if owner != null else get_parent()
	if host != null and is_instance_valid(host):
		if "velocity" in host:
			host.velocity.x = 0.0
		if "is_aggroed" in host:
			host.is_aggroed = false
		if "is_aiming" in host:
			host.is_aiming = false

	if stun_timer <= 0.0:
		is_stunned = false
		stunned_state_changed.emit(false)
		_update_visual_tint()


## Procesa la duración del arraigo y mantiene quieta a la entidad (sin tocar su agro ni sus ataques).
func _process_root_status(delta: float) -> void:
	if not is_rooted:
		return
	root_timer -= delta
	var host: Node = owner if owner != null else get_parent()
	if host != null and is_instance_valid(host) and "velocity" in host:
		host.velocity.x = 0.0
	if root_timer <= 0.0:
		is_rooted = false
		root_timer = 0.0
		rooted_state_changed.emit(false)
		_update_visual_tint()


## Procesa un HitPayload entrante aplicando fuego, hielo o aturdimiento según sus status_effects.
func apply_payload(payload: HitPayload) -> void:
	if payload == null:
		return
	
	if payload.base_tick_damage > 0.0:
		base_burn_tick_damage = payload.base_tick_damage
	
	for effect in payload.status_effects:
		match effect.to_upper():
			"FIRE", "BURN":
				var stacks: int = maxi(1, payload.status_stacks_to_apply)
				apply_fire(stacks)
			"ICE", "FREEZE", "SLOW":
				apply_ice(payload.ice_duration, payload.ice_speed_multiplier)
			"ROOT":
				# La duración viaja en ice_duration (0 = valor por defecto del receptor)
				apply_root(payload.ice_duration)
			"VENOM":
				apply_venom(maxi(1, payload.status_stacks_to_apply))
			"CHARM":
				apply_charm(payload.ice_duration if payload.ice_duration > 0.0 else 6.0)
			"STUN":
				# Duración: ice_duration si el arma la define (Llave Stillson) y no congela; si no,
				# base_tick_damage o 1.5 s por defecto
				var dur: float = payload.base_tick_damage if payload.base_tick_damage > 0.0 else 1.5
				if payload.ice_duration > 0.0 and not payload.status_effects.has("ICE"):
					dur = payload.ice_duration
				apply_stun(dur)


## Suma stacks de veneno (dardos venenosos): daño por tick = venom_tick_damage * stacks, se renueva con cada dardo.
func apply_venom(stacks: int = 1) -> void:
	venom_stacks = mini(max_venom_stacks, venom_stacks + stacks)
	_venom_timer = venom_duration
	if _venom_tick <= 0.0:
		_venom_tick = venom_tick_interval
	_update_visual_tint()


func _process_venom_status(delta: float) -> void:
	if venom_stacks <= 0:
		return
	_venom_timer -= delta
	_venom_tick -= delta
	if _venom_tick <= 0.0:
		_venom_tick = venom_tick_interval
		var tick_damage: float = venom_tick_damage * float(venom_stacks)
		if health_component != null and is_instance_valid(health_component):
			health_component.apply_damage(tick_damage, false, "VENOM_DOT")
		_spawn_damage_number(tick_damage, "VENOM")
	if _venom_timer <= 0.0:
		venom_stacks = 0
		_update_visual_tint()


## Hechiza al enemigo por `duration` s: un CharmController toma su control y lo hace pelear contra los suyos.
## Los jefes no se dejan.
func apply_charm(duration: float) -> void:
	var host: Node = owner if owner != null else get_parent()
	if host == null or not (host is CharacterBody2D) or host.is_in_group(&"boss"):
		return
	var controller: Node = host.get_node_or_null("CharmController")
	if controller == null:
		controller = CharmControllerScript.new()
		controller.name = "CharmController"
		host.add_child(controller)
	controller.call("start", duration)


## Aplica o renueva el estado de aturdimiento (STUN).
func apply_stun(duration: float) -> void:
	if duration <= 0.0:
		return
	stun_timer = maxf(stun_timer, duration)
	var was_stunned: bool = is_stunned
	is_stunned = true
	
	# Inmovilización inmediata
	var host: Node = owner if owner != null else get_parent()
	if host != null and is_instance_valid(host):
		if "velocity" in host:
			host.velocity.x = 0.0
		if "is_aggroed" in host:
			host.is_aggroed = false
		if "is_aiming" in host:
			host.is_aiming = false
	
	if not was_stunned:
		stunned_state_changed.emit(true)
	_update_visual_tint()


## Aplica o renueva el arraigo: la entidad no puede desplazarse mientras dura.
func apply_root(duration: float = 0.0) -> void:
	var dur: float = duration if duration > 0.0 else default_root_duration
	root_timer = maxf(root_timer, dur)
	var was_rooted: bool = is_rooted
	is_rooted = true
	if not was_rooted:
		rooted_state_changed.emit(true)
	_update_visual_tint()


## Aplica o renueva el estado de quemadura sumando stacks hasta el límite máximo.
func apply_fire(stacks: int = 1) -> void:
	burn_stacks = mini(max_burn_stacks, burn_stacks + stacks)
	burn_timer = burn_duration # Reinicia a 3.0s

	if burn_tick_timer <= 0.0:
		burn_tick_timer = burn_tick_interval

	_ensure_burn_vfx()
	burn_stacks_changed.emit(burn_stacks, max_burn_stacks)
	_update_visual_tint()


## Llamitas sobre el cuerpo: una por stack de fuego, hasta MAX_VISIBLE_FLAMES, repartidas por el cuerpo.
const MAX_VISIBLE_FLAMES: int = 6
## Posición de cada llama como fracción del cuerpo (x: -0.5 a 0.5 desde el centro, y: 0 arriba a 1 en los pies).
const FLAME_SLOTS: Array[Vector2] = [
	Vector2(0.0, 0.55), Vector2(-0.28, 0.25), Vector2(0.28, 0.8),
	Vector2(0.3, 0.3), Vector2(-0.3, 0.75), Vector2(0.0, 0.05),
]


func _ensure_burn_vfx() -> void:
	var host: Node2D = owner as Node2D
	if host == null:
		host = get_parent() as Node2D
	if host == null:
		return
	var wanted: int = mini(burn_stacks, MAX_VISIBLE_FLAMES)
	while _burn_flames.size() > wanted:
		var extra: Node2D = _burn_flames.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()
	var body: Rect2 = _body_rect(host)
	var flame_width: float = clampf(body.size.y * 0.3, 10.0, 20.0)
	while _burn_flames.size() < wanted:
		var flame: Node2D = FireVfxScript.make("burn", flame_width, true)
		flame.z_index = 6
		host.add_child(flame)
		_burn_flames.append(flame)
	for i in range(_burn_flames.size()):
		var slot: Vector2 = FLAME_SLOTS[i]
		# La base de la llama apoya en el punto: el slot marca dónde queda el pie de la llama
		_burn_flames[i].position = body.position + Vector2(body.size.x * (0.5 + slot.x), body.size.y * slot.y + flame_width * 0.5)


## Rectángulo del cuerpo (colisión) en coordenadas locales del enemigo.
func _body_rect(host: Node2D) -> Rect2:
	var shape_node: CollisionShape2D = host.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is RectangleShape2D:
		var size: Vector2 = (shape_node.shape as RectangleShape2D).size
		return Rect2(shape_node.position - size * 0.5, size)
	return Rect2(-10.0, -34.0, 20.0, 34.0)


func _remove_burn_vfx() -> void:
	for flame: Node2D in _burn_flames:
		if is_instance_valid(flame):
			flame.queue_free()
	_burn_flames.clear()


## Aplica o renueva la ralentización por congelamiento.
## Si se indican valores > 0, sobrescriben duración y multiplicador de velocidad por defecto.
func apply_ice(duration_override: float = 0.0, speed_multiplier_override: float = 0.0) -> void:
	is_frozen = true
	slow_timer = duration_override if duration_override > 0.0 else slow_duration # 2.5s por defecto
	_active_slow_multiplier = speed_multiplier_override if speed_multiplier_override > 0.0 else slow_multiplier
	frozen_state_changed.emit(true)
	_update_visual_tint()


## Ejecuta el tick periódico de daño por fuego (daño = base_burn_tick_damage * burn_stacks).
func _trigger_burn_tick() -> void:
	if burn_stacks <= 0:
		return
	
	var tick_damage: float = base_burn_tick_damage * float(burn_stacks)
	
	# Aplicar el daño al componente de salud o entidad
	if health_component != null and is_instance_valid(health_component):
		health_component.apply_damage(tick_damage, false, "FIRE_DOT")
	elif owner != null and "total_damage_received" in owner:
		owner.total_damage_received += tick_damage
	
	# Generar número de daño flotante en color naranja
	_spawn_damage_number(tick_damage, "FIRE")


## Genera la escena de número flotante estilizada según el elemento.
func _spawn_damage_number(amount: float, damage_type: String) -> void:
	if damage_number_scene == null or not is_inside_tree():
		return
	
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	
	var dmg_inst: Node = damage_number_scene.instantiate()
	if dmg_inst is DamageNumber:
		var dmg_num: DamageNumber = dmg_inst as DamageNumber
		var spawn_pos: Vector2 = (owner as Node2D).global_position if owner is Node2D else (get_parent() as Node2D).global_position
		dmg_num.global_position = spawn_pos + Vector2(randf_range(-10.0, 10.0), -52.0)
		
		var container: Node = tree.current_scene
		if container == null:
			container = owner if owner != null else get_parent()
		if container == null:
			container = tree.root
		if container != null:
			container.add_child(dmg_num)
			dmg_num.setup(amount, false, damage_type)


## Retorna el multiplicador de velocidad actual (0.0 si está aturdido, 0.5/override si está congelado, 1.0 si es normal).
func get_speed_multiplier() -> float:
	if is_stunned or is_rooted:
		return 0.0
	return _active_slow_multiplier if is_frozen else 1.0


## Actualiza el tinte cromático del nodo visual según los estados activos y su combinación.
func _update_visual_tint() -> void:
	if visual_node == null:
		_ensure_references()
	if visual_node == null:
		return
	
	if not _has_stored_color:
		original_color = _get_current_visual_color()
		_has_stored_color = true
	
	if is_stunned:
		# Aturdimiento prioritario: Tinte amarillo/blanco eléctrico brillante
		var stun_tint: Color = Color(1.2, 1.15, 0.4, 1.0)
		_set_current_visual_color(original_color.lerp(stun_tint, 0.75))
	elif is_charmed:
		# Hechizado: rosa brillante, para distinguirlo de los que te siguen atacando
		_set_current_visual_color(original_color.lerp(Color(1.0, 0.45, 0.95, 1.0), 0.6))
	elif venom_stacks > 0 and burn_stacks <= 0:
		# Envenenado: verde ácido
		_set_current_visual_color(original_color.lerp(Color(0.45, 1.0, 0.3, 1.0), 0.35 + 0.06 * float(venom_stacks)))
	elif burn_stacks > 0 and is_frozen:
		# Convivencia simultánea Fuego + Hielo: Tono intermedio violeta / magenta ígneo-gélido
		var mixed_tint: Color = Color(0.85, 0.3, 0.85, 1.0)
		_set_current_visual_color(original_color.lerp(mixed_tint, 0.65))
	elif burn_stacks > 0:
		# Fuego activo: Tono naranja / rojizo proporcional a los stacks
		var fire_tint: Color = Color(1.0, 0.35, 0.1, 1.0)
		var factor: float = clampf(0.35 + (float(burn_stacks) / float(max_burn_stacks)) * 0.35, 0.35, 0.70)
		_set_current_visual_color(original_color.lerp(fire_tint, factor))
	elif is_frozen:
		# Hielo activo: Tono cian / celeste helado
		var ice_tint: Color = Color(0.25, 0.75, 1.0, 1.0)
		_set_current_visual_color(original_color.lerp(ice_tint, 0.60))
	elif is_rooted:
		# Arraigado: Tono verde terroso
		var root_tint: Color = Color(0.45, 0.8, 0.3, 1.0)
		_set_current_visual_color(original_color.lerp(root_tint, 0.55))
	else:
		# Sin estados alterados: Restaurar color base original
		_set_current_visual_color(original_color)


func _get_current_visual_color() -> Color:
	if visual_node == null:
		return Color.WHITE
	if "color" in visual_node:
		return visual_node.color
	return visual_node.modulate


func _set_current_visual_color(c: Color) -> void:
	if visual_node == null:
		return
	if "color" in visual_node:
		visual_node.color = c
	else:
		visual_node.modulate = c


## Limpia todos los estados activos y restaura valores base.
func clear_all() -> void:
	burn_stacks = 0
	burn_timer = 0.0
	burn_tick_timer = 0.0
	_remove_burn_vfx()
	is_frozen = false
	slow_timer = 0.0
	is_stunned = false
	stun_timer = 0.0
	is_rooted = false
	root_timer = 0.0
	_update_visual_tint()
