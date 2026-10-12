extends Node2D
## Aura que pulsa detrás de un objeto del piso (ítem, arma o runa). El color sale de la rareza.
## Con "reducir destellos" queda fija, sin pulso.

const SettingsScript = preload("res://core/settings.gd")

var color: Color = Color.WHITE
var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 0.5
	if not SettingsScript.reduce_flashes():
		pulse = 0.5 + 0.5 * sin(_time * 3.0)
	for i in range(3):
		var radius: float = 18.0 + float(i) * 7.0 + pulse * 3.0
		var alpha: float = (0.28 - float(i) * 0.08) * (0.6 + 0.4 * pulse)
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, alpha))
