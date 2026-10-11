class_name ThrowableUtil
extends RefCounted
## Utilidades estáticas compartidas por arrojadizos y efectos de área:
## resolución de receptores de daño, filtrado de aliados y emisión de payloads.


## Resuelve el nodo que implementa `take_hit` a partir de un cuerpo/área detectado
## (por ejemplo, la Hurtbox de un enemigo apunta a su CharacterBody2D padre).
## Devuelve null si no es un blanco hostil válido (jugador, aliados, muertos).
static func resolve_hostile_target(node: Node) -> Node2D:
	if node == null or not is_instance_valid(node):
		return null
	
	var receiver: Node = node
	if not receiver.has_method("take_hit"):
		var parent: Node = node.get_parent()
		if parent != null and parent.has_method("take_hit"):
			receiver = parent
		else:
			return null
	
	if receiver.is_in_group(&"player") or receiver.is_in_group(&"allies"):
		return null
	if receiver is Player or receiver is AllyBase:
		return null
	if receiver is EnemyBase and (receiver as EnemyBase).is_dead:
		return null
	if not (receiver is Node2D):
		return null
	return receiver as Node2D


## Recolecta los blancos hostiles únicos que se superponen actualmente con un Area2D.
static func collect_hostile_targets(area: Area2D) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var seen: Dictionary = {}
	
	var candidates: Array[Node2D] = []
	candidates.append_array(area.get_overlapping_bodies())
	for other_area in area.get_overlapping_areas():
		candidates.append(other_area)
	
	for candidate in candidates:
		var target: Node2D = resolve_hostile_target(candidate)
		if target == null:
			continue
		var key: int = target.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		result.append(target)
	return result


## Devuelve el StatusReceiverComponent de un blanco, si lo posee.
static func get_status_receiver(target: Node) -> StatusReceiverComponent:
	if target == null:
		return null
	return target.get_node_or_null("StatusReceiverComponent") as StatusReceiverComponent


## Entrega un HitPayload al blanco mediante su interfaz `take_hit`.
static func deliver_hit(target: Node2D, payload: HitPayload) -> void:
	if target == null or not is_instance_valid(target) or payload == null:
		return
	if target.has_method("take_hit"):
		target.call("take_hit", payload)


## Indica si un payload transporta una infusión ígnea (fuego, plasma o lanzallamas).
static func payload_is_fire(payload: HitPayload) -> bool:
	if payload == null:
		return false
	for effect in payload.status_effects:
		match effect.to_upper():
			"FIRE", "BURN", "PLASMA", "FLAME":
				return true
	return false
