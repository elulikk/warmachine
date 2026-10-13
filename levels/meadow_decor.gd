extends RefCounted
## Decoración del Mundo 2 (Valle Esmeralda): árboles detrás del escenario, pasto y flores sobre los suelos,
## todo meciéndose con el viento, y hojas que caen de las copas. Solo dibujo: no toca colisiones.
## Sin class_name: la llama LevelSkin (`preload`) al revestir un nivel del capítulo 2.
##
## La ubicación es determinista (semilla = nombre del nivel): el mismo nivel siempre se ve igual.
## Arte en `assets/art/world2/` (Google Flow, ver `art_source/world2/process.py`).

const ArtScript = preload("res://core/art/art.gd")

const DIR: String = "res://assets/art/world2/"

## Suelos más angostos que esto no se decoran (bloques de salto, pedestales).
const MIN_GROUND_WIDTH: float = 110.0
## Las plataformas delgadas solo llevan alguna matita.
const THIN_MAX_HEIGHT: float = 40.0
## Espacio libre que necesita un árbol por encima del suelo.
const TREE_CLEARANCE: float = 300.0

const TREES: Array[String] = ["tree_oak", "tree_pine", "tree_birch", "tree_apple"]
## Árboles de hoja que sueltan hojas (el pino no).
const LEAFY: Array[String] = ["tree_oak", "tree_birch", "tree_apple"]
## Adornos de suelo con su peso relativo y escala.
const SMALL: Array = [
	["grass_tuft", 6, 0.26], ["flower_red", 3, 0.22], ["flower_yellow", 3, 0.22], ["flower_blue", 3, 0.22],
	["bush", 2, 0.34], ["mushroom", 1, 0.18], ["rock", 1, 0.26], ["fence", 1, 0.42], ["log", 1, 0.36],
]
## Los que se mecen con el viento.
const SWAYING: Array[String] = ["grass_tuft", "flower_red", "flower_yellow", "flower_blue", "bush"]

const SWAY_SHADER_CODE: String = """
shader_type canvas_item;
uniform float amp = 3.0;
uniform float speed = 1.5;
uniform float phase = 0.0;
void vertex() {
	float w = 1.0 - UV.y;
	VERTEX.x += (sin(TIME * speed + phase) + 0.35 * sin(TIME * speed * 2.3 + phase * 1.7)) * amp * w * w;
}
"""

static var _sway_shader: Shader = null


static func decorate(level: Node, solids: Array[Rect2]) -> void:
	if level.has_node("MeadowDecorBack"):
		return
	var environment: Node = level.get_node_or_null("Environment")
	var back: Node2D = Node2D.new()
	back.name = "MeadowDecorBack"
	back.z_index = -1
	back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var front: Node2D = Node2D.new()
	front.name = "MeadowDecorFront"
	front.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	level.add_child(back)
	level.add_child(front)
	# Delante del suelo pero detrás de jugador y enemigos
	if environment != null:
		level.move_child(front, environment.get_index() + 1)
		level.move_child(back, environment.get_index())

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(level.name))

	for rect: Rect2 in solids:
		if rect.size.x < MIN_GROUND_WIDTH:
			continue
		var top: float = rect.position.y
		if rect.size.y <= THIN_MAX_HEIGHT:
			_decorate_thin(front, rect, solids, rng)
			continue
		_place_trees(back, rect, solids, rng)
		var x: float = rect.position.x + rng.randf_range(10.0, 50.0)
		while x < rect.end.x - 12.0:
			if not _covered_top(rect, solids, x) and _free_above(rect, solids, x, 40.0):
				_place_small(front, Vector2(x, top), rng)
			x += rng.randf_range(34.0, 95.0)


# ==============================================================================
# Colocación
# ==============================================================================

static func _place_trees(parent: Node2D, rect: Rect2, solids: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var x: float = rect.position.x + rng.randf_range(60.0, 260.0)
	while x < rect.end.x - 60.0:
		if not _covered_top(rect, solids, x - 40.0) and not _covered_top(rect, solids, x + 40.0) \
				and _free_above(rect, solids, x, TREE_CLEARANCE):
			var kind: String = TREES[rng.randi_range(0, TREES.size() - 1)]
			var tex: Texture2D = ArtScript.tex(DIR + kind + ".png")
			if tex != null:
				var tree: Sprite2D = Sprite2D.new()
				tree.texture = tex
				tree.centered = false
				var s: float = rng.randf_range(0.5, 0.72)
				tree.scale = Vector2(s * (-1.0 if rng.randf() < 0.5 else 1.0), s)
				tree.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 14.0)
				tree.position = Vector2(x, rect.position.y)
				tree.material = _sway_material(1.1, 3.0 / s, x * 0.01)
				# Un poco más oscuro: queda como segundo plano
				tree.modulate = Color(0.88, 0.92, 0.88, 1.0)
				parent.add_child(tree)
				if LEAFY.has(kind):
					_add_leaves(parent, Vector2(x, rect.position.y - tex.get_height() * s * 0.62), tex.get_width() * s * 0.7, rng)
		x += rng.randf_range(280.0, 560.0)


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
	if SWAYING.has(name):
		sprite.material = _sway_material(rng.randf_range(1.2, 2.2), rng.randf_range(2.0, 4.0) / s, foot.x * 0.013)
	parent.add_child(sprite)


## Plataforma delgada: una o dos matitas de pasto en los extremos.
static func _decorate_thin(parent: Node2D, rect: Rect2, solids: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = ArtScript.tex(DIR + "grass_tuft.png")
	if tex == null or rng.randf() < 0.4:
		return
	for x: float in [rect.position.x + 14.0, rect.end.x - 14.0]:
		if rng.randf() < 0.5 or not _free_above(rect, solids, x, 30.0):
			continue
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		var s: float = 0.16
		sprite.scale = Vector2(s, s)
		sprite.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 4.0 / s)
		sprite.position = Vector2(x, rect.position.y)
		sprite.material = _sway_material(1.8, 2.5 / s, x * 0.02)
		parent.add_child(sprite)


## Hojas que se desprenden de la copa y caen girando con una leve deriva.
static func _add_leaves(parent: Node2D, canopy_center: Vector2, width: float, rng: RandomNumberGenerator) -> void:
	var leaf: Texture2D = ArtScript.tex(DIR + ("leaf_orange.png" if rng.randf() < 0.3 else "leaf_green.png"))
	if leaf == null:
		return
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.texture = leaf
	particles.position = canopy_center
	particles.amount = 3
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.randomness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(width * 0.5, 30.0)
	particles.direction = Vector2(1.0, 0.4)
	particles.spread = 50.0
	particles.gravity = Vector2(6.0, 22.0)
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 26.0
	particles.angular_velocity_min = -120.0
	particles.angular_velocity_max = 120.0
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.6
	particles.damping_min = 2.0
	particles.damping_max = 6.0
	# Se desvanece al final de la caída
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	particles.color_ramp = fade
	parent.add_child(particles)


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


static func _sway_material(speed: float, amp: float, phase: float) -> ShaderMaterial:
	if _sway_shader == null:
		_sway_shader = Shader.new()
		_sway_shader.code = SWAY_SHADER_CODE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _sway_shader
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("amp", amp)
	mat.set_shader_parameter("phase", phase)
	return mat
