class_name ThrowableBase
extends RigidBody2D
## Proyectil arrojadizo con física balística (parábola + rebote contra terreno en Layer 1).
## Detona por fusible, al impactar contra un enemigo o (opcionalmente) al tocar el suelo,
## instancia su efecto de área y se libera.

signal detonated(at_position: Vector2)

@export_group("Detonación")
@export var throwable_id: String = "throwable"
@export var fuse_time: float = 1.5
@export var detonate_on_enemy: bool = true
@export var detonate_on_ground: bool = false
@export var arming_time: float = 0.08

@export_group("Efecto")
@export var effect_scene: PackedScene
## Reubica el efecto sobre el suelo más cercano (útil para charcos).
@export var snap_effect_to_ground: bool = false

@export_group("Visual")
@export var body_color: Color = Color(0.45, 0.5, 0.4, 1.0)
@export var body_radius: float = 6.0

var thrower: Node2D = null

var _fuse_left: float = 0.0
var _age: float = 0.0
var _detonation_requested: bool = false
var _detonated: bool = false

@onready var impact_sensor: Area2D = get_node_or_null("ImpactSensor") as Area2D


func _ready() -> void:
	_fuse_left = fuse_time
	# Reportar contactos cuesta por cuerpo y por cuadro: solo si la granada detona al tocar el piso
	contact_monitor = detonate_on_ground
	max_contacts_reported = 4 if detonate_on_ground else 0
	if detonate_on_ground:
		body_entered.connect(_on_body_entered)
	
	if impact_sensor != null:
		impact_sensor.body_entered.connect(_on_sensor_target_entered)
		impact_sensor.area_entered.connect(_on_sensor_target_entered)


## Lanza el arrojadizo con la velocidad inicial calculada por el ThrowableManager.
func launch(origin: Vector2, initial_velocity: Vector2, p_thrower: Node2D) -> void:
	global_position = origin
	linear_velocity = initial_velocity
	angular_velocity = signf(initial_velocity.x) * 8.0
	thrower = p_thrower


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	
	_age += delta
	_fuse_left -= delta
	
	# Parpadeo cada vez más rápido al acercarse el fin del fusible.
	var urgency: float = 1.0 - clampf(_fuse_left / maxf(fuse_time, 0.01), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_age * (10.0 + 30.0 * urgency))
	modulate = Color.WHITE.lerp(Color(1.8, 1.4, 1.4, 1.0), pulse * urgency)
	
	if _fuse_left <= 0.0:
		_detonation_requested = true
	
	if _detonation_requested:
		_detonate()


func _on_body_entered(body: Node) -> void:
	if not detonate_on_ground or _detonated:
		return
	if body is StaticBody2D or body.is_in_group(&"world"):
		_detonation_requested = true


func _on_sensor_target_entered(node: Node) -> void:
	if not detonate_on_enemy or _detonated or _age < arming_time:
		return
	if ThrowableUtil.resolve_hostile_target(node) != null:
		_detonation_requested = true


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	
	var spawn_pos: Vector2 = global_position
	if snap_effect_to_ground:
		spawn_pos = _find_ground_position(spawn_pos)
	
	_spawn_effect(spawn_pos)
	detonated.emit(spawn_pos)
	queue_free()


## Proyecta un rayo hacia abajo contra el terreno (Layer 1) para ubicar el suelo.
func _find_ground_position(from_pos: Vector2) -> Vector2:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		from_pos + Vector2(0.0, -4.0),
		from_pos + Vector2(0.0, 96.0),
		1
	)
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return from_pos
	return result["position"] as Vector2


func _spawn_effect(spawn_pos: Vector2) -> void:
	if effect_scene == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var host: Node = tree.current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	
	var effect: Node2D = effect_scene.instantiate() as Node2D
	if effect == null:
		return
	
	if effect is AreaBurst:
		(effect as AreaBurst).source_node = thrower
	elif effect is AcidPool:
		(effect as AcidPool).source_node = thrower
	elif effect is GasCloud:
		(effect as GasCloud).source_node = thrower
	elif "source_node" in effect:
		effect.set("source_node", thrower)
	
	effect.position = spawn_pos
	host.add_child.call_deferred(effect)


func _draw() -> void:
	draw_circle(Vector2.ZERO, body_radius, body_color.darkened(0.45))
	draw_circle(Vector2.ZERO, body_radius - 1.5, body_color)
	draw_circle(Vector2(-1.5, -1.5), 1.8, body_color.lightened(0.6))
	draw_rect(Rect2(-1.5, -body_radius - 3.0, 3.0, 4.0), Color(0.85, 0.85, 0.85, 1.0))
