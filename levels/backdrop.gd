extends Control
## Fondo pintado a pantalla completa con un leve desplazamiento según la cámara (paralaje).
## Sin class_name: se crea por código desde LevelSkin.

## Exceso del dibujo respecto de la pantalla (fracción) para poder moverlo sin mostrar bordes.
const OVERSCAN: float = 0.14

var texture: Texture2D = null
var tone: Color = Color(0.5, 0.46, 0.48, 1.0)

var _image: TextureRect = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image = TextureRect.new()
	_image.texture = texture
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.modulate = tone
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var view: Vector2 = get_viewport_rect().size
	# Bajo un CanvasLayer no hay padre Control: el tamaño se fija a mano
	position = Vector2.ZERO
	size = view
	_image.size = view * (1.0 + OVERSCAN)
	_image.position = -view * OVERSCAN * 0.5


func _process(_delta: float) -> void:
	if _image == null:
		return
	var camera: Camera2D = get_tree().get_first_node_in_group(&"game_camera") as Camera2D
	if camera == null:
		return
	var view: Vector2 = get_viewport_rect().size
	var center: Vector2 = camera.get_screen_center_position()
	# Vaivén lento: recorre el margen sobrante a lo largo del nivel sin llegar a mostrar los bordes
	var drift: Vector2 = Vector2(sin(center.x * 0.00045), sin(center.y * 0.0009)) * view * OVERSCAN * 0.5
	_image.position = -view * OVERSCAN * 0.5 + drift
