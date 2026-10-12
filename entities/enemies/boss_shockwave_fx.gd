extends Node2D
## Efecto de suelo de la onda de choque del jefe (solo visual; el daño lo resuelve `brute_boss.gd`).
## `burst = false`: franja de aviso roja que se llena durante `duration`. `burst = true`: la onda dorada se expande.

var half_width: float = 240.0
var duration: float = 0.8
var burst: bool = false

var _t: float = 0.0


func _ready() -> void:
	z_index = 4


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = clampf(_t / maxf(duration, 0.01), 0.0, 1.0)
	if burst:
		var w: float = half_width * (0.2 + 0.8 * k)
		var color: Color = Color(1.0, 0.8, 0.3, 0.8 * (1.0 - k))
		draw_rect(Rect2(-w, -14.0, w * 2.0, 14.0), color)
		draw_rect(Rect2(-w, -18.0, w * 2.0, 4.0), Color(1.0, 1.0, 0.8, color.a))
	else:
		var color: Color = Color(1.0, 0.2, 0.15, 0.18 + 0.25 * k)
		draw_rect(Rect2(-half_width, -10.0, half_width * 2.0, 10.0), color)
		# Borde de aviso que parpadea cada vez más rápido
		var blink: float = 0.5 + 0.5 * sin(_t * (14.0 + 30.0 * k))
		draw_rect(Rect2(-half_width, -12.0, half_width * 2.0, 2.0), Color(1.0, 0.5, 0.4, 0.4 + 0.5 * blink))
