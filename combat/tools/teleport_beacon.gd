class_name TeleportBeacon
extends RigidBody2D
## Baliza de Translocación balística.
## Se arroja siguiendo una parábola con gravedad.
## Al registrar contacto firme con cualquier superficie sólida (Layer 1) o enemigo (Layer 2):
## - Emite un efecto visual en el punto de salida y de llegada.
## - Asigna de inmediato `player.global_position = beacon.global_position`.
## - Elimina la baliza y completa el ciclo de translocación.

signal teleported(from_pos: Vector2, to_pos: Vector2)

@export var beacon_color: Color = Color(0.05, 0.35, 0.32, 1.0)
@export var glow_color: Color = Color(0.18, 0.88, 0.78, 1.0)
@export var radius: float = 7.0
@export var arming_time: float = 0.05

var player: Player = null
var _age: float = 0.0
var _triggered: bool = false
var _trail_particles: CPUParticles2D = null

@onready var impact_sensor: Area2D = get_node_or_null("ImpactSensor") as Area2D


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	
	if impact_sensor != null:
		impact_sensor.body_entered.connect(_on_sensor_entered)
		impact_sensor.area_entered.connect(_on_sensor_entered)
	
	_setup_trail_particles()


func _setup_trail_particles() -> void:
	_trail_particles = CPUParticles2D.new()
	_trail_particles.name = "EnderTrail"
	_trail_particles.emitting = true
	_trail_particles.amount = 18
	_trail_particles.lifetime = 0.28
	_trail_particles.spread = 180.0
	_trail_particles.gravity = Vector2(0, 30)
	_trail_particles.initial_velocity_min = 12.0
	_trail_particles.initial_velocity_max = 28.0
	_trail_particles.scale_amount_min = 1.5
	_trail_particles.scale_amount_max = 3.2
	_trail_particles.color = Color(0.2, 0.92, 0.82, 0.85)
	
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.4, 1.0, 0.9, 0.9))
	grad.add_point(0.5, Color(0.12, 0.7, 0.62, 0.6))
	grad.set_color(1, Color(0.04, 0.2, 0.18, 0.0))
	_trail_particles.color_ramp = grad
	
	add_child(_trail_particles)


func launch(origin: Vector2, initial_velocity: Vector2, p_player: Player) -> void:
	global_position = origin
	linear_velocity = initial_velocity
	angular_velocity = signf(initial_velocity.x) * 12.0
	player = p_player


func _physics_process(delta: float) -> void:
	if _triggered:
		return
	
	_age += delta
	# Parpadeo dimensional místico
	var pulse: float = 0.5 + 0.5 * sin(_age * 20.0)
	modulate = Color.WHITE.lerp(glow_color, pulse * 0.4)


func _on_body_entered(body: Node) -> void:
	if _triggered or _age < arming_time:
		return
	# Si toca terreno sólido (Layer 1) o estático
	if body is StaticBody2D or body.is_in_group(&"world"):
		_trigger_teleport()


func _on_sensor_entered(node: Node) -> void:
	if _triggered or _age < arming_time:
		return
	var target: Node2D = ThrowableUtil.resolve_hostile_target(node)
	if target != null:
		_trigger_teleport()


func _trigger_teleport() -> void:
	if _triggered:
		return
	_triggered = true
	
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	
	var departure_pos: Vector2 = player.global_position
	# Desplazar el punto de llegada ligeramente hacia arriba para el centro del cuerpo del jugador
	var arrival_pos: Vector2 = global_position + Vector2(0.0, -14.0)
	
	# Raycast de seguridad: comprobar si el espacio superior está libre de terreno sólido (Layer 1)
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position,
		arrival_pos + Vector2(0.0, -16.0),
		1
	)
	var res: Dictionary = space_state.intersect_ray(query)
	if not res.is_empty() and res.has("position"):
		arrival_pos = res["position"] + Vector2(0.0, 16.0)
	
	# Efecto visual en origen
	_spawn_teleport_burst(departure_pos)
	
	# Teletransportar al jugador inmediatamente
	player.global_position = arrival_pos
	# Preservar o atenuar la velocidad vertical para aterrizaje seguro
	player.velocity = Vector2(player.velocity.x * 0.5, minf(player.velocity.y, 0.0))
	
	# Efecto visual en destino
	_spawn_teleport_burst(arrival_pos)
	
	teleported.emit(departure_pos, arrival_pos)
	queue_free()


func _spawn_teleport_burst(at_pos: Vector2) -> void:
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	
	var burst: Node2D = Node2D.new()
	burst.global_position = at_pos
	host.add_child(burst)
	
	var tw: Tween = burst.create_tween()
	var circle_radius: float = 34.0
	
	burst.draw.connect(func() -> void:
		burst.draw_circle(Vector2.ZERO, circle_radius, Color(0.12, 0.78, 0.68, 0.65))
		burst.draw_circle(Vector2.ZERO, circle_radius * 0.6, Color(0.7, 1.0, 0.95, 0.95))
	)
	
	tw.tween_property(burst, "scale", Vector2(1.6, 1.6), 0.22).from(Vector2(0.2, 0.2))
	tw.parallel().tween_property(burst, "modulate:a", 0.0, 0.22)
	tw.finished.connect(burst.queue_free)


func _draw() -> void:
	# Borde obsidiana oscuro
	draw_circle(Vector2.ZERO, radius, Color(0.04, 0.22, 0.2, 1.0))
	# Cuerpo esmeralda turquesa profundo
	draw_circle(Vector2.ZERO, radius * 0.82, Color(0.08, 0.48, 0.42, 1.0))
	# Núcleo místico cian brillante
	draw_circle(Vector2(0.2, 0.4), radius * 0.48, Color(0.22, 0.9, 0.8, 1.0))
	# Pupila/Centro dimensional
	draw_circle(Vector2(0.2, 0.4), radius * 0.22, Color(0.05, 0.3, 0.28, 1.0))
	# Brillo especular blanco perlado
	draw_circle(Vector2(-2.0, -2.0), 1.6, Color(0.9, 1.0, 0.98, 1.0))
