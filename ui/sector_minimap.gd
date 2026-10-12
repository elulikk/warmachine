extends Control
## Minimapa esquemático del sector: dibuja los sólidos del `Environment` (escalados para caber),
## la salida (cuadrado verde) y al jugador (punto amarillo). Sin class_name a propósito: se carga por `preload` desde HUD.

const BG_COLOR: Color = Color(0.06, 0.08, 0.12, 0.88)
const BORDER_COLOR: Color = Color(0.2, 0.3, 0.42, 0.85)
const SOLID_COLOR: Color = Color(0.45, 0.5, 0.58, 1.0)
const EXIT_COLOR: Color = Color(0.3, 1.0, 0.45, 1.0)
const PLAYER_COLOR: Color = Color(1.0, 0.85, 0.3, 1.0)
const PAD: float = 6.0

var _solids: Array[Rect2] = []
var _world: Rect2 = Rect2()
var _exit: Node2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Toma la geometría del nivel. Llamar una vez al entrar (los sólidos no se mueven).
func setup(level: Node) -> void:
	_solids.clear()
	var environment: Node = level.get_node_or_null("Environment")
	if environment != null:
		_collect_solids(environment)
	_world = Rect2()
	for solid: Rect2 in _solids:
		_world = solid if _world.size == Vector2.ZERO else _world.merge(solid)
	_exit = level.get_node_or_null("ExitGate") as Node2D
	queue_redraw()


func _process(_delta: float) -> void:
	# El jugador se mueve: se redibuja cada cuadro (es barato, son pocos rectángulos)
	queue_redraw()


func _collect_solids(node: Node) -> void:
	for child: Node in node.get_children():
		var body: StaticBody2D = child as StaticBody2D
		if body != null:
			var shape_node: CollisionShape2D = body.get_node_or_null("CollisionShape2D") as CollisionShape2D
			var rect_shape: RectangleShape2D = null
			if shape_node != null:
				rect_shape = shape_node.shape as RectangleShape2D
			if rect_shape != null:
				var center: Vector2 = shape_node.global_position
				_solids.append(Rect2(center - rect_shape.size * 0.5, rect_shape.size))
		_collect_solids(child)


## Escala por eje para que el mundo ocupe todo el recuadro con margen. No es proporcional a propósito:
## los sectores son muy anchos y bajos, y con escala uniforme el mapa quedaba como una franja.
func _fit() -> Vector2:
	return (size - Vector2(PAD, PAD) * 2.0) / _world.size


func _to_map(world_pos: Vector2, scale_xy: Vector2) -> Vector2:
	return Vector2(PAD, PAD) + (world_pos - _world.position) * scale_xy


func _draw() -> void:
	var frame: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(frame, BG_COLOR)
	draw_rect(frame, BORDER_COLOR, false, 1.0)
	if _solids.is_empty() or _world.size.x <= 0.0 or _world.size.y <= 0.0:
		return

	var scale_xy: Vector2 = _fit()
	for solid: Rect2 in _solids:
		var top_left: Vector2 = _to_map(solid.position, scale_xy)
		var rect_size: Vector2 = (solid.size * scale_xy).max(Vector2(2.0, 2.0))
		draw_rect(Rect2(top_left, rect_size), SOLID_COLOR)

	if _exit != null and is_instance_valid(_exit):
		var exit_pos: Vector2 = _to_map(_exit.global_position, scale_xy)
		draw_rect(Rect2(exit_pos - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), EXIT_COLOR)

	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null:
		draw_circle(_to_map(player.global_position, scale_xy), 3.0, PLAYER_COLOR)
