extends Node2D
## Destello de aviso en el punto donde va a nacer un enemigo: un anillo que se cierra
## hacia el centro, un disco que parpadea y un círculo fijo tipo portal.
## Se crea con `play()` y se libera solo al cumplirse `_duration`.

const RADIUS := 28.0
const COLOR := Color(0.45, 0.85, 1.0)

var _duration: float = 1.0
var _elapsed: float = 0.0


## Muestra el destello en `pos` dentro de `container` durante `duration` segundos.
static func play(container: Node, pos: Vector2, duration: float) -> void:
	var fx := Node2D.new()
	fx.set_script(load("res://combat/spawn_telegraph.gd"))
	fx.set("_duration", duration)
	container.add_child(fx)
	fx.global_position = pos


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var alpha: float = clampf(minf(t * 5.0, (1.0 - t) * 4.0), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * 18.0)

	draw_circle(Vector2.ZERO, RADIUS * 0.8, Color(COLOR, alpha * (0.12 + 0.12 * pulse)))
	draw_arc(Vector2.ZERO, RADIUS * 1.2, 0.0, TAU, 40, Color(COLOR, alpha * 0.5), 2.0, true)
	draw_arc(Vector2.ZERO, lerpf(RADIUS * 1.8, RADIUS * 0.6, t), 0.0, TAU, 40, Color(COLOR, alpha), 3.0, true)
	draw_arc(Vector2.ZERO, RADIUS * 0.4, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, alpha * 0.8), 2.0, true)
