extends Node2D
## Resplandor dorado alrededor del personaje al juntar experiencia (aditivo, se apaga solo).
## Cada orbe sube la intensidad un poco (con tope) y baja sola: con una lluvia de orbes queda un resplandor parejo.
## Sin class_name a propósito: lo crea player.gd por preload.

const CAP: float = 1.0
const STEP: float = 0.45
const FADE_PER_SECOND: float = 2.2
const COLOR: Color = Color(1.0, 0.82, 0.3, 1.0)

var intensity: float = 0.0


func _ready() -> void:
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 1
	visible = false


func pulse() -> void:
	intensity = minf(CAP, intensity + STEP * (1.0 - intensity / CAP * 0.6))
	visible = true


func _process(delta: float) -> void:
	intensity = maxf(0.0, intensity - FADE_PER_SECOND * delta)
	if intensity <= 0.0:
		visible = false
		return
	queue_redraw()


func _draw() -> void:
	for i in range(10):
		var radius: float = 24.0 + float(i) * 6.0
		var alpha: float = intensity * (0.16 - float(i) * 0.014)
		draw_circle(Vector2(0.0, -34.0), radius, Color(COLOR.r, COLOR.g, COLOR.b, alpha))
