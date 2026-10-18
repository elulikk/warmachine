@tool
extends StaticBody2D
## Objeto sólido del escenario para armar niveles arrastrando (cajas, cercos, casas, casetas).
## Arrastrar la escena (`entities/world/props/*.tscn`) bajo el nodo `Environment` del nivel y listo:
## ya tiene colisión, se puede pisar y trepar, y no hace falta tocar nada más.
##
## El ORIGEN del nodo es el centro de su BASE: poné la `position.y` en la altura del piso (en el nivel 1-01
## el piso está en y = 556) y el objeto queda apoyado.
##
## Arte: si existe el archivo de `art_path` se usa solo (alcanza con guardar el PNG con ese nombre);
## `texture` lo pisa desde el Inspector. Sin arte se dibuja un bloque de color para probar la jugabilidad.
##   stretch_art = true   el dibujo se estira al `size` (cajas y cercos: se pueden redimensionar)
##   stretch_art = false  el dibujo mantiene su proporción a `art_scale` (casas con techo que sobresale)

const ArtScript = preload("res://core/art/art.gd")

## Cuerpo visible y sólido (ancho, alto), apoyado en el origen.
@export var size: Vector2 = Vector2(80.0, 80.0):
	set(value):
		size = Vector2(maxf(value.x, 4.0), maxf(value.y, 4.0))
		_refresh()

## Cuánto se achica la colisión respecto del dibujo (fracción del ancho total y del alto): el arte tiene bordes
## transparentes y, con la colisión completa, se pisa el aire al lado del objeto.
@export var hitbox_shrink: Vector2 = Vector2(0.14, 0.07):
	set(value):
		hitbox_shrink = value
		_refresh()

## Colisión invisible sobre el cuerpo: un cerco alto que no se puede saltar aunque el dibujo sea bajo.
@export var extra_collision_top: float = 0.0:
	set(value):
		extra_collision_top = maxf(value, 0.0)
		_refresh()

## Sólidos adicionales (chimenea, alero...). Cada Rect2 es (x, y, ancho, alto) respecto del centro de la base:
## `y` negativo es hacia arriba. Ej.: Rect2(-40, -290, 50, 60) es una chimenea sobre un cuerpo de 230 de alto.
@export var extra_hitboxes: Array[Rect2] = []:
	set(value):
		extra_hitboxes = value
		_refresh()

@export_group("Arte")
@export var texture: Texture2D:
	set(value):
		texture = value
		_refresh()
@export_file("*.png", "*.jpg", "*.webp") var art_path: String = "":
	set(value):
		art_path = value
		_refresh()
@export var stretch_art: bool = true:
	set(value):
		stretch_art = value
		_refresh()
## Espejar el dibujo en horizontal (con stretch_art): así sale la variedad de los objetos de la ciudad.
@export var flip_art: bool = false:
	set(value):
		flip_art = value
		_refresh()
## Los PNG vienen al doble del tamaño de juego (como el resto de los props).
@export var art_scale: float = 0.5:
	set(value):
		art_scale = maxf(value, 0.01)
		_refresh()
## Color del bloque de prueba mientras no haya arte.
@export var placeholder_color: Color = Color(0.45, 0.32, 0.2, 1.0):
	set(value):
		placeholder_color = value
		queue_redraw()

const HITBOX_META: StringName = &"_prop_hitbox"
## Cada tanto el objeto saca de adentro suyo a los cuerpos (enemigos, jugador) que hayan quedado superpuestos
## (aparición dentro del objeto, empujones). Capa 2 = enemigos y jugador; capa 1 = mundo.
const EJECT_PERIOD: float = 1.5
const EJECT_BODY_MASK: int = 2
const EJECT_SHRINK: float = 9.0
const EJECT_MARGIN: float = 4.0


func _ready() -> void:
	# Los enemigos terrestres saltan los obstáculos bajos (un cerco alto no se puede saltar)
	if not Engine.is_editor_hint() and extra_collision_top <= 0.0:
		add_to_group(&"hop_obstacle")
	_refresh()
	if not Engine.is_editor_hint():
		var timer: Timer = Timer.new()
		timer.wait_time = EJECT_PERIOD
		timer.one_shot = false
		timer.autostart = false
		timer.timeout.connect(_eject_overlaps)
		add_child(timer)
		# Primera pasada tras unos cuadros de física (los enemigos recién nacidos aún no están en el espacio)
		get_tree().create_timer(0.3 + randf() * 0.3).timeout.connect(func() -> void:
			_eject_overlaps()
			timer.start())


func _refresh() -> void:
	if not is_inside_tree():
		return
	_rebuild_hitboxes()
	_rebuild_art()
	queue_redraw()


func _rebuild_hitboxes() -> void:
	for child: Node in get_children():
		if child.has_meta(HITBOX_META):
			remove_child(child)
			child.queue_free()
	var body_w: float = size.x * (1.0 - hitbox_shrink.x)
	var body_h: float = size.y * (1.0 - hitbox_shrink.y)
	var rects: Array[Rect2] = [Rect2(-body_w * 0.5, -body_h - extra_collision_top, body_w, body_h + extra_collision_top)]
	rects.append_array(extra_hitboxes)
	for rect: Rect2 in rects:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rect.size
		var node: CollisionShape2D = CollisionShape2D.new()
		node.name = "Hitbox"
		node.shape = shape
		node.position = rect.position + rect.size * 0.5
		node.set_meta(HITBOX_META, true)
		add_child(node)


## Saca de adentro del objeto a los cuerpos superpuestos: los pone al costado más cercano que esté libre, o encima.
func _eject_overlaps() -> void:
	if not is_inside_tree() or get_world_2d() == null:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var inner: RectangleShape2D = RectangleShape2D.new()
	# Sobre la colisión real (ya achicada por `hitbox_shrink`), no sobre el dibujo: pegarse al costado o caminar encima no cuenta
	var body_w: float = size.x * (1.0 - hitbox_shrink.x)
	var body_h: float = size.y * (1.0 - hitbox_shrink.y)
	inner.size = Vector2(maxf(body_w - EJECT_SHRINK * 2.0, 2.0), maxf(body_h - EJECT_SHRINK * 2.0, 2.0))
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = inner
	query.transform = Transform2D(0.0, global_position + Vector2(0.0, -body_h * 0.5))
	query.collision_mask = EJECT_BODY_MASK
	for hit: Dictionary in space.intersect_shape(query, 8):
		var body: CharacterBody2D = hit.get("collider") as CharacterBody2D
		if body != null:
			_push_out(body, space)


func _push_out(body: CharacterBody2D, space: PhysicsDirectSpaceState2D) -> void:
	var shape_node: CollisionShape2D = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	var half: float = shape_node.shape.get_rect().size.x * 0.5 * absf(shape_node.global_scale.x)
	var side: float = signf(body.global_position.x - global_position.x)
	if side == 0.0:
		side = 1.0
	var reach: float = size.x * (1.0 - hitbox_shrink.x) * 0.5 + half + EJECT_MARGIN
	var candidates: Array[Vector2] = [
		Vector2(global_position.x + side * reach, body.global_position.y),
		Vector2(global_position.x - side * reach, body.global_position.y),
		Vector2(global_position.x, global_position.y - size.y * (1.0 - hitbox_shrink.y) - EJECT_MARGIN),
	]
	for spot: Vector2 in candidates:
		if _spot_is_free(space, shape_node, body, spot):
			body.global_position = spot
			body.velocity = Vector2.ZERO
			return


## true si el cuerpo, puesto en `spot`, no toca el mundo (se levanta 3 px para ignorar el contacto con el piso).
func _spot_is_free(space: PhysicsDirectSpaceState2D, shape_node: CollisionShape2D, body: CharacterBody2D, spot: Vector2) -> bool:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	var offset: Vector2 = shape_node.global_position - body.global_position
	query.transform = Transform2D(0.0, spot + offset + Vector2(0.0, -3.0))
	query.collision_mask = 1
	return space.intersect_shape(query, 1).is_empty()


func _resolve_texture() -> Texture2D:
	if texture != null:
		return texture
	if not art_path.is_empty():
		return ArtScript.tex(art_path)
	return null


func _rebuild_art() -> void:
	var old: Node = get_node_or_null("Art")
	if old != null:
		remove_child(old)
		old.queue_free()
	var tex: Texture2D = _resolve_texture()
	if tex == null:
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex_size: Vector2 = tex.get_size()
	if stretch_art:
		sprite.scale = Vector2((-1.0 if flip_art else 1.0) * size.x / tex_size.x, size.y / tex_size.y)
		sprite.position = Vector2(0.0, -size.y * 0.5)
	else:
		sprite.scale = Vector2(art_scale, art_scale)
		sprite.position = Vector2(0.0, -tex_size.y * art_scale * 0.5)
	add_child(sprite)


func _draw() -> void:
	var has_art: bool = _resolve_texture() != null
	if not has_art:
		_draw_block(Rect2(-size.x * 0.5, -size.y, size.x, size.y))
		for rect: Rect2 in extra_hitboxes:
			_draw_block(rect)
	# En el editor se marcan las colisiones que no se ven: el cerco alto y los sólidos extra
	if Engine.is_editor_hint():
		var guide: Color = Color(1.0, 0.2, 0.2, 0.18)
		if extra_collision_top > 0.0:
			draw_rect(Rect2(-size.x * 0.5, -size.y - extra_collision_top, size.x, extra_collision_top), guide)
		if has_art:
			for rect: Rect2 in extra_hitboxes:
				draw_rect(rect, guide)
			draw_rect(Rect2(-size.x * 0.5, -size.y, size.x, size.y), Color(0.2, 1.0, 0.4, 0.15))


func _draw_block(rect: Rect2) -> void:
	draw_rect(rect, placeholder_color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), placeholder_color.lightened(0.35))
	draw_rect(rect, placeholder_color.darkened(0.4), false, 2.0)
