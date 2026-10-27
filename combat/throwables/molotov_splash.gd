extends Node2D
## Estallido del molotov: una llamarada (AreaBurst con fuego) y una alfombra de charcos de fuego sobre el piso.
## Lo crea el arrojadizo al romperse; se libera apenas reparte sus efectos.

const BURST_SCENE: PackedScene = preload("res://combat/throwables/molotov_burst.tscn")
const FuelPoolScript = preload("res://combat/throwables/fuel_pool.gd")

## Separación horizontal de los charcos (uno al centro y los demás a los costados).
const POOL_OFFSETS: Array[float] = [-72.0, 0.0, 72.0]
const POOL_LIFETIME: float = 4.5
const POOL_TICK_DAMAGE: float = 5.0

var source_node: Node2D = null


func _ready() -> void:
	var host: Node = get_parent()
	if host == null:
		queue_free()
		return
	var burst: AreaBurst = BURST_SCENE.instantiate() as AreaBurst
	if burst != null:
		burst.source_node = source_node
		burst.position = position
		host.add_child.call_deferred(burst)
	for offset in POOL_OFFSETS:
		var pool: Area2D = FuelPoolScript.new()
		pool.source_node = source_node
		pool.lifetime = POOL_LIFETIME
		pool.tick_damage = POOL_TICK_DAMAGE
		pool.position = _floor_point(position + Vector2(offset, 0.0))
		host.add_child.call_deferred(pool)
	queue_free()


## Piso bajo el punto (los charcos de los costados pueden caer en un escalón distinto). Sin piso cerca, queda donde está.
func _floor_point(at: Vector2) -> Vector2:
	var from: Vector2 = at + Vector2(0.0, -40.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 140.0), 1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return at
	return hit["position"] as Vector2
