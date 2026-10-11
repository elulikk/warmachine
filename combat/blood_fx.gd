extends RefCounted
## Sangre (o aceite y chispas en los enemigos mecánicos): salpicadura, manchas en el piso y trozos.
## Sin class_name a propósito: se carga por `preload` (ver class-name-cache-gotcha).
## Todo es procedural y respeta la densidad de partículas de la calidad gráfica.

const SettingsScript = preload("res://core/settings.gd")

const FX_Z_INDEX: int = 15
const BLOOD: Color = Color(0.55, 0.03, 0.05, 1.0)
const BLOOD_DARK: Color = Color(0.32, 0.01, 0.03, 1.0)
const OIL: Color = Color(0.1, 0.1, 0.11, 1.0)
const SPARK: Color = Color(1.0, 0.8, 0.35, 1.0)

## Las manchas del piso duran este tiempo y luego se desvanecen.
const STAIN_LIFETIME: float = 9.0
const STAIN_FADE: float = 3.0
## Tope de manchas vivas: al pasarse se borran las más viejas.
const STAIN_LIMIT: int = 60
const STAIN_GROUP: StringName = &"blood_stains"
## Distancia máxima hasta el piso al buscar dónde cae una gota.
const FLOOR_RAY_LENGTH: float = 420.0
## Debajo de esta densidad de partículas no hay salpicaduras ni trozos (las manchas del piso sí).
const MIN_DENSITY_FOR_PARTICLES: float = 0.3


static func _container(host: Node) -> Node:
	if host == null or not host.is_inside_tree():
		return null
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


## Salpicadura de gotas que sale en la dirección del golpe y cae por gravedad.
static func spray(host: Node, pos: Vector2, dir: Vector2, damage: float, mechanical: bool) -> void:
	var density: float = SettingsScript.particle_scale()
	if density < MIN_DENSITY_FOR_PARTICLES:
		return
	var container: Node = _container(host)
	if container == null:
		return
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.z_index = FX_Z_INDEX
	emitter.one_shot = true
	emitter.amount = maxi(2, roundi(clampf(3.0 + damage * 0.35, 4.0, 14.0) * density))
	emitter.lifetime = 0.55
	emitter.explosiveness = 1.0
	emitter.direction = dir.normalized() if dir.length() > 0.01 else Vector2.UP
	emitter.spread = 50.0
	emitter.initial_velocity_min = 50.0
	emitter.initial_velocity_max = 230.0
	emitter.gravity = Vector2(0.0, 720.0)
	emitter.scale_amount_min = 1.6
	emitter.scale_amount_max = 3.2
	var ramp: Gradient = Gradient.new()
	if mechanical:
		ramp.set_color(0, Color(SPARK.r, SPARK.g, SPARK.b, 1.0))
		ramp.set_color(1, Color(0.35, 0.12, 0.05, 0.0))
	else:
		ramp.set_color(0, Color(0.75, 0.05, 0.07, 1.0))
		ramp.set_color(1, Color(BLOOD_DARK.r, BLOOD_DARK.g, BLOOD_DARK.b, 0.0))
	emitter.color_ramp = ramp
	container.add_child(emitter)
	emitter.global_position = pos
	emitter.emitting = true
	emitter.get_tree().create_timer(1.0).timeout.connect(emitter.queue_free)


## Trozos más grandes al cruzar un umbral de daño y al morir.
static func chunks(host: Node, pos: Vector2, amount: int, base_color: Color, mechanical: bool) -> void:
	var density: float = SettingsScript.particle_scale()
	if density < MIN_DENSITY_FOR_PARTICLES:
		return
	var container: Node = _container(host)
	if container == null:
		return
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.z_index = FX_Z_INDEX
	emitter.one_shot = true
	emitter.amount = maxi(2, roundi(float(amount) * density))
	emitter.lifetime = 0.7
	emitter.explosiveness = 1.0
	emitter.direction = Vector2.UP
	emitter.spread = 75.0
	emitter.initial_velocity_min = 90.0
	emitter.initial_velocity_max = 260.0
	emitter.gravity = Vector2(0.0, 800.0)
	emitter.scale_amount_min = 2.6
	emitter.scale_amount_max = 4.6
	emitter.angular_velocity_min = -360.0
	emitter.angular_velocity_max = 360.0
	var ramp: Gradient = Gradient.new()
	var piece: Color = base_color if mechanical else BLOOD
	ramp.set_color(0, Color(piece.r, piece.g, piece.b, 1.0))
	ramp.set_color(1, Color(piece.r * 0.5, piece.g * 0.5, piece.b * 0.5, 0.0))
	emitter.color_ramp = ramp
	container.add_child(emitter)
	emitter.global_position = pos
	emitter.emitting = true
	emitter.get_tree().create_timer(1.2).timeout.connect(emitter.queue_free)


## Deja `count` manchas en el piso cerca de `pos`, repartidas hacia donde salpicó. Cada una aparece
## cuando la gota llegaría al piso y se desvanece pasado un rato.
static func stains(host: Node2D, pos: Vector2, dir: Vector2, count: int, size_mult: float, mechanical: bool) -> void:
	if host == null or not host.is_inside_tree():
		return
	var n: int = maxi(1, roundi(float(count) * clampf(SettingsScript.particle_scale(), 0.5, 1.0)))
	var space: PhysicsDirectSpaceState2D = host.get_world_2d().direct_space_state
	var side: float = signf(dir.x) if absf(dir.x) > 0.1 else 0.0
	for i in range(n):
		var offset_x: float = randf_range(-14.0, 14.0) + side * randf_range(4.0, 46.0)
		var from_pos: Vector2 = Vector2(pos.x + offset_x, pos.y)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, from_pos + Vector2(0.0, FLOOR_RAY_LENGTH), 1)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var fall: float = (hit["position"] as Vector2).y - pos.y
		var delay: float = clampf(sqrt(2.0 * maxf(fall, 0.0) / 720.0), 0.05, 0.6)
		_place_stain(host, hit, size_mult, mechanical, delay)


static func _place_stain(host: Node, hit: Dictionary, size_mult: float, mechanical: bool, delay: float) -> void:
	var tree: SceneTree = host.get_tree()
	var floor_body: Node2D = hit.get("collider") as Node2D
	# Pegada al piso: si es una plataforma que se mueve, la mancha se mueve con ella
	var parent: Node = floor_body if floor_body != null and floor_body is StaticBody2D else _container(host)
	if parent == null:
		return
	_trim_stains(tree)

	var stain: Node2D = Node2D.new()
	stain.add_to_group(STAIN_GROUP)
	stain.visible = false
	var width: float = randf_range(9.0, 24.0) * size_mult
	var height: float = randf_range(2.4, 4.2) * clampf(size_mult, 0.7, 1.4)
	var color: Color = OIL if mechanical else BLOOD_DARK
	stain.add_child(_ellipse(width, height, Color(color.r, color.g, color.b, 0.92)))
	var center_color: Color = Color(0.2, 0.2, 0.22, 0.9) if mechanical else Color(color.r * 1.6, color.g * 1.4, color.b * 1.4, 0.9)
	stain.add_child(_ellipse(width * 0.55, height * 0.6, center_color))
	parent.add_child(stain)
	stain.global_position = (hit["position"] as Vector2) + Vector2(0.0, 1.5)

	tree.create_timer(delay).timeout.connect(stain.set_visible.bind(true))
	var fade: Tween = stain.create_tween()
	fade.tween_interval(delay + STAIN_LIFETIME)
	fade.tween_property(stain, "modulate:a", 0.0, STAIN_FADE)
	fade.tween_callback(stain.queue_free)


static func _ellipse(width: float, height: float, color: Color) -> Polygon2D:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var angle: float = TAU * float(i) / 10.0
		points.append(Vector2(cos(angle) * width * 0.5, sin(angle) * height * 0.5))
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	return polygon


static func _trim_stains(tree: SceneTree) -> void:
	var existing: Array[Node] = tree.get_nodes_in_group(STAIN_GROUP)
	var overflow: int = existing.size() - STAIN_LIMIT + 1
	for i in range(maxi(0, overflow)):
		existing[i].queue_free()
