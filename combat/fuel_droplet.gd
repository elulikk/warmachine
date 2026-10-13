class_name FuelDroplet
extends Projectile
## Gota de combustible encendido: vuela con gravedad leve y, al tocar el piso, deja un charco de fuego.

const FuelPoolScript = preload("res://combat/throwables/fuel_pool.gd")
const FireVfx = preload("res://combat/fire_vfx.gd")

@export var fall_gravity: float = 520.0

var _velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	var core: CanvasItem = get_node_or_null("ColorRect") as CanvasItem
	if core != null:
		core.visible = false
	# Cada gota sale distinta (tamaño, velocidad y caída), como un chorro de líquido.
	var size_mult: float = randf_range(0.7, 1.7)
	scale = Vector2.ONE * size_mult
	fall_gravity *= randf_range(0.8, 1.3)
	add_child(FireVfx.make("droplet", 36.0))


func setup(
	p_speed: float,
	p_payload: HitPayload,
	_p_bounces: int = 0,
	_p_pierces: int = 0,
	_p_forks: int = 0,
	p_sprite: Texture2D = null
) -> void:
	super.setup(p_speed, p_payload, 0, 0, 0, p_sprite)
	_velocity = transform.x * p_speed * randf_range(0.65, 1.15)


func _physics_process(delta: float) -> void:
	_velocity.y += fall_gravity * delta
	global_position += _velocity * delta
	rotation = _velocity.angle()

	current_lifetime += delta
	if current_lifetime >= max_lifetime:
		recycle()


func _handle_collision(target: Node) -> void:
	if _has_impacted:
		return
	if payload != null and payload.source_node != null and (target == payload.source_node or target.get_parent() == payload.source_node):
		return
	if target is StaticBody2D or target is TileMap or target.is_in_group("world"):
		_land()
		return
	super._handle_collision(target)


## Se detiene, crea el charco en el punto de caída y se libera.
func _land() -> void:
	_has_impacted = true
	set_physics_process(false)
	var container: Node = get_tree().current_scene if is_inside_tree() else null
	if container != null:
		var pool_node: Area2D = FuelPoolScript.new()
		pool_node.source_node = payload.source_node if payload != null else null
		pool_node.position = global_position
		container.call_deferred("add_child", pool_node)
	call_deferred("recycle")


func recycle() -> void:
	if pool == null or not is_instance_valid(pool):
		queue_free()
		return
	super.recycle()


func _update_appearance() -> void:
	pass
