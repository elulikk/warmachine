extends RefCounted
## Cursor del sistema reemplazado por una mira pequeña (cuatro marcas con hueco
## central y punto), dibujada por código con contorno oscuro para que se lea
## sobre cualquier fondo. El punto caliente es el centro.

const SIZE := 25
const CENTER := 12
const GAP := 3
const ARM := 5
const FILL := Color(1.0, 0.95, 0.85)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.85)

const SHAPES: Array[int] = [
	Input.CURSOR_ARROW,
	Input.CURSOR_POINTING_HAND,
	Input.CURSOR_CAN_DROP,
	Input.CURSOR_DRAG,
]


static func install() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Image directa (no ImageTexture): evita una textura de GPU sin liberar al cerrar
	var img := _build_image()
	for shape in SHAPES:
		Input.set_custom_mouse_cursor(img, shape, Vector2(CENTER, CENTER))


static func _build_image() -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var pts: Array[Vector2i] = [Vector2i(CENTER, CENTER)]
	for i in range(GAP, GAP + ARM):
		pts.append(Vector2i(CENTER + i, CENTER))
		pts.append(Vector2i(CENTER - i, CENTER))
		pts.append(Vector2i(CENTER, CENTER + i))
		pts.append(Vector2i(CENTER, CENTER - i))
	# Contorno primero, relleno encima
	for p in pts:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				_put(img, p.x + dx, p.y + dy, OUTLINE)
	for p in pts:
		_put(img, p.x, p.y, FILL)
	return img


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.set_pixel(x, y, c)
