extends RefCounted
## Qué tan lejos de la cámara está algo. Sirve para dormir lo que nadie ve (animación de enemigos, redibujado de
## áreas, gotas): el daño y la lógica siguen, solo se ahorra lo que es puramente visual.
## Sin class_name a propósito: se usa por `preload` (ver class-name-cache-gotcha).
##
## El rectángulo visible se calcula una sola vez por cuadro y se comparte entre todos los que preguntan.

static var _stamp: int = -1
static var _rect: Rect2 = Rect2(-1.0e9, -1.0e9, 2.0e9, 2.0e9)


## Rectángulo que ve la cámara en coordenadas del mundo, agrandado `margin` px por cada lado.
static func world_rect(ctx: Node, margin: float = 0.0) -> Rect2:
	var frame: int = Engine.get_process_frames()
	if frame != _stamp:
		_stamp = frame
		var vp: Viewport = ctx.get_viewport() if ctx != null and ctx.is_inside_tree() else null
		if vp != null:
			_rect = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return _rect.grow(margin)


## true si `node` está dentro de lo que ve la cámara (más `margin` px de colchón).
static func near(node: Node2D, margin: float = 160.0) -> bool:
	if node == null or not node.is_inside_tree():
		return true
	return world_rect(node, margin).has_point(node.global_position)
