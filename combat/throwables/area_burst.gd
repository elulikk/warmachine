class_name AreaBurst
extends Area2D
## Detonación radial instantánea (fragmentación, criogénica, explosión de fuego).
## Espera dos frames de física para que el Area2D registre superposiciones, aplica un
## HitPayload único a cada blanco hostil dentro del radio y se disuelve tras un destello.

@export_group("Geometría")
@export var radius: float = 90.0

@export_group("Daño")
@export var damage: float = 60.0
@export var knockback_force: float = 0.0
@export var armor_penetration: float = 0.0
@export var critical: bool = false

@export_group("Estados Alterados")
@export var status_effects: Array[String] = []
@export var status_stacks: int = 1
@export var tick_damage: float = 3.0
## Duración personalizada de ICE (0.0 = valor por defecto del receptor).
@export var ice_duration: float = 0.0
## Multiplicador de velocidad restante bajo ICE (0.2 = 80% de ralentización).
@export var ice_speed_multiplier: float = 0.0

@export_group("Reacciones")
## Si es true, esta explosión es una fuente de ignición para nubes de gas cercanas.
@export var ignites_gas: bool = false

@export_group("Visual")
@export var burst_color: Color = Color(1.0, 0.6, 0.2, 1.0)
@export var visual_duration: float = 0.4
## Sprite de la explosión (vacío = dibujo procedural). Se carga en runtime y cae al dibujo si falta.
@export_file("*.png") var sprite_path: String = ""

var source_node: Node2D = null
var _visual_progress: float = 0.0
var _sprite: Texture2D = null


func _ready() -> void:
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		_sprite = load(sprite_path) as Texture2D
	collision_layer = 8 if ignites_gas else 0
	collision_mask = 2
	monitoring = true
	monitorable = ignites_gas
	if ignites_gas:
		add_to_group(&"fire_source")
	
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	add_child(shape_node)
	
	_run_burst()


func _run_burst() -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_set_visual_progress, 0.0, 1.0, visual_duration)
	tween.finished.connect(queue_free)
	
	# Dos frames de física garantizan que el Area2D ya haya calculado sus superposiciones.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_apply_effects()


func _apply_effects() -> void:
	var boom_sound: StringName = &"boom_frag"
	if status_effects.has("ICE"):
		boom_sound = &"boom_ice"
	elif status_effects.has("FIRE") or ignites_gas:
		boom_sound = &"boom_fire"
	GameFeel.sfx(self, boom_sound, global_position, -2.0, randf_range(0.92, 1.08))
	var targets: Array[Node2D] = ThrowableUtil.collect_hostile_targets(self)
	for target in targets:
		if not is_instance_valid(target):
			continue
		ThrowableUtil.deliver_hit(target, _build_payload(target))


func _build_payload(target: Node2D) -> HitPayload:
	var effects: Array[String] = []
	effects.append_array(status_effects)
	if critical and not effects.has("critical"):
		effects.append("critical")
	
	var direction: Vector2 = Vector2.ZERO
	if knockback_force > 0.0:
		direction = target.global_position - global_position
		if direction.length_squared() < 1.0:
			direction = Vector2.UP
		# Ligero impulso vertical para que el retroceso expansivo sea visible en suelo.
		direction = (direction.normalized() + Vector2(0.0, -0.35)).normalized()
	
	var payload: HitPayload = HitPayload.new(
		damage,
		knockback_force,
		direction,
		source_node,
		effects,
		status_stacks,
		tick_damage,
		armor_penetration
	)
	payload.ice_duration = ice_duration
	payload.ice_speed_multiplier = ice_speed_multiplier
	return payload


func _set_visual_progress(value: float) -> void:
	_visual_progress = value
	queue_redraw()


func _draw() -> void:
	var eased: float = 1.0 - pow(1.0 - _visual_progress, 3.0)
	var current_radius: float = radius * (0.25 + 0.75 * eased)
	var fade: float = 1.0 - _visual_progress
	
	if _sprite != null:
		# Sprite que se expande y se desvanece; la rotación fija por instancia evita repetirse.
		var half: float = current_radius * 1.05
		var tint: Color = Color(1.0, 1.0, 1.0, minf(1.0, fade * 1.6))
		draw_texture_rect(_sprite, Rect2(Vector2(-half, -half), Vector2(half, half) * 2.0), false, tint)
		return
	
	var fill: Color = burst_color
	fill.a = 0.35 * fade
	draw_circle(Vector2.ZERO, current_radius, fill)
	
	var ring: Color = burst_color.lightened(0.4)
	ring.a = 0.9 * fade
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 48, ring, 3.0)
	
	var core: Color = Color(1.0, 1.0, 1.0, 0.8 * fade)
	draw_circle(Vector2.ZERO, current_radius * 0.35 * fade, core)
