extends RefCounted
## Sangre (o aceite y chispas en los enemigos mecánicos): salpicadura, manchas en el piso y trozos.
## Sin class_name a propósito: se carga por `preload` (ver class-name-cache-gotcha).
## Todo es procedural y respeta la densidad de partículas de la calidad gráfica.
##
## Arte opcional en `res://assets/art/fx/` (se usa si existe; si no, queda la forma procedural). Los PNG
## se exportan al doble del tamaño en juego, con fondo transparente y la imagen centrada:
##   blood_drop.png            gota suelta (cualquier tamaño chico)
##   blood_stain_01..03.png    mancha plana para el piso, vista de costado, más ancha que alta
##   blood_spray_01..03.png    abanico de salpicadura apuntando a la DERECHA (se rota hacia el golpe)
##   blood_mark_01..04.png     herida / salpicadura para pegar sobre el cuerpo del enemigo
##   gore_chunk_01..04.png     trozo de carne
##   gore_gut_01..02.png       tripa / intestino
##   gore_bone_01..02.png      hueso
##   gore_scrap_01..02.png     chatarra (enemigos mecánicos)

const SettingsScript = preload("res://core/settings.gd")
const ArtScript = preload("res://core/art/art.gd")
const GibScript = preload("res://combat/gib.gd")

const FX_DIR: String = "res://assets/art/fx/"
const GIB_GROUP: StringName = &"gibs"
const GIB_LIMIT: int = 40

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


static var _drop_tex: Texture2D = null


## Textura `base_NN.png` al azar entre 1 y `variants`, o null si no hay arte.
static func variant_tex(base: String, variants: int) -> Texture2D:
	var start: int = randi_range(1, maxi(1, variants))
	for i in range(variants):
		var n: int = (start - 1 + i) % variants + 1
		var tex: Texture2D = ArtScript.tex(FX_DIR + "%s_%02d.png" % [base, n])
		if tex != null:
			return tex
	return null


## Gota redonda: el arte `blood_drop.png` o un disco generado (nunca un cuadrado).
static func drop_texture() -> Texture2D:
	if _drop_tex != null:
		return _drop_tex
	var art: Texture2D = ArtScript.tex(FX_DIR + "blood_drop.png")
	if art != null:
		_drop_tex = art
		return _drop_tex
	var size: int = 12
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = (size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x - center, y - center).length() / center
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf((1.0 - d) * 3.0, 0.0, 1.0)))
	_drop_tex = ImageTexture.create_from_image(image)
	return _drop_tex


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
	var drop: Texture2D = drop_texture()
	emitter.texture = drop
	var drop_w: float = float(drop.get_width())
	emitter.scale_amount_min = 2.6 / drop_w
	emitter.scale_amount_max = 5.4 / drop_w
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


## Trozos de carne, tripas y huesos (o chatarra y resortes) que saltan y rebotan en el piso.
## `spread_up` abre el cono hacia arriba; `power` multiplica la velocidad de salida.
static func gibs(host: Node2D, pos: Vector2, count: int, mechanical: bool, power: float = 1.0) -> void:
	var density: float = SettingsScript.particle_scale()
	if density < MIN_DENSITY_FOR_PARTICLES:
		return
	var container: Node = _container(host)
	if container == null:
		return
	var tree: SceneTree = host.get_tree()
	var amount: int = maxi(1, roundi(float(count) * density))
	var existing: Array[Node] = tree.get_nodes_in_group(GIB_GROUP)
	for i in range(maxi(0, existing.size() + amount - GIB_LIMIT)):
		existing[i].queue_free()

	for i in range(amount):
		var roll: float = randf()
		var kind: String = "chunk"
		var texture: Texture2D = null
		if mechanical:
			kind = "scrap" if roll < 0.65 else "spring"
			texture = variant_tex("gore_scrap", 2) if kind == "scrap" else null
		elif roll < 0.5:
			kind = "chunk"
			texture = variant_tex("gore_chunk", 4)
		elif roll < 0.8:
			kind = "gut"
			texture = variant_tex("gore_gut", 2)
		else:
			kind = "bone"
			texture = variant_tex("gore_bone", 2)

		var gib: Node2D = GibScript.new() as Node2D
		gib.set("mechanical", mechanical)
		gib.z_index = FX_Z_INDEX
		gib.add_to_group(GIB_GROUP)
		container.add_child(gib)
		gib.global_position = pos + Vector2(randf_range(-6.0, 6.0), randf_range(-8.0, 4.0))
		gib.call("build", kind, texture)
		var angle: float = deg_to_rad(-90.0 + randf_range(-72.0, 72.0))
		gib.set("velocity", Vector2.from_angle(angle) * randf_range(130.0, 360.0) * power)
		gib.set("spin", randf_range(-14.0, 14.0))
		gib.rotation = randf() * TAU


## Abanico de salpicadura dibujado (si hay arte) en el punto de impacto, apuntando hacia `dir`.
static func spray_sprite(host: Node, pos: Vector2, dir: Vector2) -> void:
	var tex: Texture2D = variant_tex("blood_spray", 3)
	var container: Node = _container(host)
	if tex == null or container == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.z_index = FX_Z_INDEX
	sprite.scale = Vector2(0.5, 0.5)
	container.add_child(sprite)
	sprite.global_position = pos
	sprite.rotation = dir.angle() if dir.length() > 0.01 else randf() * TAU
	var fade: Tween = sprite.create_tween()
	fade.set_parallel(true)
	fade.tween_property(sprite, "scale", Vector2(0.7, 0.7), 0.2)
	fade.tween_property(sprite, "modulate:a", 0.0, 0.2).set_delay(0.05)
	fade.chain().tween_callback(sprite.queue_free)


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
	var art: Texture2D = null if mechanical else variant_tex("blood_stain", 3)
	if art != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = art
		var factor: float = width / float(art.get_width())
		sprite.scale = Vector2(factor * (-1.0 if randf() < 0.5 else 1.0), factor)
		stain.add_child(sprite)
	else:
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
