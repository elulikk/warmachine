extends RefCounted
## Decoración del Mundo 3 (Abismo Ígneo): estalagmitas, árboles calcinados y columnas rotas detrás del escenario,
## calaveras, huesos y cristales de azufre sobre los suelos, braseros que titilan, cadenas y jaulas colgando que se
## balancean, brasas y ceniza que suben (CPUParticles2D), lava que hierve en los pozos y grietas del suelo que laten.
## Solo dibujo: no toca colisiones. Sin class_name: la llama LevelSkin (`preload`, tema del capítulo 3).
##
## La ubicación es determinista (semilla = nombre del nivel): el mismo nivel siempre se ve igual.
## Arte en `assets/art/world3/` (Google Flow, ver `art_source/world3/process.py`).

const ArtScript = preload("res://core/art/art.gd")

const DIR: String = "res://assets/art/world3/"

## Suelos más angostos que esto no se decoran (bloques de salto, pedestales).
const MIN_GROUND_WIDTH: float = 110.0
## Las plataformas delgadas solo llevan alguna cadena colgando.
const THIN_MAX_HEIGHT: float = 40.0
## Espacio libre que necesita un decorado grande por encima del suelo.
const BIG_CLEARANCE: float = 260.0
## Las cadenas y jaulas cuelgan desde arriba de lo que muestra la cámara (limit_top = 60).
const HANG_TOP: float = -40.0

## Pozo de lava: hueco entre dos suelos sin nada debajo. La superficie queda a esta profundidad bajo el borde.
const LAVA_DEPTH: float = 80.0
const LAVA_MIN_GAP: float = 24.0
const LAVA_MAX_GAP: float = 700.0
## Daño al tocar la lava (fracción de la vida máxima) y velocidad del rebote que lo saca del pozo.
const LAVA_DAMAGE_FRACTION: float = 0.2
const LAVA_BOUNCE: float = 800.0

const BIG: Array[String] = ["stalagmite", "dead_tree", "broken_column"]
## Adornos de suelo con su peso relativo y escala.
const SMALL: Array = [
	["skull", 3, 0.2], ["bone_pile", 4, 0.3], ["sulfur_crystal", 2, 0.2], ["smoking_rock", 2, 0.24],
	["hell_mushroom", 2, 0.18], ["stake", 2, 0.24], ["tombstone", 1, 0.3], ["demon_eye", 1, 0.14],
]
## Texturas cuyo brillo de lava late (suelo y borde con brasas).
const PULSING: Array[String] = ["volcanic_rock.png", "ember_crust.png"]

const PULSE_SHADER_CODE: String = """
shader_type canvas_item;
uniform float speed = 1.6;
uniform float strength = 0.3;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	// Solo las grietas (naranja: mucho rojo, poco azul) laten; la roca negra queda igual
	float hot = smoothstep(0.18, 0.6, c.r - c.b);
	float pulse = 0.5 + 0.5 * sin(TIME * speed + FRAGCOORD.x * 0.004 + FRAGCOORD.y * 0.006);
	c.rgb += vec3(1.0, 0.42, 0.08) * hot * pulse * strength;
	COLOR = c;
}
"""

const LAVA_SHADER_CODE: String = """
shader_type canvas_item;
uniform vec2 rect_size = vec2(100.0, 1200.0);
void fragment() {
	vec2 p = UV * rect_size / 36.0;
	float w1 = 0.5 + 0.5 * sin(p.x * 1.7 + TIME * 1.1 + sin(p.y * 2.3 - TIME * 0.7) * 1.4);
	float w2 = 0.5 + 0.5 * sin(p.x * 2.9 - TIME * 0.8 + p.y * 1.6 + sin(p.x * 0.7 + TIME * 0.5));
	float depth = clamp(UV.y * rect_size.y / 260.0, 0.0, 1.0);
	vec3 hot = vec3(1.0, 0.82, 0.35);
	vec3 mid = vec3(0.98, 0.36, 0.06);
	vec3 dark = vec3(0.3, 0.04, 0.02);
	vec3 c = mix(mid, hot, pow(w1 * w2, 1.5));
	// Costra oscura que flota en la superficie
	c = mix(c, vec3(0.22, 0.06, 0.03), smoothstep(0.72, 0.9, w2) * 0.6 * (1.0 - depth));
	c = mix(c, dark, depth * 0.85);
	// Borde superior incandescente
	float rim = 1.0 - smoothstep(0.0, 6.0, UV.y * rect_size.y);
	c += vec3(1.0, 0.7, 0.3) * rim * (0.6 + 0.4 * sin(TIME * 3.0 + p.x));
	COLOR = vec4(c, 1.0);
}
"""

static var _pulse_shader: Shader = null
static var _lava_shader: Shader = null
static var _glow_tex: Texture2D = null
static var _rise_tex: Texture2D = null


static func decorate(level: Node, solids: Array[Rect2]) -> void:
	if level.has_node("HellDecorBack"):
		return
	var environment: Node = level.get_node_or_null("Environment")
	var back: Node2D = Node2D.new()
	back.name = "HellDecorBack"
	back.z_index = -1
	back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var front: Node2D = Node2D.new()
	front.name = "HellDecorFront"
	front.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	level.add_child(back)
	level.add_child(front)
	# Delante del suelo pero detrás de jugador y enemigos
	if environment != null:
		level.move_child(front, environment.get_index() + 1)
		level.move_child(back, environment.get_index())

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(level.name))

	var level_end: float = 0.0
	for rect: Rect2 in solids:
		level_end = maxf(level_end, rect.end.x)
		if rect.size.x < MIN_GROUND_WIDTH:
			continue
		if rect.size.y <= THIN_MAX_HEIGHT:
			_decorate_thin(back, rect, rng)
			continue
		var top: float = rect.position.y
		_place_big(back, rect, solids, rng)
		_place_braziers(back, rect, solids, rng)
		var x: float = rect.position.x + rng.randf_range(20.0, 80.0)
		while x < rect.end.x - 14.0:
			if not _covered_top(rect, solids, x) and _free_above(rect, solids, x, 40.0):
				_place_small(front, Vector2(x, top), rng)
			x += rng.randf_range(70.0, 190.0)
		_add_rising(back, Vector2(rect.get_center().x, top - 6.0), rect.size.x, rng)

	_place_hangers(back, level_end, rng)
	_add_lava_pits(back, solids, rng)
	if environment != null:
		_pulse_ground(environment)


# ==============================================================================
# Colocación
# ==============================================================================

static func _place_big(parent: Node2D, rect: Rect2, solids: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var x: float = rect.position.x + rng.randf_range(80.0, 320.0)
	while x < rect.end.x - 70.0:
		if not _covered_top(rect, solids, x - 40.0) and not _covered_top(rect, solids, x + 40.0) \
				and _free_above(rect, solids, x, BIG_CLEARANCE):
			var kind: String = BIG[rng.randi_range(0, BIG.size() - 1)]
			var tex: Texture2D = ArtScript.tex(DIR + kind + ".png")
			if tex != null:
				var prop: Sprite2D = Sprite2D.new()
				prop.texture = tex
				prop.centered = false
				var s: float = rng.randf_range(0.42, 0.62)
				prop.scale = Vector2(s * (-1.0 if rng.randf() < 0.5 else 1.0), s)
				prop.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 12.0)
				prop.position = Vector2(x, rect.position.y)
				# Más oscuro: queda como segundo plano
				prop.modulate = Color(0.72, 0.66, 0.66, 1.0)
				parent.add_child(prop)
		x += rng.randf_range(420.0, 820.0)


## Braseros al fondo: el fuego titila (brillo aditivo que late) y suelta brasas.
static func _place_braziers(parent: Node2D, rect: Rect2, solids: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = ArtScript.tex(DIR + "brazier.png")
	if tex == null:
		return
	var x: float = rect.position.x + rng.randf_range(200.0, 600.0)
	while x < rect.end.x - 60.0:
		if not _covered_top(rect, solids, x) and _free_above(rect, solids, x, 90.0):
			var s: float = rng.randf_range(0.36, 0.44)
			var brazier: Sprite2D = Sprite2D.new()
			brazier.texture = tex
			brazier.centered = false
			brazier.scale = Vector2(s, s)
			brazier.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 6.0)
			brazier.position = Vector2(x, rect.position.y)
			brazier.modulate = Color(0.85, 0.8, 0.8, 1.0)
			parent.add_child(brazier)
			var flame: Vector2 = Vector2(x, rect.position.y - tex.get_height() * s * 0.7)
			_add_glow(parent, flame, 1.3, rng)
			_add_flame_embers(parent, flame, rng)
		x += rng.randf_range(700.0, 1300.0)


static func _place_small(parent: Node2D, foot: Vector2, rng: RandomNumberGenerator) -> void:
	var total: int = 0
	for entry: Array in SMALL:
		total += int(entry[1])
	var pick: int = rng.randi_range(1, total)
	var chosen: Array = SMALL[0]
	for entry: Array in SMALL:
		pick -= int(entry[1])
		if pick <= 0:
			chosen = entry
			break
	var name: String = str(chosen[0])
	var tex: Texture2D = ArtScript.tex(DIR + name + ".png")
	if tex == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	var s: float = float(chosen[2]) * rng.randf_range(0.8, 1.2)
	sprite.scale = Vector2(s * (-1.0 if rng.randf() < 0.5 else 1.0), s)
	sprite.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 6.0 / s)
	sprite.position = foot
	parent.add_child(sprite)
	if name == "sulfur_crystal" or name == "demon_eye":
		_add_glow(parent, foot - Vector2(0.0, tex.get_height() * s * 0.5), 0.55, rng,
			Color(1.0, 0.85, 0.2, 0.55) if name == "sulfur_crystal" else Color(1.0, 0.2, 0.1, 0.6))


## Plataforma delgada: a veces una cadena corta cuelga de un extremo.
static func _decorate_thin(parent: Node2D, rect: Rect2, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.45:
		return
	var x: float = rect.position.x + 16.0 if rng.randf() < 0.5 else rect.end.x - 16.0
	_add_hanger(parent, Vector2(x, rect.end.y - 4.0), rng.randf_range(50.0, 110.0), false, rng)


## Cadenas y jaulas que cuelgan desde arriba de la vista, cada tanto, balanceándose.
static func _place_hangers(parent: Node2D, level_end: float, rng: RandomNumberGenerator) -> void:
	var x: float = rng.randf_range(500.0, 900.0)
	while x < level_end - 300.0:
		var with_cage: bool = rng.randf() < 0.4
		_add_hanger(parent, Vector2(x, HANG_TOP), rng.randf_range(170.0, 330.0), with_cage, rng)
		x += rng.randf_range(650.0, 1300.0)


## Cadena de `length` px desde `anchor`, con jaula opcional al final; se balancea desde el ancla.
static func _add_hanger(parent: Node2D, anchor: Vector2, length: float, with_cage: bool, rng: RandomNumberGenerator) -> void:
	var chain: Texture2D = ArtScript.tex(DIR + "chain.png")
	if chain == null:
		return
	var pivot: Node2D = Node2D.new()
	pivot.position = anchor
	pivot.modulate = Color(0.7, 0.64, 0.64, 1.0)
	parent.add_child(pivot)
	var chain_scale: float = 0.5
	var links: TextureRect = TextureRect.new()
	links.texture = chain
	links.stretch_mode = TextureRect.STRETCH_TILE
	links.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	links.size = Vector2(chain.get_width(), length / chain_scale)
	links.scale = Vector2(chain_scale, chain_scale)
	links.position = Vector2(-chain.get_width() * chain_scale * 0.5, 0.0)
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot.add_child(links)
	if with_cage:
		var cage: Texture2D = ArtScript.tex(DIR + "hanging_cage.png")
		if cage != null:
			# La jaula trae su propio tramo de cadena arriba: se apoya sobre el final de la cadena
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = cage
			sprite.centered = false
			var s: float = rng.randf_range(0.32, 0.42)
			sprite.scale = Vector2(s, s)
			sprite.offset = Vector2(-cage.get_width() * 0.5, 0.0)
			sprite.position = Vector2(0.0, length - 20.0)
			pivot.add_child(sprite)
	if pivot.is_inside_tree():
		var amp: float = deg_to_rad(rng.randf_range(1.5, 3.5) * (0.6 if with_cage else 1.0))
		var period: float = rng.randf_range(1.6, 2.6) * (1.3 if with_cage else 1.0)
		pivot.rotation = -amp
		var swing: Tween = pivot.create_tween().set_loops()
		swing.tween_property(pivot, "rotation", amp, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		swing.tween_property(pivot, "rotation", -amp, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ==============================================================================
# Lava
# ==============================================================================

## Pozos de lava: huecos entre suelos a la misma altura sin nada sólido debajo (sin lecho de roca).
static func _add_lava_pits(parent: Node2D, solids: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var floors: Array[Rect2] = []
	for rect: Rect2 in solids:
		if rect.size.y > THIN_MAX_HEIGHT and rect.size.x >= 60.0 and rect.size.y < 400.0:
			floors.append(rect)
	for a: Rect2 in floors:
		# El suelo más cercano a la derecha de `a` a la misma altura
		var best: Rect2 = Rect2()
		var found: bool = false
		for b: Rect2 in floors:
			if b.position.x < a.end.x - 1.0 or absf(b.position.y - a.position.y) > 40.0:
				continue
			if not found or b.position.x < best.position.x:
				best = b
				found = true
		if not found:
			continue
		var gap: float = best.position.x - a.end.x
		if gap < LAVA_MIN_GAP or gap > LAVA_MAX_GAP:
			continue
		var top: float = maxf(a.position.y, best.position.y)
		if _solid_below_gap(solids, a.end.x, best.position.x, top):
			continue
		_add_lava(parent, Rect2(a.end.x - 4.0, top + LAVA_DEPTH, gap + 8.0, 1200.0), rng)


static func _solid_below_gap(solids: Array[Rect2], x0: float, x1: float, top: float) -> bool:
	for other: Rect2 in solids:
		if other.position.x >= x1 or other.end.x <= x0:
			continue
		if other.end.y > top + 1.0:
			return true
	return false


## La lava quema al tocarla: daño por porcentaje de vida, llama de estado y un rebote hacia arriba que deja salir
## del pozo (si se cae más allá, el abismo del nivel sigue matando).
static func _add_lava_hazard(parent: Node2D, area: Rect2) -> void:
	var zone: Area2D = Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2 # cuerpo del jugador
	zone.position = area.get_center()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = area.size
	shape.shape = rect
	zone.add_child(shape)
	zone.body_entered.connect(func(body: Node2D) -> void: _on_lava_touched(body))
	parent.add_child(zone)


static func _on_lava_touched(body: Node2D) -> void:
	if not body.has_method("take_damage") or not ("velocity" in body):
		return
	var max_hp: float = 100.0
	var stats: Object = body.get("stats_manager")
	if stats != null and stats.has_method("get_max_health"):
		max_hp = float(stats.call("get_max_health"))
	body.call("take_damage", max_hp * LAVA_DAMAGE_FRACTION)
	var status: Node = body.get_node_or_null("StatusReceiverComponent")
	if status != null and status.has_method("apply_fire"):
		status.call("apply_fire", 2)
	body.set("velocity", Vector2(float(body.get("velocity").x), -LAVA_BOUNCE))


static func _add_lava(parent: Node2D, area: Rect2, rng: RandomNumberGenerator) -> void:
	if _lava_shader == null:
		_lava_shader = Shader.new()
		_lava_shader.code = LAVA_SHADER_CODE
	var lava: ColorRect = ColorRect.new()
	lava.position = area.position
	lava.size = area.size
	lava.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _lava_shader
	mat.set_shader_parameter("rect_size", area.size)
	lava.material = mat
	parent.add_child(lava)
	_add_lava_hazard(parent, area)
	# Resplandor que sube del pozo y brasas que saltan de la superficie
	var glow: Sprite2D = Sprite2D.new()
	glow.texture = _get_rise_texture()
	glow.centered = false
	glow.position = Vector2(area.position.x, area.position.y - 110.0)
	glow.scale = Vector2(area.size.x / 64.0, 110.0 / 64.0)
	glow.material = _additive()
	parent.add_child(glow)
	if glow.is_inside_tree():
		var beat: Tween = glow.create_tween().set_loops()
		beat.tween_property(glow, "modulate:a", 0.6, rng.randf_range(0.9, 1.4)).set_trans(Tween.TRANS_SINE)
		beat.tween_property(glow, "modulate:a", 1.0, rng.randf_range(0.9, 1.4)).set_trans(Tween.TRANS_SINE)
	_add_rising(parent, Vector2(area.get_center().x, area.position.y), area.size.x, rng, 2.5)


## Las grietas de lava del suelo y de la costra laten (shader sobre las texturas que puso LevelSkin).
static func _pulse_ground(node: Node) -> void:
	# Se compara la textura (Art.tex cachea): la de un PNG sin importar no trae resource_path
	var pulsing: Array[Texture2D] = []
	for file: String in PULSING:
		var tex: Texture2D = ArtScript.tex(DIR + file)
		if tex != null:
			pulsing.append(tex)
	if not pulsing.is_empty():
		_pulse_textures(node, pulsing, _pulse_material())


static func _pulse_textures(node: Node, pulsing: Array[Texture2D], mat: ShaderMaterial) -> void:
	for child: Node in node.get_children():
		var tiled: TextureRect = child as TextureRect
		if tiled != null and pulsing.has(tiled.texture):
			tiled.material = mat
		_pulse_textures(child, pulsing, mat)


static func _pulse_material() -> ShaderMaterial:
	if _pulse_shader == null:
		_pulse_shader = Shader.new()
		_pulse_shader.code = PULSE_SHADER_CODE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _pulse_shader
	return mat


# ==============================================================================
# Brillo y partículas
# ==============================================================================

## Brillo aditivo que titila (fuego de brasero, cristal, ojo).
static func _add_glow(parent: Node2D, center: Vector2, size: float, rng: RandomNumberGenerator,
		tint: Color = Color(1.0, 0.55, 0.15, 0.85)) -> void:
	var glow: Sprite2D = Sprite2D.new()
	glow.texture = _get_glow_texture()
	glow.position = center
	glow.scale = Vector2(size, size)
	glow.modulate = tint
	glow.material = _additive()
	parent.add_child(glow)
	if not glow.is_inside_tree():
		return
	var a: float = tint.a
	var flicker: Tween = glow.create_tween().set_loops()
	flicker.tween_property(glow, "modulate:a", a * 0.55, rng.randf_range(0.06, 0.12))
	flicker.tween_property(glow, "modulate:a", a * 0.95, rng.randf_range(0.08, 0.16))
	flicker.tween_property(glow, "modulate:a", a * 0.7, rng.randf_range(0.05, 0.1))
	flicker.tween_property(glow, "modulate:a", a, rng.randf_range(0.1, 0.2))


static func _add_flame_embers(parent: Node2D, center: Vector2, rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = ArtScript.tex(DIR + "ember.png")
	if tex == null:
		return
	var p: CPUParticles2D = _particles(tex, 5, 1.6)
	p.position = center
	p.emission_rect_extents = Vector2(10.0, 4.0)
	p.spread = 25.0
	p.gravity = Vector2(0.0, -30.0)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.45
	p.material = _additive()
	parent.add_child(p)


## Brasas y ceniza que suben de una franja de `width` px centrada en `center`.
static func _add_rising(parent: Node2D, center: Vector2, width: float, rng: RandomNumberGenerator, density: float = 1.0) -> void:
	var ember: Texture2D = ArtScript.tex(DIR + "ember.png")
	if ember != null:
		var p: CPUParticles2D = _particles(ember, clampi(int(width / 140.0 * density), 2, 40), 4.5)
		p.position = center
		p.emission_rect_extents = Vector2(width * 0.5, 6.0)
		p.spread = 20.0
		p.gravity = Vector2(rng.randf_range(-4.0, 4.0), -12.0)
		p.initial_velocity_min = 18.0
		p.initial_velocity_max = 55.0
		p.scale_amount_min = 0.2
		p.scale_amount_max = 0.45
		p.material = _additive()
		parent.add_child(p)
	var ash: Texture2D = ArtScript.tex(DIR + "ash.png")
	if ash != null:
		var q: CPUParticles2D = _particles(ash, clampi(int(width / 260.0 * density), 1, 20), 7.0)
		q.position = center - Vector2(0.0, 30.0)
		q.emission_rect_extents = Vector2(width * 0.5, 30.0)
		q.spread = 40.0
		q.gravity = Vector2(5.0, -5.0)
		q.initial_velocity_min = 6.0
		q.initial_velocity_max = 18.0
		q.angular_velocity_min = -90.0
		q.angular_velocity_max = 90.0
		q.angle_min = 0.0
		q.angle_max = 360.0
		q.scale_amount_min = 0.4
		q.scale_amount_max = 0.8
		q.modulate = Color(0.75, 0.7, 0.7, 0.8)
		parent.add_child(q)


## Partículas hacia arriba que aparecen y se desvanecen.
static func _particles(tex: Texture2D, amount: int, lifetime: float) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.randomness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0.0, -1.0)
	p.damping_min = 2.0
	p.damping_max = 6.0
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 1))
	fade.add_point(0.7, Color(1, 1, 1, 0.8))
	p.color_ramp = fade
	return p


static func _additive() -> CanvasItemMaterial:
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


## Mancha radial suave (64 px) para los brillos.
static func _get_glow_texture() -> Texture2D:
	if _glow_tex == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_glow_tex = tex
	return _glow_tex


## Degradé vertical (64 px) naranja abajo y transparente arriba: resplandor sobre la lava.
static func _get_rise_texture() -> Texture2D:
	if _rise_tex == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(1.0, 0.4, 0.08, 0.0))
		gradient.set_color(1, Color(1.0, 0.4, 0.08, 0.22))
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill_from = Vector2(0.5, 0.0)
		tex.fill_to = Vector2(0.5, 1.0)
		tex.width = 64
		tex.height = 64
		_rise_tex = tex
	return _rise_tex


# ==============================================================================
# Consultas de espacio
# ==============================================================================

## true si otro sólido apoya sobre la cara superior de `rect` en la columna `x` (bloque, pedestal, pared).
static func _covered_top(rect: Rect2, solids: Array[Rect2], x: float) -> bool:
	for other: Rect2 in solids:
		if other == rect:
			continue
		if x < other.position.x or x > other.end.x:
			continue
		if other.position.y < rect.position.y + 2.0 and other.end.y > rect.position.y - 6.0:
			return true
	return false


## true si no hay ningún sólido en `height` px por encima de la cara superior en la columna `x`.
static func _free_above(rect: Rect2, solids: Array[Rect2], x: float, height: float) -> bool:
	var probe: Rect2 = Rect2(Vector2(x - 20.0, rect.position.y - height), Vector2(40.0, height - 2.0))
	for other: Rect2 in solids:
		if other == rect:
			continue
		if probe.intersects(other):
			return false
	return true
