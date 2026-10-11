class_name StatusReceiverComponent
extends Node
## Componente receptor y procesador de estados alterados (Fuego con DoT/Stacking y Hielo con Slow).
## Gestiona temporizadores, acumulación progresiva de stacks, alteración de tintes visuales
## y aplicación periódica de daño por fuego sin interferir con la ralentización del hielo.

signal burn_stacks_changed(stacks: int, max_stacks: int)
signal burn_expired
signal frozen_state_changed(is_frozen: bool)
signal stunned_state_changed(is_stunned: bool)

@export_group("Fuego (Burn / DoT)")
@export var max_burn_stacks: int = 10
@export var burn_duration: float = 3.0
@export var burn_tick_interval: float = 0.5
@export var base_burn_tick_damage: float = 3.0

@export_group("Hielo (Freeze / Slow)")
@export var slow_duration: float = 2.5
@export var slow_multiplier: float = 0.5

@export_group("Referencias")
@export var health_component: HealthComponent
@export var visual_node: CanvasItem
@export var damage_number_scene: PackedScene = preload("res://combat/damage_number.tscn")

# Estado de Fuego
var burn_stacks: int = 0
var burn_timer: float = 0.0
var burn_tick_timer: float = 0.0

# Estado de Hielo
var is_frozen: bool = false
var slow_timer: float = 0.0
var _active_slow_multiplier: float = 0.5

# Estado de Aturdimiento (Stun)
var stun_timer: float = 0.0
var is_stunned: bool = false

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
	_process_fire_status(delta)
	_process_ice_status(delta)
	_process_stun_status(delta)


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
			"STUN":
				# Usar base_tick_damage o 1.5s por defecto como duración de stun
				var dur: float = payload.base_tick_damage if payload.base_tick_damage > 0.0 else 1.5
				apply_stun(dur)


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


## Aplica o renueva el estado de quemadura sumando stacks hasta el límite máximo.
func apply_fire(stacks: int = 1) -> void:
	burn_stacks = mini(max_burn_stacks, burn_stacks + stacks)
	burn_timer = burn_duration # Reinicia a 3.0s
	
	if burn_tick_timer <= 0.0:
		burn_tick_timer = burn_tick_interval
	
	burn_stacks_changed.emit(burn_stacks, max_burn_stacks)
	_update_visual_tint()


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
	if is_stunned:
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
	is_frozen = false
	slow_timer = 0.0
	is_stunned = false
	stun_timer = 0.0
	_update_visual_tint()
