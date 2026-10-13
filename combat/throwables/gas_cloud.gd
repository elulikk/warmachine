class_name GasCloud
extends Area2D
## Nube densa de gas inflamable. Inflige ticks leves de daño biológico a los blancos en su interior
## y deflagra en una `fire_explosion` si entra en contacto con fuego (proyectiles con infusión "FIRE",
## plasma, lanzallamas, otra explosión ígnea o enemigos que ya estén ardiendo).

const FIRE_EXPLOSION_SCENE: PackedScene = preload("res://combat/throwables/fire_explosion.tscn")
const EffectCapScript = preload("res://core/effect_cap.gd")
const ViewCullScript = preload("res://core/view_cull.gd")
## Nubes vivas a la vez: al pasarse, la más vieja se disipa (protege la lluvia de bombas de gas).
const MAX_ALIVE: int = 24

@export var lifetime: float = 6.0
@export var tick_interval: float = 0.4
@export var tick_damage: float = 4.0
@export var radius: float = 105.0
@export var cloud_color: Color = Color(0.35, 0.85, 0.25, 1.0)
## Multiplicador del radio de la explosión resultante respecto al radio de la nube.
@export var explosion_radius_mult: float = 1.15

var source_node: Node2D = null

var _age: float = 0.0
var _tick_timer: float = 0.0
var _ignited: bool = false
var _sprite: Texture2D = null

const SPRITE_PATH: String = "res://assets/sprites/efectos/gas_cloud.png"
var _puffs: Array[Vector3] = [] # x, y = offset normalizado; z = fase de animación


func _ready() -> void:
	if ResourceLoader.exists(SPRITE_PATH):
		_sprite = load(SPRITE_PATH) as Texture2D
	# Capa 0 (no es detectada). Máscara 2|4|8: entidades, proyectiles y fuentes de ignición.
	collision_layer = 0
	collision_mask = 14
	monitoring = true
	monitorable = false
	
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	add_child(shape_node)
	
	for i in range(9):
		var ang: float = randf() * TAU
		var dist: float = sqrt(randf()) * 0.7
		_puffs.append(Vector3(cos(ang) * dist, sin(ang) * dist, randf() * TAU))
	
	area_entered.connect(_on_area_entered)
	# Desfasado al azar: los ticks de muchas nubes no caen en el mismo cuadro
	_tick_timer = randf_range(0.05, tick_interval)
	EffectCapScript.register(&"gas_cloud", self, MAX_ALIVE)


func _physics_process(delta: float) -> void:
	if _ignited:
		return
	
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_tick()
	
	# Fuera de la cámara no hace falta redibujar (el daño y la ignición siguen igual)
	if ViewCullScript.near(self, radius + 60.0):
		queue_redraw()


func _apply_tick() -> void:
	var targets: Array[Node2D] = ThrowableUtil.collect_hostile_targets(self)
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		# Un blanco que ya está ardiendo enciende el gas.
		var receiver: StatusReceiverComponent = ThrowableUtil.get_status_receiver(target)
		if receiver != null and receiver.burn_stacks > 0:
			ignite()
			return
		
		var effects: Array[String] = ["POISON"]
		var payload: HitPayload = HitPayload.new(
			tick_damage,
			0.0,
			Vector2.ZERO,
			source_node,
			effects,
			1,
			0.0,
			0.0
		)
		ThrowableUtil.deliver_hit(target, payload)


func _on_area_entered(area: Area2D) -> void:
	if _ignited:
		return
	
	if area is Projectile:
		var proj: Projectile = area as Projectile
		# Los proyectiles reciclados del pool permanecen invisibles y sin payload.
		if proj.visible and ThrowableUtil.payload_is_fire(proj.payload):
			ignite()
	elif area.is_in_group(&"fire_source"):
		ignite()


## La nube se disipa rápido (la pide el tope de nubes vivas).
func expire() -> void:
	lifetime = minf(lifetime, _age + 0.4)


## Consume la nube instantáneamente en una explosión masiva de fuego.
func ignite() -> void:
	if _ignited:
		return
	_ignited = true
	set_physics_process(false)
	_spawn_fire_explosion.call_deferred()


func _spawn_fire_explosion() -> void:
	var host: Node = get_parent()
	if host == null or not is_inside_tree():
		queue_free()
		return
	
	var explosion: AreaBurst = FIRE_EXPLOSION_SCENE.instantiate() as AreaBurst
	if explosion != null:
		explosion.radius = radius * explosion_radius_mult
		explosion.source_node = source_node
		explosion.position = position
		host.add_child(explosion)
	queue_free()


func _draw() -> void:
	var fade_in: float = clampf(_age / 0.4, 0.0, 1.0)
	var fade_out: float = clampf((lifetime - _age) / 1.0, 0.0, 1.0)
	var alpha_mult: float = fade_in * fade_out
	
	if _sprite != null:
		# La nube respira y gira lento; dos capas a distinto giro dan sensación de volutas.
		var size: float = radius * (0.95 + 0.05 * fade_in) * 2.0
		var tint: Color = Color(1.0, 1.0, 1.0, 0.7 * alpha_mult)
		draw_set_transform(Vector2.ZERO, _age * 0.25, Vector2.ONE)
		draw_texture_rect(_sprite, Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size)), false, tint)
		draw_set_transform(Vector2.ZERO, -_age * 0.4 + 1.3, Vector2.ONE * 0.8)
		tint.a *= 0.55
		draw_texture_rect(_sprite, Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size)), false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	
	var base: Color = cloud_color
	base.a = 0.22 * alpha_mult
	draw_circle(Vector2.ZERO, radius * (0.9 + 0.1 * fade_in), base)
	
	for puff in _puffs:
		var phase: float = puff.z + _age * 1.4
		var offset: Vector2 = Vector2(puff.x, puff.y) * radius + Vector2(cos(phase), sin(phase)) * 6.0
		var puff_color: Color = cloud_color.lightened(0.15)
		puff_color.a = 0.16 * alpha_mult
		draw_circle(offset, radius * (0.38 + 0.04 * sin(phase)), puff_color)
	
	var edge: Color = cloud_color.lightened(0.3)
	edge.a = 0.45 * alpha_mult
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, edge, 2.0)
