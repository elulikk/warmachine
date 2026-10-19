extends RefCounted
## Decoración del Mundo 1 (El Presente): mobiliario urbano según el sector (faroles, hidrantes, contenedores,
## cercas, bitas, sillones, parlantes...), lluvia y relámpagos en los exteriores, autos que cruzan por el fondo,
## luces y bola de espejos en la discoteca, y agua en los pozos entre muelles y canales.
## Los objetos de `SOLID_PROPS` (contenedores, tachos, buzones, bancas, cajas...) son sólidos: se agrupan en
## escalones de alturas distintas para saltar de uno al otro, y los enemigos los sortean (`obstacle_hop.gd`).
## El resto es solo dibujo. Sin class_name: la llama LevelSkin (`preload`, tema del capítulo 1).
##
## La ubicación es determinista (semilla = nombre del nivel). Arte en `assets/art/world1/`
## (Google Flow, ver `art_source/world1/process.py`).

const ArtScript = preload("res://core/art/art.gd")
const SettingsScript = preload("res://core/settings.gd")

const DIR: String = "res://assets/art/world1/"

const MIN_GROUND_WIDTH: float = 110.0
const THIN_MAX_HEIGHT: float = 40.0
## Ancho mínimo de un sólido para que le caigan salpicaduras de lluvia.
const SPLASH_MIN_WIDTH: float = 24.0
## Lluvia: altura de la que nacen las gotas, inclinación (dx por dy), velocidad y ancho de cada columna emisora.
const RAIN_TOP: float = -20.0
const RAIN_SLANT: float = 0.22
const RAIN_SPEED: float = 980.0
const RAIN_STRIP: float = 48.0
## Las lámparas del techo cuelgan desde arriba de lo que muestra la cámara (limit_top = 60).
const HANG_TOP: float = -40.0

## Por sector: lluvia, autos, relámpagos y objetos de suelo [nombre, peso, alto en juego (px)].
const SECTORS: Dictionary = {
	# 1-01: calle limpia, sin objetos de suelo (tutorial del cuchillo y el asaltante); solo faroles con cono de luz
	"1_01": {"rain": true, "cars": true, "props": [], "lamps": 640.0},
	"1_02": {"rain": true, "cars": false, "props": [
		["fire_ladder", 1, 150.0], ["trash_bags", 3, 44.0], ["wet_boxes", 3, 48.0], ["steam_grate", 2, 60.0], ["rust_pipe", 1, 40.0],
		["barrel", 2, 52.0], ["dumpster", 2, 50.0], ["street_lamp", 1, 120.0]]},
	"1_03": {"rain": false, "cars": false, "water": true, "props": [
		["rust_pipe", 2, 40.0], ["valve", 2, 40.0], ["sewer_grate", 1, 50.0], ["puddle", 3, 14.0], ["barrel", 2, 52.0],
		["iron_ladder", 1, 120.0], ["steam_grate", 1, 60.0], ["trash_bags", 1, 40.0]]},
	# 1-04: la torre y los techos. Props de azotea solo sobre los techos exteriores (`prop_max_y`); sin lluvia (cae desde y = -20)
	"1_04": {"rain": false, "cars": false, "prop_max_y": -990.0, "props": [
		["water_tank", 1, 150.0], ["antenna", 2, 150.0], ["vent_chimney", 2, 100.0], ["roof_sign", 1, 90.0],
		["safety_rail", 3, 36.0], ["vent_duct", 2, 50.0]]},
	"1_05": {"rain": true, "cars": false, "water": true, "props": [
		["bollard", 3, 36.0], ["buoy", 2, 48.0], ["crates", 3, 60.0], ["oil_barrel", 3, 50.0], ["rope_coil", 2, 24.0],
		["dock_lamp", 2, 110.0]]},
	"1_06": {"rain": false, "cars": false, "hang": "chandelier", "props": [
		["armchair", 3, 56.0], ["big_plant", 3, 80.0], ["luggage_cart", 2, 70.0], ["reception_desk", 1, 60.0]]},
	"1_07": {"rain": false, "cars": false, "hang": "disco_ball", "club": true, "props": [
		["speaker", 3, 80.0], ["dj_console", 1, 55.0], ["bar_counter", 2, 60.0], ["stage_light", 2, 70.0]]},
	"1_08": {"rain": true, "cars": false, "props": [
		["water_tank", 1, 150.0], ["ac_unit", 3, 60.0], ["antenna", 2, 150.0], ["vent_chimney", 2, 100.0],
		["roof_sign", 1, 90.0], ["safety_rail", 3, 36.0], ["vent_duct", 2, 50.0], ["heli_spot", 1, 60.0]]},
}
## Props que llevan un brillo cálido en la cabeza y su color.
const GLOWS: Dictionary = {
	"street_lamp": Color(1.0, 0.72, 0.3, 0.8), "dock_lamp": Color(1.0, 0.75, 0.35, 0.75),
	"traffic_light": Color(1.0, 0.25, 0.2, 0.6), "stage_light": Color(0.9, 0.4, 1.0, 0.7),
	"bar_sign": Color(1.0, 0.2, 0.3, 0.6), "heli_spot": Color(1.0, 0.3, 0.2, 0.5),
}
## Objetos sólidos: alto en juego [mínimo, máximo] (px). El salto del jugador llega a ~138 px, así que ninguno
## pasa de 115, salvo la cabina telefónica y el contenedor (124, que se saltan de punta); en un grupo los extremos se acotan a END_MAX
## para que se pueda subir desde el suelo.
const SOLID_PROPS: Dictionary = {
	"trash_can": [56.0, 76.0], "house_mailbox": [60.0, 80.0], "mailbox": [54.0, 62.0],
	"dumpster": [118.0, 124.0], "barrel": [64.0, 84.0], "oil_barrel": [66.0, 86.0], "crates": [84.0, 110.0],
	"wet_boxes": [76.0, 100.0], "trash_bags": [52.0, 70.0], "ac_unit": [70.0, 100.0],
	"phone_booth": [118.0, 124.0],
}
const END_MAX: float = 90.0
## Diferencia máxima de altura entre dos escalones vecinos.
const STEP_MAX: float = 56.0
## Aire libre sobre cada objeto sólido (que entre el jugador).
const HEADROOM: float = 70.0
## Distancia mínima a los puntos del nivel que no se deben tapar (inicio, salida, checkpoints, cinemáticas).
const AVOID_RADIUS: float = 170.0
## Franja libre de objetos a cada lado del centro de una arena (antes y después del encuentro).
const ARENA_CLEAR: float = 900.0
const CAR_FILES: Array[String] = ["car_sedan", "car_taxi", "car_pickup", "car_police"]
## Faroles con cono de luz (`lamps` en SECTORS = separación media en px): alto en juego, ancho del cono en el suelo,
## color de la luz y cada cuántos faroles uno anda mal y parpadea.
const LAMP_HEIGHT: float = 150.0
const LAMP_CONE_WIDTH: float = 260.0
const LAMP_LIGHT: Color = Color(1.0, 0.74, 0.38, 1.0)
const LAMP_BROKEN_EVERY: int = 4
const CLUB_COLORS: Array[Color] = [
	Color(1.0, 0.2, 0.6, 0.16), Color(0.2, 0.9, 1.0, 0.16), Color(0.6, 0.3, 1.0, 0.18), Color(1.0, 0.8, 0.2, 0.12),
]

static var _arena_x: Array[float] = []
static var _prop_spans: Array[Vector2] = []
static var _glow_tex: Texture2D = null
static var _rain_tex: Texture2D = null
static var _splash_tex: Texture2D = null


static func decorate(level: Node, solids: Array[Rect2]) -> void:
	if level.has_node("CityDecorBack"):
		return
	var level_id: String = str(level.get("level_id")) if "level_id" in level else "1_01"
	var cfg: Dictionary = SECTORS.get(level_id, SECTORS["1_01"]) as Dictionary
	var environment: Node = level.get_node_or_null("Environment")
	var back: Node2D = Node2D.new()
	back.name = "CityDecorBack"
	back.z_index = -1
	back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var front: Node2D = Node2D.new()
	front.name = "CityDecorFront"
	front.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	level.add_child(back)
	level.add_child(front)
	if environment != null:
		level.move_child(front, environment.get_index() + 1)
		level.move_child(back, environment.get_index())

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(level.name))
	var props: Array = cfg.get("props", []) as Array

	var avoid: Array[float] = _avoid_points(level)
	_arena_x = _arena_centers(level)
	_prop_spans = _baked_spans(level)

	var level_end: float = 0.0
	var max_y: float = float(cfg.get("prop_max_y", INF))
	for rect: Rect2 in solids:
		level_end = maxf(level_end, rect.end.x)
		if rect.size.x < MIN_GROUND_WIDTH or rect.size.y <= THIN_MAX_HEIGHT or rect.position.y > max_y:
			continue
		var x: float = rect.position.x + rng.randf_range(40.0, 140.0)
		while x < rect.end.x - 30.0:
			if not _covered_top(rect, solids, x):
				x = maxf(x, _place_prop(back, front, rect, solids, x, props, rng, avoid))
			x += rng.randf_range(130.0, 330.0)

	if cfg.has("hang"):
		_place_hanging(back, str(cfg["hang"]), level_end, rng)
	if cfg.has("lamps"):
		_add_street_lamps(back, front, solids, float(cfg["lamps"]), rng)
	if bool(cfg.get("water", false)):
		_add_water_pits(back, solids, rng)
	if bool(cfg.get("club", false)):
		_add_club_lights(level, rng)
	if bool(cfg.get("rain", false)):
		_add_rain(level, solids)
	if bool(cfg.get("cars", false)):
		_add_cars(level, rng)


# ==============================================================================
# Objetos de suelo
# ==============================================================================

## Pone un objeto de suelo en `x` y devuelve el borde derecho que ocupa (para no apilar encima).
## Los sólidos (`SOLID_PROPS`) no van acá: son props del nivel horneados (ver `plan_solids`).
static func _place_prop(back: Node2D, front: Node2D, rect: Rect2, solids: Array[Rect2], x: float, props: Array,
		rng: RandomNumberGenerator, avoid: Array[float]) -> float:
	if props.is_empty():
		return x
	var chosen: Array = _pick_entry(props, rng)
	var name: String = str(chosen[0])
	if SOLID_PROPS.has(name):
		return x
	var target_h: float = float(chosen[2]) * rng.randf_range(0.9, 1.1)
	if not _free_above(rect, solids, x, target_h + 20.0):
		return x
	var tex: Texture2D = ArtScript.tex(DIR + name + ".png")
	if tex == null:
		return x
	var s: float = target_h / float(tex.get_height())
	var half_w: float = tex.get_width() * s * 0.5
	if _in_arena_zone(x, half_w) or _in_prop_span(x, half_w):
		return x
	for point: float in avoid:
		if absf(point - x) < AVOID_RADIUS + half_w:
			return x
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	var flip: float = -1.0 if rng.randf() < 0.5 and not GLOWS.has(name) else 1.0
	sprite.scale = Vector2(s * flip, s)
	sprite.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 4.0 / s)
	sprite.position = Vector2(x, rect.position.y)
	# Los objetos altos quedan detrás del jugador; los bajos delante (como la maleza)
	(back if target_h >= 90.0 else front).add_child(sprite)
	if GLOWS.has(name):
		_add_glow(back, Vector2(x, rect.position.y - target_h * 0.88), target_h / 55.0, GLOWS[name] as Color, rng)
	return x


## Elige un tipo de objeto de `props` según su peso.
static func _pick_entry(props: Array, rng: RandomNumberGenerator) -> Array:
	var total: int = 0
	for entry: Array in props:
		total += int(entry[1])
	var pick: int = rng.randi_range(1, total)
	for entry: Array in props:
		pick -= int(entry[1])
		if pick <= 0:
			return entry
	return props[0] as Array


## Obstáculos sólidos del nivel: lista de props (nombre, centro x, base y, ancho, alto, espejado) que se hornea en
## el .tscn con art_source/world1/bake_decor_props.gd. En juego no se generan: son nodos `WorldProp` del nivel.
static func plan_solids(level: Node, solids: Array[Rect2]) -> Array[Dictionary]:
	var level_id: String = str(level.get("level_id")) if "level_id" in level else "1_01"
	var cfg: Dictionary = SECTORS.get(level_id, SECTORS["1_01"]) as Dictionary
	var props: Array = cfg.get("props", []) as Array
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(level.name))
	var avoid: Array[float] = _avoid_points(level)
	_arena_x = _arena_centers(level)
	var plan: Array[Dictionary] = []
	for rect: Rect2 in solids:
		if rect.size.x < MIN_GROUND_WIDTH or rect.size.y <= THIN_MAX_HEIGHT:
			continue
		var x: float = rect.position.x + rng.randf_range(40.0, 140.0)
		while x < rect.end.x - 30.0:
			if not _covered_top(rect, solids, x):
				var chosen: Array = _pick_entry(props, rng)
				if SOLID_PROPS.has(str(chosen[0])):
					x = maxf(x, _plan_solid_group(plan, rect, solids, x, props, str(chosen[0]), rng, avoid))
			x += rng.randf_range(130.0, 330.0)
	return plan


## Grupo de 1 a 3 objetos sólidos pegados, de alturas distintas y escalonadas (subida, bajada o pico).
## Agrega cada objeto a `plan` y devuelve el borde derecho del último.
static func _plan_solid_group(plan: Array[Dictionary], rect: Rect2, solids: Array[Rect2], x: float, props: Array,
		first: String, rng: RandomNumberGenerator, avoid: Array[float]) -> float:
	var pool: Array[String] = []
	for entry: Array in props:
		if SOLID_PROPS.has(str(entry[0])) and not pool.has(str(entry[0])):
			pool.append(str(entry[0]))
	var count: int = 1 + (1 if rng.randf() < 0.75 else 0) + (1 if rng.randf() < 0.4 else 0)
	var names: Array[String] = [first]
	for i: int in count - 1:
		names.append(pool[rng.randi_range(0, pool.size() - 1)])
	# Alturas: ordenadas de menor a mayor y luego en subida, bajada o pico
	var heights: Array[float] = []
	for n: String in names:
		var range_h: Array = SOLID_PROPS[n] as Array
		heights.append(rng.randf_range(float(range_h[0]), float(range_h[1])))
	var order: Array[int] = []
	for i: int in names.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return heights[a] < heights[b])
	var mode: int = rng.randi_range(0, 2)
	if mode == 1:
		order.reverse()
	elif mode == 2 and order.size() == 3:
		order = [order[0], order[2], order[1]]
	var seq_names: Array[String] = []
	var seq_h: Array[float] = []
	for i: int in order:
		seq_names.append(names[i])
		seq_h.append(heights[i])
	if seq_h.size() > 1:
		seq_h[0] = minf(seq_h[0], END_MAX)
		seq_h[seq_h.size() - 1] = minf(seq_h[seq_h.size() - 1], END_MAX)
		for i: int in range(1, seq_h.size()):
			seq_h[i] = clampf(seq_h[i], seq_h[i - 1] - STEP_MAX, seq_h[i - 1] + STEP_MAX)
	var ground_y: float = rect.position.y
	var cursor: float = x
	var edge: float = x
	var flip: float = -1.0 if rng.randf() < 0.5 else 1.0
	for i: int in seq_names.size():
		var tex: Texture2D = ArtScript.tex(DIR + seq_names[i] + ".png")
		if tex == null:
			break
		var h: float = seq_h[i]
		var s: float = h / float(tex.get_height())
		var w: float = tex.get_width() * s
		var left: float = cursor
		if i > 0:
			# Nunca hacia atrás: un objeto encima de la punta del anterior lo tapa
			left += rng.randf_range(0.0, 8.0)
		var item: Rect2 = Rect2(left, ground_y - h, w, h)
		if item.position.x < rect.position.x + 24.0 or item.end.x > rect.end.x - 24.0:
			break
		if _in_arena_zone(item.get_center().x, w * 0.5):
			break
		var probe: Rect2 = Rect2(item.position.x, item.position.y - HEADROOM, w, h + HEADROOM - 2.0)
		var blocked: bool = false
		for other: Rect2 in solids:
			if other != rect and probe.intersects(other):
				blocked = true
				break
		for point: float in avoid:
			if absf(point - item.get_center().x) < AVOID_RADIUS + w * 0.5:
				blocked = true
				break
		if blocked:
			break
		plan.append({"name": seq_names[i], "x": item.get_center().x, "y": ground_y, "w": w, "h": h, "flip": flip < 0.0})
		cursor = item.end.x
		edge = item.end.x
	return edge


## Props horneados del nivel (nodo `Props`, grupo `decor_prop`): la decoración de suelo no los tapa.
static func _baked_spans(level: Node) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	var holder: Node = level.get_node_or_null("Props")
	if holder == null:
		return spans
	for child: Node in holder.get_children():
		var node: Node2D = child as Node2D
		if node == null or not node.is_in_group(&"decor_prop"):
			continue
		var half_w: float = (node.get("size") as Vector2).x * 0.5
		spans.append(Vector2(node.position.x - half_w, node.position.x + half_w))
	return spans


static func _in_prop_span(x: float, half_w: float) -> bool:
	for span: Vector2 in _prop_spans:
		if x + half_w > span.x and x - half_w < span.y:
			return true
	return false


## Centros x de las arenas del nivel (nodos `Arena*`): alrededor de cada uno no hay objetos de decoración.
static func _arena_centers(level: Node) -> Array[float]:
	var centers: Array[float] = []
	for child: Node in level.get_children():
		if str(child.name).begins_with("Arena") and child is Node2D:
			centers.append((child as Node2D).position.x)
	return centers


## Si un objeto centrado en `x` con semiancho `half_w` cae dentro de la franja libre de alguna arena.
static func _in_arena_zone(x: float, half_w: float) -> bool:
	for center: float in _arena_x:
		if absf(center - x) < ARENA_CLEAR + half_w:
			return true
	return false


## Posiciones x del nivel que no deben quedar tapadas: jugador, enemigos, salida, checkpoints, cinemáticas, tienda...
static func _avoid_points(level: Node) -> Array[float]:
	var points: Array[float] = []
	for child: Node in level.get_children():
		var node: Node2D = child as Node2D
		if node == null or node is StaticBody2D or node is Camera2D:
			continue
		if child.name == &"Environment" or child.name == &"Props" or child.name == &"Buildings" or str(child.name).begins_with("CityDecor"):
			continue
		points.append(node.position.x)
	return points


## Faroles a lo largo del suelo (sin colisión, detrás del jugador): poste, brillo en la cabeza, cono de luz hasta
## el piso y charco de luz. Uno de cada LAMP_BROKEN_EVERY parpadea (quieto con "reducir destellos").
static func _add_street_lamps(parent: Node2D, front: Node2D, solids: Array[Rect2], spacing: float, rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = ArtScript.tex(DIR + "street_lamp.png")
	if tex == null:
		return
	var s: float = LAMP_HEIGHT / float(tex.get_height())
	var count: int = 0
	for rect: Rect2 in solids:
		if rect.size.x < MIN_GROUND_WIDTH or rect.size.y <= THIN_MAX_HEIGHT:
			continue
		var x: float = rect.position.x + rng.randf_range(200.0, spacing)
		while x < rect.end.x - 120.0:
			if not _covered_top(rect, solids, x) and _free_above(rect, solids, x, LAMP_HEIGHT + 20.0):
				_place_lamp(parent, front, tex, s, Vector2(x, rect.position.y), count % LAMP_BROKEN_EVERY == LAMP_BROKEN_EVERY - 1, rng)
				count += 1
			x += spacing * rng.randf_range(0.8, 1.2)


static func _place_lamp(parent: Node2D, front: Node2D, tex: Texture2D, s: float, base: Vector2, broken: bool, rng: RandomNumberGenerator) -> void:
	var lamp: Node2D = Node2D.new()
	lamp.position = base
	parent.add_child(lamp)
	var pole: Sprite2D = Sprite2D.new()
	pole.texture = tex
	pole.centered = false
	pole.scale = Vector2(s, s)
	pole.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 4.0 / s)
	lamp.add_child(pole)

	# Todo lo que es luz va en un nodo aparte, así el parpadeo lo apaga entero
	var light: Node2D = Node2D.new()
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = add
	lamp.add_child(light)
	var head_y: float = -LAMP_HEIGHT * 0.9
	var cone: Polygon2D = Polygon2D.new()
	cone.use_parent_material = true
	var top_w: float = 10.0
	var bottom_w: float = LAMP_CONE_WIDTH * 0.5
	cone.polygon = PackedVector2Array([
		Vector2(-top_w, head_y), Vector2(top_w, head_y), Vector2(bottom_w, 0.0), Vector2(-bottom_w, 0.0)])
	var hot: Color = Color(LAMP_LIGHT, 0.34)
	var cold: Color = Color(LAMP_LIGHT, 0.0)
	cone.vertex_colors = PackedColorArray([hot, hot, cold, cold])
	light.add_child(cone)
	var head: Sprite2D = Sprite2D.new()
	head.texture = _get_glow_texture()
	head.use_parent_material = true
	head.position = Vector2(0.0, head_y)
	head.scale = Vector2(1.6, 1.6)
	head.modulate = Color(LAMP_LIGHT, 0.85)
	light.add_child(head)
	# El charco va delante del piso (si no, el borde del suelo lo tapa); parpadea junto con el resto
	var pool_holder: Node2D = Node2D.new()
	pool_holder.position = base
	pool_holder.material = add
	front.add_child(pool_holder)
	var pool: Sprite2D = Sprite2D.new()
	pool.texture = _get_glow_texture()
	pool.use_parent_material = true
	pool.position = Vector2(0.0, 2.0)
	pool.scale = Vector2(LAMP_CONE_WIDTH / 40.0, 0.7)
	pool.modulate = Color(LAMP_LIGHT, 0.35)
	pool_holder.add_child(pool)

	if broken and not SettingsScript.reduce_flashes() and light.is_inside_tree():
		_schedule_flicker(light, pool_holder, rng.randf_range(1.5, 5.0))


## Farol que anda mal: cada tanto se corta dos o tres veces seguidas y vuelve.
static func _schedule_flicker(light: Node2D, pool: Node2D, wait: float) -> void:
	_after(light, wait, func() -> void:
		if not is_instance_valid(light) or not light.is_inside_tree() or not is_instance_valid(pool):
			return
		var tw: Tween = light.create_tween()
		for i: int in randi_range(2, 4):
			var dim: float = randf_range(0.0, 0.25)
			tw.tween_property(light, "modulate:a", dim, 0.04)
			tw.parallel().tween_property(pool, "modulate:a", dim, 0.04)
			tw.tween_interval(randf_range(0.03, 0.12))
			tw.tween_property(light, "modulate:a", 1.0, 0.04)
			tw.parallel().tween_property(pool, "modulate:a", 1.0, 0.04)
			tw.tween_interval(randf_range(0.05, 0.2))
		tw.tween_callback(func() -> void: _schedule_flicker(light, pool, randf_range(2.0, 7.0))))


## Lámparas del techo (araña de cristal del hotel, bola de espejos de la discoteca).
static func _place_hanging(parent: Node2D, name: String, level_end: float, rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = ArtScript.tex(DIR + name + ".png")
	if tex == null:
		return
	var x: float = rng.randf_range(500.0, 900.0)
	while x < level_end - 300.0:
		var length: float = rng.randf_range(90.0, 170.0)
		var line: ColorRect = ColorRect.new()
		line.color = Color(0.1, 0.1, 0.12, 1.0)
		line.position = Vector2(x - 1.0, HANG_TOP)
		line.size = Vector2(2.0, length)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(line)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		var s: float = (80.0 if name == "chandelier" else 66.0) / float(tex.get_height())
		sprite.scale = Vector2(s, s)
		sprite.offset = Vector2(-tex.get_width() * 0.5, 0.0)
		sprite.position = Vector2(x, HANG_TOP + length)
		parent.add_child(sprite)
		var center: Vector2 = sprite.position + Vector2(0.0, tex.get_height() * s * 0.5)
		if name == "disco_ball":
			if sprite.is_inside_tree():
				# Gira: el ancho oscila y el brillo late
				var spin: Tween = sprite.create_tween().set_loops()
				spin.tween_property(sprite, "scale:x", s * 0.78, 0.9).set_trans(Tween.TRANS_SINE)
				spin.tween_property(sprite, "scale:x", s, 0.9).set_trans(Tween.TRANS_SINE)
			_add_glow(parent, center, 1.4, Color(0.8, 0.9, 1.0, 0.55), rng)
		else:
			_add_glow(parent, center, 1.8, Color(1.0, 0.8, 0.45, 0.6), rng)
		x += rng.randf_range(800.0, 1500.0)


# ==============================================================================
# Agua (canales y muelle)
# ==============================================================================

## Huecos entre suelos a la misma altura sin nada debajo: agua negra con reflejos.
static func _add_water_pits(parent: Node2D, solids: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var floors: Array[Rect2] = []
	for rect: Rect2 in solids:
		if rect.size.y > THIN_MAX_HEIGHT and rect.size.x >= 60.0 and rect.size.y < 400.0:
			floors.append(rect)
	for a: Rect2 in floors:
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
		if gap < 24.0 or gap > 700.0:
			continue
		var top: float = maxf(a.position.y, best.position.y)
		if _solid_below_gap(solids, a.end.x, best.position.x, top):
			continue
		var water: ColorRect = ColorRect.new()
		water.position = Vector2(a.end.x - 4.0, top + 56.0)
		water.size = Vector2(gap + 8.0, 1200.0)
		water.color = Color(0.03, 0.05, 0.1, 1.0)
		water.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(water)
		# Línea de reflejo en la superficie
		var shine: ColorRect = ColorRect.new()
		shine.position = Vector2(a.end.x - 4.0, top + 56.0)
		shine.size = Vector2(gap + 8.0, 3.0)
		shine.color = Color(0.4, 0.7, 1.0, 0.55)
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(shine)
		if shine.is_inside_tree():
			var ripple: Tween = shine.create_tween().set_loops()
			ripple.tween_property(shine, "modulate:a", 0.35, rng.randf_range(0.8, 1.3)).set_trans(Tween.TRANS_SINE)
			ripple.tween_property(shine, "modulate:a", 1.0, rng.randf_range(0.8, 1.3)).set_trans(Tween.TRANS_SINE)


static func _solid_below_gap(solids: Array[Rect2], x0: float, x1: float, top: float) -> bool:
	for other: Rect2 in solids:
		if other.position.x >= x1 or other.end.x <= x0:
			continue
		if other.end.y > top + 1.0:
			return true
	return false


# ==============================================================================
# Capas de pantalla: lluvia, relámpagos, autos y luces de la discoteca
# ==============================================================================

## Ejecuta `action` pasados `seconds`, con un Timer hijo de `owner_node`: si el nivel se libera antes, nunca corre.
static func _after(owner_node: Node, seconds: float, action: Callable) -> void:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	owner_node.add_child(timer)
	timer.timeout.connect(func() -> void:
		timer.queue_free()
		action.call())
	timer.start()


## Entrada pública para escenas que no pasan por `decorate` (la Sala de Estrés).
static func add_rain(level: Node, solids: Array[Rect2]) -> void:
	_add_rain(level, solids)


## Lluvia en el mundo (columnas de gotas que mueren al chocar con el primer sólido, así que lo cubierto no se moja),
## salpicaduras donde pega, y un relámpago ocasional en una capa de pantalla.
static func _add_rain(level: Node, solids: Array[Rect2]) -> void:
	_add_rain_drops(level, solids)
	_add_rain_splashes(level, solids)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Rain"
	layer.layer = 2
	level.add_child(layer)

	var flash: ColorRect = ColorRect.new()
	flash.name = "Lightning"
	flash.color = Color(0.8, 0.88, 1.0, 0.0)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	_schedule_lightning(layer, flash)


## Y donde la gota que cae inclinada (RAIN_SLANT) toca primero un sólido a partir de `cx` en la altura RAIN_TOP.
static func _rain_landing(solids: Array[Rect2], cx: float, bottom: float) -> float:
	var landing: float = bottom
	for rect: Rect2 in solids:
		var top: float = rect.position.y
		if top <= RAIN_TOP or top >= landing:
			continue
		var x: float = cx - RAIN_SLANT * (top - RAIN_TOP)
		if x >= rect.position.x and x <= rect.end.x:
			landing = top
	return landing


## Columnas de gotas de RAIN_STRIP px: cada emisor vive lo que tarda su gota en llegar al primer sólido.
static func _add_rain_drops(level: Node, solids: Array[Rect2]) -> void:
	if solids.is_empty():
		return
	var min_x: float = INF
	var max_x: float = -INF
	var bottom: float = 0.0
	for rect: Rect2 in solids:
		min_x = minf(min_x, rect.position.x)
		max_x = maxf(max_x, rect.end.x)
		bottom = maxf(bottom, rect.end.y)
	bottom += 40.0
	var holder: Node2D = Node2D.new()
	holder.name = "RainDrops"
	holder.z_index = 20
	level.add_child(holder)
	var density: float = SettingsScript.particle_scale()
	var norm: float = sqrt(1.0 + RAIN_SLANT * RAIN_SLANT)
	var cx: float = min_x
	var end_x: float = max_x + RAIN_SLANT * (bottom - RAIN_TOP) + RAIN_STRIP
	while cx < end_x:
		var land: float = _rain_landing(solids, cx, bottom)
		var fall: float = land - RAIN_TOP
		var drops: CPUParticles2D = CPUParticles2D.new()
		drops.texture = _get_rain_texture()
		drops.lifetime = fall * norm / RAIN_SPEED
		drops.preprocess = drops.lifetime
		drops.amount = maxi(1, roundi(3.5 * drops.lifetime / 0.8 * density))
		drops.local_coords = false
		drops.position = Vector2(cx, RAIN_TOP)
		drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		drops.emission_rect_extents = Vector2(RAIN_STRIP * 0.5, 2.0)
		drops.direction = Vector2(-RAIN_SLANT, 1.0)
		drops.spread = 0.0
		drops.gravity = Vector2.ZERO
		drops.initial_velocity_min = RAIN_SPEED
		drops.initial_velocity_max = RAIN_SPEED
		drops.particle_flag_align_y = true
		drops.modulate = Color(0.7, 0.8, 1.0, 0.5)
		holder.add_child(drops)
		cx += RAIN_STRIP


## Tramos del borde superior de `rect` donde la lluvia llega: lo tapado por un sólido más alto se descarta.
static func _rain_exposed(rect: Rect2, solids: Array[Rect2]) -> Array[Vector2]:
	var blocked: Array[Vector2] = []
	for other: Rect2 in solids:
		if other == rect or other.position.y >= rect.position.y - 1.0:
			continue
		var shift: float = RAIN_SLANT * (rect.position.y - other.position.y)
		var from_x: float = other.position.x - shift
		var to_x: float = other.end.x - shift
		if to_x > rect.position.x and from_x < rect.end.x:
			blocked.append(Vector2(from_x, to_x))
	blocked.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var open: Array[Vector2] = []
	var cursor: float = rect.position.x
	for span: Vector2 in blocked:
		if span.x > cursor:
			open.append(Vector2(cursor, minf(span.x, rect.end.x)))
		cursor = maxf(cursor, span.y)
		if cursor >= rect.end.x:
			break
	if cursor < rect.end.x:
		open.append(Vector2(cursor, rect.end.x))
	return open


## Salpicaduras sobre el borde superior de cada sólido (donde pisa el jugador): un emisor por tramo expuesto, en mundo.
static func _add_rain_splashes(level: Node, solids: Array[Rect2]) -> void:
	var holder: Node2D = Node2D.new()
	holder.name = "RainSplashes"
	level.add_child(holder)
	var environment: Node = level.get_node_or_null("Environment")
	if environment != null:
		level.move_child(holder, environment.get_index() + 1)
	var density: float = SettingsScript.particle_scale()
	var grow: Curve = Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(0.75, 0.85, 1.0, 0.6))
	fade.set_color(1, Color(0.75, 0.85, 1.0, 0.0))
	for rect: Rect2 in solids:
		if rect.size.x < SPLASH_MIN_WIDTH:
			continue
		for span: Vector2 in _rain_exposed(rect, solids):
			var width: float = span.y - span.x
			if width < SPLASH_MIN_WIDTH:
				continue
			var fx: CPUParticles2D = CPUParticles2D.new()
			fx.texture = _get_splash_texture()
			fx.amount = maxi(2, roundi(clampf(width / 45.0, 2.0, 24.0) * density))
			fx.lifetime = 0.25
			fx.randomness = 1.0
			fx.local_coords = false
			fx.position = Vector2((span.x + span.y) * 0.5, rect.position.y)
			fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			fx.emission_rect_extents = Vector2(width * 0.5, 1.0)
			fx.gravity = Vector2.ZERO
			fx.initial_velocity_min = 0.0
			fx.initial_velocity_max = 0.0
			fx.scale_amount_curve = grow
			fx.color_ramp = fade
			holder.add_child(fx)


static func _schedule_lightning(layer: CanvasLayer, flash: ColorRect) -> void:
	if not layer.is_inside_tree():
		return
	var wait: float = randf_range(14.0, 34.0)
	_after(layer, wait, func() -> void:
		if not is_instance_valid(flash) or not flash.is_inside_tree():
			return
		var tw: Tween = flash.create_tween()
		tw.tween_property(flash, "color:a", 0.38, 0.05)
		tw.tween_property(flash, "color:a", 0.0, 0.12)
		tw.tween_property(flash, "color:a", 0.25, 0.04)
		tw.tween_property(flash, "color:a", 0.0, 0.4)
		_schedule_lightning(layer, flash))


## Autos que cruzan por el fondo (detrás del escenario, delante del cielo pintado), sin colisión.
static func _add_cars(level: Node, rng: RandomNumberGenerator) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Traffic"
	layer.layer = -90
	level.add_child(layer)
	_schedule_car(layer, 0)


static func _schedule_car(layer: CanvasLayer, index: int) -> void:
	if not layer.is_inside_tree():
		return
	var wait: float = randf_range(5.0, 14.0)
	_after(layer, wait, func() -> void:
		if not is_instance_valid(layer) or not layer.is_inside_tree():
			return
		var file: String = CAR_FILES[randi() % CAR_FILES.size()]
		var tex: Texture2D = ArtScript.tex(DIR + file + ".png")
		if tex != null:
			var car: Sprite2D = Sprite2D.new()
			car.texture = tex
			car.centered = true
			var s: float = 0.42
			var to_right: bool = (index % 2) == 0
			# Los autos miran a la izquierda: los que van a la derecha se voltean.
			car.scale = Vector2(s * (-1.0 if to_right else 1.0), s)
			car.modulate = Color(0.7, 0.72, 0.85, 0.95)
			var y: float = 520.0
			var from_x: float = -300.0 if to_right else 1900.0
			var to_x: float = 1900.0 if to_right else -300.0
			car.position = Vector2(from_x, y)
			layer.add_child(car)
			var tw: Tween = car.create_tween()
			tw.tween_property(car, "position:x", to_x, randf_range(4.0, 6.5))
			tw.tween_callback(car.queue_free)
		_schedule_car(layer, index + 1))


## Discoteca: velo de color que cambia al ritmo de un temporizador sobre toda la escena.
static func _add_club_lights(level: Node, rng: RandomNumberGenerator) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ClubLights"
	layer.layer = 1
	level.add_child(layer)
	var veil: ColorRect = ColorRect.new()
	veil.anchors_preset = Control.PRESET_FULL_RECT
	veil.anchor_right = 1.0
	veil.anchor_bottom = 1.0
	veil.color = CLUB_COLORS[0]
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	veil.material = mat
	layer.add_child(veil)
	if veil.is_inside_tree():
		var beat: Tween = veil.create_tween().set_loops()
		for color: Color in CLUB_COLORS:
			beat.tween_property(veil, "color", color, 0.46).set_trans(Tween.TRANS_SINE)
			beat.tween_property(veil, "color:a", color.a * 0.4, 0.46).set_trans(Tween.TRANS_SINE)


# ==============================================================================
# Brillo y texturas
# ==============================================================================

static func _add_glow(parent: Node2D, center: Vector2, size: float, tint: Color, rng: RandomNumberGenerator) -> void:
	var glow: Sprite2D = Sprite2D.new()
	glow.texture = _get_glow_texture()
	glow.position = center
	glow.scale = Vector2(size, size)
	glow.modulate = tint
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	parent.add_child(glow)
	if not glow.is_inside_tree():
		return
	var a: float = tint.a
	var flicker: Tween = glow.create_tween().set_loops()
	flicker.tween_property(glow, "modulate:a", a * 0.75, rng.randf_range(0.5, 1.4)).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(glow, "modulate:a", a, rng.randf_range(0.5, 1.4)).set_trans(Tween.TRANS_SINE)


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


## Gota: línea de 2 x 22 px que se desvanece en los extremos.
static func _get_rain_texture() -> Texture2D:
	if _rain_tex == null:
		var img: Image = Image.create(2, 22, false, Image.FORMAT_RGBA8)
		for y in range(22):
			var a: float = 1.0 - absf(float(y) - 11.0) / 11.0
			for x in range(2):
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_rain_tex = ImageTexture.create_from_image(img)
	return _rain_tex


## Salpicadura: elipse achatada de 10 x 4 px, más tenue hacia los bordes.
static func _get_splash_texture() -> Texture2D:
	if _splash_tex == null:
		var img: Image = Image.create(10, 4, false, Image.FORMAT_RGBA8)
		for y in range(4):
			for x in range(10):
				var d: float = Vector2((float(x) - 4.5) / 4.5, (float(y) - 1.5) / 1.5).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
		_splash_tex = ImageTexture.create_from_image(img)
	return _splash_tex


# ==============================================================================
# Consultas de espacio
# ==============================================================================

static func _covered_top(rect: Rect2, solids: Array[Rect2], x: float) -> bool:
	for other: Rect2 in solids:
		if other == rect:
			continue
		if x < other.position.x or x > other.end.x:
			continue
		if other.position.y < rect.position.y + 2.0 and other.end.y > rect.position.y - 6.0:
			return true
	return false


static func _free_above(rect: Rect2, solids: Array[Rect2], x: float, height: float) -> bool:
	var probe: Rect2 = Rect2(Vector2(x - 20.0, rect.position.y - height), Vector2(40.0, height - 2.0))
	for other: Rect2 in solids:
		if other == rect:
			continue
		if probe.intersects(other):
			return false
	return true
