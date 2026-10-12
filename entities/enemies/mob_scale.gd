extends RefCounted
## Escala de los enemigos (Fase Q, punto 13). Sin class_name: se usa por preload.
## Las escenas guardan el tamaño 1x; `apply()` agranda una vez, al final del `_ready` de cada enemigo,
## el arte (`EnemyArt`), la colisión del cuerpo, la hurtbox y la altura de la barra de estado.
## El origen de cada enemigo está en los pies, así que todo crece hacia arriba sin hundirse en el piso.

const MOB_SCALE: float = 1.5
## Alto máximo de la colisión contra el mundo: las plataformas bajas de las arenas del 1-3 y el 1-4 dejan 76 px
## de luz. El bruto (105 px al 1.5x), el zombi y el fantasma quedan con el cuerpo a 72 px (el alto del ladrón) para poder pasar por
## debajo; el arte y la hurtbox sí crecen completos (la cabeza puede atravesar la plataforma al pasar).
const MAX_BODY_HEIGHT: float = 72.0


static func apply(host: Node2D, art: Node2D) -> void:
	if host.has_meta(&"mob_scaled") or is_equal_approx(MOB_SCALE, 1.0):
		return
	host.set_meta(&"mob_scaled", true)
	if art != null:
		art.scale = Vector2(MOB_SCALE, MOB_SCALE)
	var body_shape: CollisionShape2D = host.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_scale_shape(body_shape)
	if body_shape != null and body_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = body_shape.shape as RectangleShape2D
		if rect.size.y > MAX_BODY_HEIGHT:
			# Los pies quedan donde estaban: se recorta desde arriba
			var bottom: float = body_shape.position.y + rect.size.y * 0.5
			rect.size.y = MAX_BODY_HEIGHT
			body_shape.position.y = bottom - MAX_BODY_HEIGHT * 0.5
	var hurtbox: Node = host.get_node_or_null("Hurtbox")
	if hurtbox != null:
		for child: Node in hurtbox.get_children():
			_scale_shape(child as CollisionShape2D)
	for node_name: String in ["StatusDisplayComponent", "OverheadHealthBar"]:
		var node: Node2D = host.get_node_or_null(node_name) as Node2D
		if node == null:
			continue
		if "vertical_offset_y" in node:
			node.set("vertical_offset_y", float(node.get("vertical_offset_y")) * MOB_SCALE)
		node.position.y *= MOB_SCALE


## Las formas de las escenas son compartidas entre instancias: se duplican antes de agrandarlas.
static func _scale_shape(shape_node: CollisionShape2D) -> void:
	if shape_node == null or shape_node.shape == null:
		return
	var shape: Shape2D = shape_node.shape.duplicate() as Shape2D
	if shape is RectangleShape2D:
		(shape as RectangleShape2D).size *= MOB_SCALE
	elif shape is CircleShape2D:
		(shape as CircleShape2D).radius *= MOB_SCALE
	elif shape is CapsuleShape2D:
		(shape as CapsuleShape2D).radius *= MOB_SCALE
		(shape as CapsuleShape2D).height *= MOB_SCALE
	shape_node.shape = shape
	shape_node.position *= MOB_SCALE
