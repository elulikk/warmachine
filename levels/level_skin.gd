extends RefCounted
## Revestimiento de arte del mundo (suelos, paredes, plataformas y fondo pintado).
## Sin class_name: se carga por `preload` (LevelBase, BaseCamp, TestLevel).
##
## Los niveles se arman con `StaticBody2D` + `ColorRect` (más un `TopBorder`) bajo el nodo `Environment`.
## Para no tocar los 50 `.tscn`, al iniciar el nivel cada cuerpo se cubre con texturas según su tamaño y
## el `ColorRect` original queda oculto (la colisión no cambia).

const ArtScript = preload("res://core/art/art.gd")
const BackdropScript = preload("res://levels/backdrop.gd")
const SettingsScript = preload("res://core/settings.gd")
const MeadowDecorScript = preload("res://levels/meadow_decor.gd")
const HellDecorScript = preload("res://levels/hell_decor.gd")
const CityDecorScript = preload("res://levels/city_decor.gd")

const WORLD_DIR: String = "res://assets/art/world4/"
const BG_DIR: String = "res://assets/art/bg/"
## Zoom de los fondos por capas (el de la imagen fija es 1.3 en backdrop.gd). Menos zoom = menos borroso.
const LAYER_ZOOM: float = 1.1

## Fondo pintado por capítulo (0 = campamento base).
const CHAPTER_BACKDROPS: Dictionary = {
	0: "workshop.jpg", 1: "city_street.jpg", 2: "meadow.jpg", 3: "hell_plain.jpg", 4: "workshop.jpg", 5: "city.jpg"
}

## Cuánto se oscurece el fondo para que el escenario jugable destaque.
const BACKDROP_TONE: Color = Color(0.5, 0.46, 0.48, 1.0)

const EDGE_HEIGHT: float = 14.0
const WALL_MAX_WIDTH: float = 130.0
const WALL_MIN_HEIGHT: float = 200.0
const THIN_MAX_HEIGHT: float = 40.0

## Relleno bajo los suelos: solo dibujo (la colisión sigue igual), para que no parezcan flotar.
const GROUND_FILL_DEPTH: float = 1200.0
const GROUND_FILL_TONE: Color = Color(0.42, 0.4, 0.46, 1.0)
## Si hay algo sólido a menos de esta distancia por debajo de un bloque, el bloque es un techo o un piso
## superior (no apoya sobre el vacío) y no se rellena: el relleno taparía el pasillo de abajo.
const FILL_SKIP_GAP: float = 900.0

## Temas de arte por capítulo (los capítulos sin entrada usan el revestimiento industrial del capítulo 4).
## Misma clasificación de cuerpos para todos: muro / plataforma delgada / techo / suelo con borde superior.
##   dir             carpeta del arte (Google Flow, ver `art_source/worldN/process.py`)
##   ground          textura del suelo (repetible) y `ground_tone`; `fill_tone` oscurece el relleno bajo el suelo
##   stone           muros y techos (`wall_tone`, `ceiling_tone`)
##   ground_strip    (opcional) piso pintado de una pieza que reemplaza a `ground` + `edge`; `ground_fill` rellena debajo
##   edge            tira del borde superior del suelo, `edge_height` px de alto, sube `edge_lift` de su alto
##   platform        tablón de las plataformas delgadas (NinePatch con `platform_margins` [izq, der, arriba, abajo])
##   backdrop_tone   oscurecimiento del fondo; `backdrop_tones` lo pisa por archivo (fondos muy cargados)
##   decor           script con `decorate(level, solids)` (decoración y partículas; solo dibujo)
const CHAPTER_THEMES: Dictionary = {
	# Mundo 2 (Valle Esmeralda, medieval): tierra con borde de césped, muros de piedra, tablones de madera y cielo abierto
	2: {
		"dir": "res://assets/art/world2/",
		"ground": "dirt.png", "ground_tone": Color(1.0, 1.0, 1.0, 1.0), "fill_tone": Color(0.62, 0.55, 0.5, 1.0),
		"stone": "stone.png", "wall_tone": Color(0.92, 0.92, 0.92, 1.0), "ceiling_tone": Color(0.85, 0.85, 0.85, 1.0),
		"edge": "grass_edge.png", "edge_height": 30.0, "edge_lift": 0.55,
		"platform": "platform_wood.png", "platform_margins": [16, 16, 6, 6],
		"backdrop_tone": Color(0.9, 0.9, 0.9, 1.0),
		# El bosque es muy cargado: se apaga más para que el escenario jugable se lea
		"backdrop_tones": {"forest_green.jpg": Color(0.68, 0.72, 0.68, 1.0)},
		"decor": MeadowDecorScript,
	},
	# Mundo 3 (Abismo Ígneo, infierno): roca volcánica con grietas de lava, costra con brasas, ladrillo demoníaco,
	# plataformas de hueso y hierro; los fondos son muy rojos y cargados, se apagan bastante
	3: {
		"dir": "res://assets/art/world3/",
		"ground": "volcanic_rock.png", "ground_tone": Color(0.68, 0.6, 0.58, 1.0), "fill_tone": Color(0.32, 0.24, 0.24, 1.0),
		"stone": "demon_brick.png", "wall_tone": Color(0.85, 0.8, 0.8, 1.0), "ceiling_tone": Color(0.75, 0.7, 0.7, 1.0),
		"edge": "ember_crust.png", "edge_height": 26.0, "edge_lift": 0.5,
		"platform": "bone_platform.png", "platform_margins": [20, 20, 6, 6],
		"backdrop_tone": Color(0.52, 0.47, 0.47, 1.0),
		"backdrop_tones": {"lava_cavern.jpg": Color(0.5, 0.45, 0.45, 1.0), "demon_citadel.jpg": Color(0.48, 0.44, 0.44, 1.0)},
		"decor": HellDecorScript,
	},
	# Mundo 1 (El Presente, ciudad de noche): asfalto mojado, ladrillo urbano y plataformas de chapa; cada sector
	# pisa suelo, muros y plataforma con `sectors[level_id]` (alcantarilla, muelle, mármol, discoteca, azotea)
	1: {
		"dir": "res://assets/art/world1/",
		"ground": "asphalt.png", "ground_tone": Color(0.85, 0.85, 0.9, 1.0), "fill_tone": Color(0.4, 0.4, 0.48, 1.0),
		"stone": "city_brick.png", "wall_tone": Color(0.85, 0.85, 0.9, 1.0), "ceiling_tone": Color(0.7, 0.7, 0.78, 1.0),
		"edge": "edge_asphalt.png", "edge_height": 28.0, "edge_lift": 0.25,
		"platform": "plat_metal.png", "platform_margins": [10, 10, 4, 4],
		"backdrop_tone": Color(0.62, 0.62, 0.7, 1.0),
		"backdrop_tones": {"city_club.jpg": Color(0.55, 0.55, 0.62, 1.0), "city_hotel.jpg": Color(0.6, 0.58, 0.6, 1.0)},
		"decor": CityDecorScript,
		"sectors": {
			# `backdrop` es la imagen fija (la base de Flow, de la que salieron las capas). `backdrop_layers` es el paralaje:
			# [archivo en assets/art/bg/parallax/, profundidad], de atrás hacia adelante
			"1_01": {"ground_strip": "city_floor_strip.png", "ground_fill": "city_floor_fill.png", "backdrop": "city_night_base.jpg", "backdrop_lift": 0.12, "backdrop_layers": [["city_parallax_sky.webp", 0.15],
				["city_parallax_far.webp", 0.35], ["city_parallax_mid.webp", 0.65], ["city_parallax_street.webp", 1.0]]},
			"1_02": {"backdrop": "city_alley.jpg"},
			"1_03": {"edge": "edge_sewer.png", "ground": "sewer_stone.png", "stone": "sewer_stone.png", "ground_tone": Color(0.8, 0.9, 0.85, 1.0),
				"fill_tone": Color(0.32, 0.4, 0.38, 1.0), "backdrop": "city_sewer.jpg"},
			"1_04": {"platform": "plat_wood.png", "platform_margins": [6, 6, 4, 4], "backdrop": "city_houses.jpg"},
			"1_05": {"edge": "edge_dock.png", "ground": "dock_planks.png", "ground_tone": Color(0.8, 0.85, 0.95, 1.0), "fill_tone": Color(0.3, 0.34, 0.42, 1.0),
				"backdrop": "city_dock.jpg"},
			"1_06": {"edge": "edge_marble.png", "ground": "marble.png", "stone": "marble.png", "ground_tone": Color(0.85, 0.82, 0.95, 1.0),
				"fill_tone": Color(0.3, 0.28, 0.36, 1.0), "backdrop": "city_hotel.jpg"},
			"1_07": {"edge": "edge_club.png", "ground": "club_floor.png", "stone": "city_brick.png", "ground_tone": Color(0.95, 0.9, 1.0, 1.0),
				"fill_tone": Color(0.25, 0.22, 0.3, 1.0), "backdrop": "city_club.jpg"},
			"1_08": {"edge": "edge_roof.png", "ground": "roof_gravel.png", "fill_tone": Color(0.32, 0.32, 0.4, 1.0), "backdrop": "city_rooftop.jpg"},
		},
	},
}

## Tema del capítulo con los cambios del sector del nivel (`sectors[level_id]`).
static func _resolve_theme(level: Node, chapter: int) -> Dictionary:
	if not CHAPTER_THEMES.has(chapter):
		return {}
	var theme: Dictionary = (CHAPTER_THEMES[chapter] as Dictionary).duplicate()
	var sectors: Dictionary = theme.get("sectors", {}) as Dictionary
	var level_id: String = str(level.get("level_id")) if "level_id" in level else ""
	if sectors.has(level_id):
		for key: Variant in (sectors[level_id] as Dictionary).keys():
			theme[key] = (sectors[level_id] as Dictionary)[key]
	return theme


## Rectángulos (en el mundo) de todos los sólidos del nivel que se está revistiendo.
static var _solid_rects: Array[Rect2] = []
## Capítulo del nivel que se está revistiendo (elige el juego de texturas).
static var _chapter: int = 1
## Tema del nivel en curso: el del capítulo, con los cambios de su sector (`sectors[level_id]`).
static var _theme: Dictionary = {}


## `backdrop_file` pisa el fondo del capítulo (nombre de archivo dentro de `assets/art/bg/`).
static func apply(level: Node, chapter: int = 1, backdrop_file: String = "") -> void:
	_chapter = chapter
	_theme = _resolve_theme(level, chapter)
	if backdrop_file.is_empty() and _theme.has("backdrop"):
		backdrop_file = str(_theme["backdrop"])
	var environment: Node = level.get_node_or_null("Environment")
	if environment != null:
		_solid_rects.clear()
		_collect_solids(environment)
		_skin_bodies(environment)
		var decor: Variant = _theme.get("decor", null)
		if decor != null:
			(decor as GDScript).call("decorate", level, _solid_rects)
	_install_backdrop(level, chapter, backdrop_file)


## Rectángulos sólidos del último nivel revestido (los usa la decoración).
static func solid_rects() -> Array[Rect2]:
	return _solid_rects


# ==============================================================================
# Cuerpos sólidos
# ==============================================================================

static func _collect_solids(node: Node) -> void:
	for child: Node in node.get_children():
		var body: StaticBody2D = child as StaticBody2D
		if body != null:
			var rect: ColorRect = body.get_node_or_null("ColorRect") as ColorRect
			if rect != null:
				var body_pos: Vector2 = body.global_position if body.is_inside_tree() else body.position
				var origin: Vector2 = body_pos + Vector2(rect.offset_left, rect.offset_top)
				_solid_rects.append(Rect2(origin, Vector2(rect.offset_right - rect.offset_left, rect.offset_bottom - rect.offset_top)))
		_collect_solids(child)


## true si hay otro sólido debajo de `world_rect` (solapado en horizontal) a menos de FILL_SKIP_GAP.
static func _has_solid_below(world_rect: Rect2) -> bool:
	for other: Rect2 in _solid_rects:
		if other.position.is_equal_approx(world_rect.position) and other.size.is_equal_approx(world_rect.size):
			continue
		if other.position.x >= world_rect.end.x or other.end.x <= world_rect.position.x:
			continue
		var gap: float = other.position.y - world_rect.end.y
		if gap >= -1.0 and gap <= FILL_SKIP_GAP:
			return true
	return false


static func _skin_bodies(node: Node) -> void:
	for child: Node in node.get_children():
		if child is StaticBody2D:
			_skin_body(child as StaticBody2D)
		_skin_bodies(child)


## true si otro sólido toca la cara superior de `world_rect` cubriendo al menos la mitad de su ancho.
static func _has_solid_on_top(world_rect: Rect2) -> bool:
	var covered: float = 0.0
	for other: Rect2 in _solid_rects:
		if other.position.is_equal_approx(world_rect.position) and other.size.is_equal_approx(world_rect.size):
			continue
		if absf(other.end.y - world_rect.position.y) > 2.0:
			continue
		covered += maxf(0.0, minf(other.end.x, world_rect.end.x) - maxf(other.position.x, world_rect.position.x))
	return covered >= world_rect.size.x * 0.5


static func _skin_body(body: StaticBody2D) -> void:
	var rect: ColorRect = body.get_node_or_null("ColorRect") as ColorRect
	if rect == null or body.has_node("SkinVisual"):
		return
	var floor_tex: Texture2D = ArtScript.tex(WORLD_DIR + "floor_blue.png")
	if floor_tex == null:
		return # sin arte: se deja el rectángulo de color

	var origin: Vector2 = Vector2(rect.offset_left, rect.offset_top)
	var extent: Vector2 = Vector2(rect.offset_right - rect.offset_left, rect.offset_bottom - rect.offset_top)
	if extent.x < 4.0 or extent.y < 4.0:
		return

	if not _theme.is_empty():
		_skin_body_themed(body, rect, origin, extent, _theme)
		return

	var visual: Node2D = Node2D.new()
	visual.name = "SkinVisual"
	visual.position = origin
	body.add_child(visual)
	body.move_child(visual, 0)

	var is_wall: bool = extent.x <= WALL_MAX_WIDTH and extent.y >= WALL_MIN_HEIGHT
	var is_thin: bool = extent.y <= THIN_MAX_HEIGHT and not is_wall

	if is_thin:
		_build_thin_platform(visual, extent)
	elif is_wall:
		_build_wall(visual, extent)
	else:
		var body_pos: Vector2 = body.global_position if body.is_inside_tree() else body.position
		_build_ground(visual, extent, floor_tex, not _has_solid_below(Rect2(body_pos + origin, extent)))

	# El rectángulo original (y su borde) ya no se dibujan
	rect.visible = false
	var border: CanvasItem = body.get_node_or_null("TopBorder") as CanvasItem
	if border != null:
		border.visible = false


## Capítulo con tema propio (CHAPTER_THEMES): misma clasificación de cuerpos (muro / plataforma delgada / suelo).
static func _skin_body_themed(body: StaticBody2D, rect: ColorRect, origin: Vector2, extent: Vector2, theme: Dictionary) -> void:
	var dir: String = str(theme["dir"])
	var ground: Texture2D = ArtScript.tex(dir + str(theme["ground"]))
	if ground == null:
		return
	var visual: Node2D = Node2D.new()
	visual.name = "SkinVisual"
	visual.position = origin
	body.add_child(visual)
	body.move_child(visual, 0)

	var is_wall: bool = extent.x <= WALL_MAX_WIDTH and extent.y >= WALL_MIN_HEIGHT
	var is_thin: bool = extent.y <= THIN_MAX_HEIGHT and not is_wall
	var body_pos: Vector2 = body.global_position if body.is_inside_tree() else body.position
	var world_rect: Rect2 = Rect2(body_pos + origin, extent)
	var stone: Texture2D = ArtScript.tex(dir + str(theme["stone"]))
	if stone == null:
		stone = ground

	if is_thin:
		var plank: Texture2D = ArtScript.tex(dir + str(theme["platform"]))
		if plank != null:
			var margins: Array = theme["platform_margins"] as Array
			var patch: NinePatchRect = NinePatchRect.new()
			patch.texture = plank
			patch.patch_margin_left = int(margins[0])
			patch.patch_margin_right = int(margins[1])
			patch.patch_margin_top = int(margins[2])
			patch.patch_margin_bottom = int(margins[3])
			patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
			patch.size = Vector2(extent.x, maxf(extent.y, 22.0))
			patch.position = Vector2(0.0, -2.0)
			patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			visual.add_child(patch)
	elif is_wall:
		_tile_rect(visual, stone, extent, theme["wall_tone"] as Color)
	else:
		# Un techo (algo sólido justo debajo) es piedra; un suelo lleva su borde superior
		var is_ceiling: bool = _has_solid_below(world_rect) and extent.y >= 90.0
		if is_ceiling:
			_tile_rect(visual, stone, extent, theme["ceiling_tone"] as Color)
		elif theme.has("ground_strip") and _build_ground_strip(visual, dir, extent, theme, world_rect):
			pass # piso pintado de una pieza (sin borde aparte)
		else:
			_tile_rect(visual, ground, extent, theme["ground_tone"] as Color)
			if not _has_solid_below(world_rect):
				var fill: TextureRect = _tile_rect(visual, ground, Vector2(extent.x, GROUND_FILL_DEPTH), theme["fill_tone"] as Color)
				fill.position = Vector2(0.0, extent.y)
			var edge_tex: Texture2D = ArtScript.tex(dir + str(theme["edge"]))
			# Sin borde si otro sólido apoya encima (lecho de roca bajo el suelo): quedaría una franja enterrada
			if edge_tex != null and not _has_solid_on_top(world_rect):
				var edge_h: float = float(theme["edge_height"])
				var edge: TextureRect = _tile_rect(visual, edge_tex, Vector2(extent.x, edge_h))
				edge.position = Vector2(0.0, -edge_h * float(theme["edge_lift"]))

	rect.visible = false
	var border: CanvasItem = body.get_node_or_null("TopBorder") as CanvasItem
	if border != null:
		border.visible = false
	var bottom: CanvasItem = body.get_node_or_null("BottomBorder") as CanvasItem
	if bottom != null:
		bottom.visible = false


## Suelo pintado de una pieza (acera + bordillo + calle): la franja `ground_strip` repite en horizontal desde la cara
## superior y, si el bloque apoya sobre el vacío, `ground_fill` rellena hacia abajo. Sin borde ondulado aparte.
## Devuelve false (sin dibujar) si falta el arte.
static func _build_ground_strip(visual: Node2D, dir: String, extent: Vector2, theme: Dictionary, world_rect: Rect2) -> bool:
	var strip: Texture2D = ArtScript.tex(dir + str(theme["ground_strip"]))
	if strip == null:
		return false
	var fill_tex: Texture2D = ArtScript.tex(dir + str(theme.get("ground_fill", theme["ground"])))
	# Lecho bajo otro suelo: solo asfalto liso, sin acera propia
	if _has_solid_on_top(world_rect):
		if fill_tex != null:
			_tile_rect(visual, fill_tex, extent)
		return true
	var strip_h: float = float(strip.get_height())
	var open_below: bool = not _has_solid_below(world_rect)
	# Con un lecho pegado debajo la franja se muestra entera (el lecho no dibuja acera)
	var shown_h: float = strip_h if (open_below or _has_solid_touching_below(world_rect)) else minf(strip_h, extent.y)
	var region: AtlasTexture = AtlasTexture.new()
	region.atlas = strip
	region.region = Rect2(0.0, 0.0, float(strip.get_width()), shown_h)
	_tile_rect(visual, region, Vector2(extent.x, shown_h))
	if open_below and fill_tex != null:
		var fill: TextureRect = _tile_rect(visual, fill_tex, Vector2(extent.x, GROUND_FILL_DEPTH))
		fill.position = Vector2(0.0, maxf(strip_h, extent.y))
		if extent.y > strip_h:
			_tile_rect(visual, fill_tex, Vector2(extent.x, extent.y - strip_h)).position = Vector2(0.0, strip_h)
	return true


## true si otro sólido apoya justo debajo de `world_rect` (sin hueco) cubriendo al menos la mitad de su ancho.
static func _has_solid_touching_below(world_rect: Rect2) -> bool:
	var covered: float = 0.0
	for other: Rect2 in _solid_rects:
		if other.position.is_equal_approx(world_rect.position) and other.size.is_equal_approx(world_rect.size):
			continue
		if absf(other.position.y - world_rect.end.y) > 2.0:
			continue
		covered += maxf(0.0, minf(other.end.x, world_rect.end.x) - maxf(other.position.x, world_rect.position.x))
	return covered >= world_rect.size.x * 0.5


static func _tile_rect(parent: Node, texture: Texture2D, rect_size: Vector2, tone: Color = Color.WHITE) -> TextureRect:
	var tiled: TextureRect = TextureRect.new()
	tiled.texture = texture
	tiled.stretch_mode = TextureRect.STRETCH_TILE
	tiled.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tiled.size = rect_size
	tiled.modulate = tone
	tiled.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tiled)
	return tiled


## Suelo o bloque macizo: chapa remachada con la tabla de cobre arriba.
static func _build_ground(visual: Node2D, extent: Vector2, floor_tex: Texture2D, with_fill: bool = true) -> void:
	_tile_rect(visual, floor_tex, extent, Color(0.92, 0.9, 0.95, 1.0))
	# Macizo bajo la superficie: mampostería oscura que llega hasta el fondo de la vista
	# (solo si el bloque apoya sobre el vacío; un techo o piso superior no se rellena)
	if with_fill:
		var fill_tex: Texture2D = ArtScript.tex(WORLD_DIR + "wall_brick.png")
		if fill_tex == null:
			fill_tex = floor_tex
		var fill: TextureRect = _tile_rect(visual, fill_tex, Vector2(extent.x, GROUND_FILL_DEPTH), GROUND_FILL_TONE)
		fill.position = Vector2(0.0, extent.y)
	var edge_tex: Texture2D = ArtScript.tex(WORLD_DIR + "edge_top.png")
	if edge_tex != null:
		var edge: TextureRect = _tile_rect(visual, edge_tex, Vector2(extent.x, EDGE_HEIGHT))
		edge.position = Vector2(0.0, -3.0)
	# Sombra suave bajo el borde para dar volumen
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.28)
	shade.size = Vector2(extent.x, 10.0)
	shade.position = Vector2(0.0, EDGE_HEIGHT - 3.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(shade)


## Muro o columna: mampostería oscura.
static func _build_wall(visual: Node2D, extent: Vector2) -> void:
	var brick: Texture2D = ArtScript.tex(WORLD_DIR + "wall_brick.png")
	if brick == null:
		brick = ArtScript.tex(WORLD_DIR + "floor_blue.png")
	_tile_rect(visual, brick, extent, Color(0.85, 0.82, 0.84, 1.0))


## Plataforma delgada: tabla de cobre con refuerzos.
static func _build_thin_platform(visual: Node2D, extent: Vector2) -> void:
	var strip: Texture2D = ArtScript.tex(WORLD_DIR + "platform_strip.png")
	if strip == null:
		return
	var patch: NinePatchRect = NinePatchRect.new()
	patch.texture = strip
	patch.patch_margin_left = 14
	patch.patch_margin_right = 14
	patch.patch_margin_top = 4
	patch.patch_margin_bottom = 4
	patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	patch.size = extent
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(patch)


# ==============================================================================
# Fondo
# ==============================================================================

static func _install_backdrop(level: Node, chapter: int, backdrop_file: String = "") -> void:
	var layer: CanvasLayer = level.get_node_or_null("Background") as CanvasLayer
	if layer == null:
		return
	# El ColorRect de fondo de las escenas nace con filtro STOP y cubre toda la pantalla: se tragaba el clic derecho
	# antes de que llegara a `_unhandled_input` (mano secundaria). Un fondo nunca debe capturar el ratón.
	for child: Node in layer.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var file: String = backdrop_file if not backdrop_file.is_empty() else str(CHAPTER_BACKDROPS.get(clampi(chapter, 0, 5), "workshop.jpg"))
	var texture: Texture2D = ArtScript.tex(BG_DIR + file)
	if texture == null:
		return
	for child: Node in layer.get_children():
		if child is ColorRect:
			(child as ColorRect).color = Color(0.05, 0.04, 0.05, 1.0)
	if layer.has_node("Backdrop"):
		return
	var backdrop: Control = BackdropScript.new() as Control
	backdrop.name = "Backdrop"
	backdrop.set("texture", texture)
	var tone: Color = BACKDROP_TONE
	if not _theme.is_empty():
		tone = (_theme["backdrop_tones"] as Dictionary).get(file, _theme["backdrop_tone"]) as Color
	backdrop.set("tone", tone)
	# Paralaje por capas: solo si el nivel las define, usa el fondo de su tema (no uno propio) y la opción está activada
	if _theme.has("backdrop_layers") and backdrop_file == str(_theme.get("backdrop", "")) and SettingsScript.get_bool("parallax_bg"):
		backdrop.set("layers", _parallax_layers(_theme["backdrop_layers"] as Array))
		backdrop.set("zoom", LAYER_ZOOM)
		backdrop.set("lift", float(_theme.get("backdrop_lift", 0.0)))
	layer.add_child(backdrop)


## Capas de paralaje del tema: [archivo dentro de `assets/art/bg/parallax/`, profundidad]. Omite las que no carguen.
static func _parallax_layers(spec: Array) -> Array:
	var layers: Array = []
	for entry: Array in spec:
		var layer_texture: Texture2D = ArtScript.tex(BG_DIR + "parallax/" + str(entry[0]))
		if layer_texture != null:
			layers.append({"texture": layer_texture, "depth": float(entry[1])})
	return layers
