@tool
extends StaticBody2D
## Plataforma o bloque sólido para armar niveles desde el editor (Fase T, punto 1).
## Arrastrar `platform.tscn` bajo el nodo `Environment` del nivel y ajustar `size` en el Inspector:
## la colisión, el `ColorRect` y el `TopBorder` se acomodan solos. En juego, `level_skin.gd` la viste
## igual que los bloques hechos a mano (piso, pared o plataforma fina según las proporciones).

@export var size: Vector2 = Vector2(256, 32):
	set(value):
		size = Vector2(maxf(value.x, 4.0), maxf(value.y, 4.0))
		_refresh()
@export var color: Color = Color(0.12, 0.16, 0.22, 1):
	set(value):
		color = value
		_refresh()
@export var border_color: Color = Color(0.25, 0.55, 0.85, 1):
	set(value):
		border_color = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var rect_shape: RectangleShape2D = shape_node.shape as RectangleShape2D
		# Cada instancia necesita su propia forma: la de la escena es compartida
		if rect_shape == null or not rect_shape.resource_local_to_scene:
			rect_shape = RectangleShape2D.new()
			rect_shape.resource_local_to_scene = true
			shape_node.shape = rect_shape
		rect_shape.size = size
		shape_node.position = Vector2.ZERO
	var half: Vector2 = size * 0.5
	var body_rect: ColorRect = get_node_or_null("ColorRect") as ColorRect
	if body_rect != null:
		body_rect.offset_left = -half.x
		body_rect.offset_top = -half.y
		body_rect.offset_right = half.x
		body_rect.offset_bottom = half.y
		body_rect.color = color
	var border: ColorRect = get_node_or_null("TopBorder") as ColorRect
	if border != null:
		border.offset_left = -half.x
		border.offset_top = -half.y
		border.offset_right = half.x
		border.offset_bottom = -half.y + 3.0
		border.color = border_color
