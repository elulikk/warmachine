extends RefCounted
## Pérdida de aggro por distancia: un enemigo que persigue al jugador lo suelta al alejarse lo suficiente
## (LOSE_FACTOR veces su rango de detección). No aplica a los de arena (grupo `arena_enemies`) ni a los
## de oleadas (meta `no_leash`), que deben seguir yendo hacia el jugador. Sin class_name: se usa por `preload`.

const LOSE_FACTOR: float = 1.8
const GROUP_ARENA: StringName = &"arena_enemies"
const META_NO_LEASH: StringName = &"no_leash"


static func should_drop(body: Node, dist: float, aggro_range: float) -> bool:
	if dist <= aggro_range * LOSE_FACTOR:
		return false
	return not body.is_in_group(GROUP_ARENA) and not body.has_meta(META_NO_LEASH)
