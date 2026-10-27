@tool
extends Node2D
## Tramo prearmado de nivel: se arrastra a mano dentro de un sector (hijo directo de la raíz, no de Environment)
## y se coloca en el editor con el borde izquierdo (origen del tramo) donde empieza.
##
## - El nodo `Geometry` (StaticBody2D + ColorRect, igual que `Environment`) se pasa solo al `Environment` del
##   sector al arrancar, conservando la posición: así `LevelSkin` lo reviste con el tileset del mundo.
## - Todo lo demás (enemigos, arenas, checkpoints, carteles) se queda en el tramo.
## - Suelo del tramo a y=556 (cara superior), igual que los sectores. El `width` solo sirve para ver el
##   rectángulo en el editor y para encadenar tramos (el siguiente va en `x + width`).

@export var width: float = 1600.0:
	set(value):
		width = value
		queue_redraw()
@export var chunk_name: String = "":
	set(value):
		chunk_name = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var geometry: Node2D = get_node_or_null("Geometry") as Node2D
	var environment: Node = get_parent().get_node_or_null("Environment") if get_parent() != null else null
	if geometry == null or environment == null:
		return
	var at: Transform2D = geometry.global_transform
	remove_child(geometry)
	environment.add_child(geometry)
	geometry.global_transform = at


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var top: float = 300.0
	draw_rect(Rect2(0.0, top, width, 256.0), Color(0.3, 0.8, 1.0, 0.07), true)
	draw_rect(Rect2(0.0, top, width, 256.0), Color(0.3, 0.8, 1.0, 0.8), false, 2.0)
	draw_line(Vector2(0.0, top), Vector2(0.0, 556.0 + 80.0), Color(0.3, 1.0, 0.5, 1.0), 4.0)
	draw_line(Vector2(width, top), Vector2(width, 556.0 + 80.0), Color(1.0, 0.5, 0.3, 1.0), 4.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(8.0, top + 22.0), "%s  (ancho %d)" % [chunk_name, int(width)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(1, 1, 1, 0.9))
