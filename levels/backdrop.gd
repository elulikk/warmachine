extends Control
## Fondo pintado a pantalla completa con un leve desplazamiento según la cámara (paralaje).
## Puede ser una imagen fija o varias capas con distinta profundidad (de atrás hacia adelante).
## Sin class_name: se crea por código desde LevelSkin.

## Tamaño del dibujo respecto de la pantalla, con proporción fija (sin estirarlo). Lo que sobra se recorta.
const SCALE: float = 1.3
## Dónde queda el dibujo en vertical: 0 = borde superior arriba, 1 = borde inferior abajo.
## Casi abajo para que se vean las puertas y ventanas de la planta baja, por encima del suelo del juego.
const ANCHOR_Y: float = 0.9
## Amplitud del vaivén vertical alrededor de ANCHOR_Y (fracción del sobrante). El horizontal recorre todo el sobrante.
const SWAY_Y: float = 0.1

## Cuánto se agranda el dibujo sobre la pantalla. Las capas usan menos zoom: con más, la imagen de origen se ve borrosa.
var zoom: float = SCALE
## Imagen fija: se usa solo si no hay capas.
var texture: Texture2D = null
var tone: Color = Color(0.5, 0.46, 0.48, 1.0)
## Capas de paralaje, de atrás hacia adelante: [{"texture": Texture2D, "depth": float}, ...].
## depth 0 = la capa no se mueve; 1 = se mueve como el dibujo de una imagen fija. Vacío = imagen fija.
var layers: Array = []

## Un TextureRect por capa (o uno solo con la imagen fija), y su profundidad.
var _rects: Array[TextureRect] = []
var _depths: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var items: Array = layers
	if items.is_empty():
		items = [{"texture": texture, "depth": 1.0}]
	for item: Dictionary in items:
		var rect: TextureRect = TextureRect.new()
		rect.texture = item["texture"] as Texture2D
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.modulate = tone
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_rects.append(rect)
		_depths.append(float(item["depth"]))
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var view: Vector2 = get_viewport_rect().size
	# Bajo un CanvasLayer no hay padre Control: el tamaño se fija a mano
	position = Vector2.ZERO
	size = view
	# Todas las capas comparten el tamaño de la primera, así que el recorte es el mismo
	var tex: Texture2D = _rects[0].texture if not _rects.is_empty() else null
	var tex_size: Vector2 = tex.get_size() if tex != null else view
	# Cubre la pantalla con escala uniforme y deja el sobrante para moverlo
	var k: float = maxf(view.x / tex_size.x, view.y / tex_size.y) * zoom
	for rect: TextureRect in _rects:
		rect.size = tex_size * k
	_place(view, Vector2.ZERO)


## Coloca cada capa: `sway` va de -1 a 1 en cada eje. Las capas lejanas (depth bajo) se mueven menos.
func _place(view: Vector2, sway: Vector2) -> void:
	for i: int in _rects.size():
		var rect: TextureRect = _rects[i]
		var depth: float = _depths[i]
		var excess: Vector2 = rect.size - view
		var x: float = -excess.x * (0.5 + 0.5 * sway.x * depth)
		var y: float = -excess.y * (ANCHOR_Y + SWAY_Y * sway.y * depth)
		rect.position = Vector2(x, y)


func _process(_delta: float) -> void:
	if _rects.is_empty():
		return
	var camera: Camera2D = get_tree().get_first_node_in_group(&"game_camera") as Camera2D
	if camera == null:
		return
	var center: Vector2 = camera.get_screen_center_position()
	# Vaivén lento: recorre el sobrante a lo largo del nivel sin llegar a mostrar los bordes
	var sway: Vector2 = Vector2(sin(center.x * 0.00045), sin(center.y * 0.0009))
	_place(get_viewport_rect().size, sway)
