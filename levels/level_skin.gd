extends RefCounted
## Revestimiento de arte del mundo (suelos, paredes, plataformas y fondo pintado).
## Sin class_name: se carga por `preload` (LevelBase, BaseCamp, TestLevel).
##
## Los niveles se arman con `StaticBody2D` + `ColorRect` (más un `TopBorder`) bajo el nodo `Environment`.
## Para no tocar los 50 `.tscn`, al iniciar el nivel cada cuerpo se cubre con texturas según su tamaño y
## el `ColorRect` original queda oculto (la colisión no cambia).

const ArtScript = preload("res://core/art/art.gd")
const BackdropScript = preload("res://levels/backdrop.gd")

const WORLD_DIR: String = "res://assets/art/world/"
const BG_DIR: String = "res://assets/art/bg/"

## Fondo pintado por capítulo (0 = campamento base).
const CHAPTER_BACKDROPS: Dictionary = {
	0: "workshop.jpg", 1: "workshop.jpg", 2: "city.jpg", 3: "forest.jpg", 4: "castle.jpg", 5: "city.jpg"
}

## Cuánto se oscurece el fondo para que el escenario jugable destaque.
const BACKDROP_TONE: Color = Color(0.5, 0.46, 0.48, 1.0)

const EDGE_HEIGHT: float = 14.0
const WALL_MAX_WIDTH: float = 130.0
const WALL_MIN_HEIGHT: float = 200.0
const THIN_MAX_HEIGHT: float = 40.0


static func apply(level: Node, chapter: int = 1) -> void:
	var environment: Node = level.get_node_or_null("Environment")
	if environment != null:
		_skin_bodies(environment)
	_install_backdrop(level, chapter)


# ==============================================================================
# Cuerpos sólidos
# ==============================================================================

static func _skin_bodies(node: Node) -> void:
	for child: Node in node.get_children():
		if child is StaticBody2D:
			_skin_body(child as StaticBody2D)
		_skin_bodies(child)


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
		_build_ground(visual, extent, floor_tex)

	# El rectángulo original (y su borde) ya no se dibujan
	rect.visible = false
	var border: CanvasItem = body.get_node_or_null("TopBorder") as CanvasItem
	if border != null:
		border.visible = false


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
static func _build_ground(visual: Node2D, extent: Vector2, floor_tex: Texture2D) -> void:
	_tile_rect(visual, floor_tex, extent, Color(0.92, 0.9, 0.95, 1.0))
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

static func _install_backdrop(level: Node, chapter: int) -> void:
	var layer: CanvasLayer = level.get_node_or_null("Background") as CanvasLayer
	if layer == null:
		return
	var file: String = str(CHAPTER_BACKDROPS.get(clampi(chapter, 0, 5), "workshop.jpg"))
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
	backdrop.set("tone", BACKDROP_TONE)
	layer.add_child(backdrop)
