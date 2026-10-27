class_name TargetScannerComponent
extends Node2D
## Componente universal de escaneo periódico de objetivos (Target Scanner).
## Localiza la entidad viva más cercana dentro del radio configurado que pertenezca
## a los grupos especificados, cuente con vitalidad activa y posea línea de visión directa.

signal target_found(target: Node2D)
signal target_lost

@export var detection_radius: float = 320.0
@export var target_groups: Array[String] = ["enemies"]
@export var scan_interval: float = 0.2
@export var ray_collision_mask: int = 1 # Capa 1: Geometría de terreno / mundo

var current_target: Node2D = null

var _scan_timer: Timer = null
var _ray_cast: RayCast2D = null


func _ready() -> void:
	_setup_timer()
	_setup_raycast()
	# Escaneo inicial al instanciar
	scan_now()


func _setup_timer() -> void:
	_scan_timer = Timer.new()
	_scan_timer.name = "InternalScanTimer"
	_scan_timer.wait_time = maxf(0.05, scan_interval)
	_scan_timer.autostart = true
	_scan_timer.one_shot = false
	_scan_timer.timeout.connect(scan_now)
	add_child(_scan_timer)


func _setup_raycast() -> void:
	_ray_cast = RayCast2D.new()
	_ray_cast.name = "LoSRayCast"
	_ray_cast.enabled = true
	_ray_cast.collision_mask = ray_collision_mask
	_ray_cast.exclude_parent = true
	add_child(_ray_cast)


## Ejecuta un barrido de escaneo periódico buscando el blanco vivo más próximo con LoS.
func scan_now() -> void:
	if not is_inside_tree():
		return
	
	# Verificar si el objetivo actual todavía sigue vivo y válido
	if current_target != null:
		if not _is_entity_alive(current_target) or not _is_in_range_and_los(current_target):
			_set_target(null)
	
	var best_target: Node2D = null
	var best_dist_sq: float = detection_radius * detection_radius
	var scanner_origin: Vector2 = global_position
	
	var candidates: Array[Node2D] = []
	for grp in target_groups:
		var nodes: Array[Node] = get_tree().get_nodes_in_group(grp)
		for node in nodes:
			if node is Node2D and is_instance_valid(node) and not candidates.has(node):
				candidates.append(node as Node2D)
	
	for candidate in candidates:
		if candidate == get_parent():
			continue
		if not _is_entity_alive(candidate):
			continue
		
		var cand_center: Vector2 = _get_entity_center(candidate)
		var dist_sq: float = scanner_origin.distance_squared_to(cand_center)
		if dist_sq > best_dist_sq:
			continue
		
		if not _has_line_of_sight(cand_center):
			continue
		
		best_dist_sq = dist_sq
		best_target = candidate
	
	_set_target(best_target)


func _set_target(new_target: Node2D) -> void:
	if new_target != current_target:
		current_target = new_target
		if current_target != null:
			target_found.emit(current_target)
		else:
			target_lost.emit()


func _is_in_range_and_los(entity: Node2D) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	var cand_center: Vector2 = _get_entity_center(entity)
	var dist: float = global_position.distance_to(cand_center)
	if dist > detection_radius:
		return false
	return _has_line_of_sight(cand_center)


func _is_entity_alive(entity: Node2D) -> bool:
	if entity == null or not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return false
	# Invisible (Capa de Invisibilidad): no se puede apuntar
	if entity.get(&"is_invisible") == true or bool(entity.get_meta(&"is_invisible", false)):
		return false
	
	var health_comp: HealthComponent = entity.get_node_or_null("HealthComponent") as HealthComponent
	if health_comp != null:
		return health_comp.current_health > 0.0 and not health_comp.is_dead
	
	if "current_health" in entity:
		if float(entity.get("current_health")) <= 0.0:
			return false
		if "is_dead" in entity and bool(entity.get("is_dead")):
			return false
	
	return true


func _get_entity_center(entity: Node2D) -> Vector2:
	var shape: CollisionShape2D = entity.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		return shape.global_position
	if entity is CharacterBody2D:
		return entity.global_position + Vector2(0, -18.0)
	return entity.global_position


func _has_line_of_sight(target_world_pos: Vector2) -> bool:
	if _ray_cast == null:
		return true
	
	_ray_cast.global_position = global_position
	_ray_cast.target_position = _ray_cast.to_local(target_world_pos)
	_ray_cast.force_raycast_update()
	
	if _ray_cast.is_colliding():
		var col_point: Vector2 = _ray_cast.get_collision_point()
		var col_dist: float = global_position.distance_to(col_point)
		var target_dist: float = global_position.distance_to(target_world_pos)
		# Si colisionó con terreno a una distancia menor a la del objetivo
		if col_dist < target_dist - 6.0:
			return false
	
	return true


func get_current_target() -> Node2D:
	if current_target != null and (not is_instance_valid(current_target) or not _is_entity_alive(current_target)):
		_set_target(null)
	return current_target


func has_target() -> bool:
	return get_current_target() != null
