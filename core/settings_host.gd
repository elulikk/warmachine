extends CanvasLayer
## Anfitrión de las opciones de juego: contador de FPS en pantalla, silencio al perder el foco y posprocesado
## (`core/post_fx.gd`: viñeta, grano, resplandor y filtro para daltonismo).
## Lo crea `settings.gd` bajo la raíz del árbol; vive siempre (también en pausa).

## Se carga con `load()` y no con `preload()`: settings.gd precarga este script y un preload cruzado no compila.
var _settings: GDScript = load("res://core/settings.gd") as GDScript

var _label: Label = null
var _unfocused: bool = false
var _post_fx: Node = null


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.name = "FpsLabel"
	_label.position = Vector2(8.0, 6.0)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_post_fx = (load("res://core/post_fx.gd") as GDScript).new() as Node
	_post_fx.name = "PostFx"
	add_child(_post_fx)
	refresh()


func refresh() -> void:
	if _label != null:
		_label.visible = bool(_settings.call("get_bool", "show_fps"))
	if _post_fx != null and is_instance_valid(_post_fx) and _post_fx.is_inside_tree():
		_post_fx.call("refresh")
	_update_mute()


func _process(_delta: float) -> void:
	if _label != null and _label.visible:
		_label.text = "%d FPS" % int(Engine.get_frames_per_second())


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_unfocused = true
		_update_mute()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_unfocused = false
		_update_mute()


func _update_mute() -> void:
	var master: int = AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, _unfocused and bool(_settings.call("get_bool", "mute_unfocused")))
