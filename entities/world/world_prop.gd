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


func _ready() -> void:
	# Los enemigos terrestres saltan los obstáculos bajos (un cerco alto no se puede saltar)
	if not Engine.is_editor_hint() and extra_collision_top <= 0.0:
		add_to_group(&"hop_obstacle")
	_refresh()


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
	var rects: Array[Rect2] = [Rect2(-size.x * 0.5, -size.y - extra_collision_top, size.x, size.y + extra_collision_top)]
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
		sprite.scale = Vector2(size.x / tex_size.x, size.y / tex_size.y)
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
