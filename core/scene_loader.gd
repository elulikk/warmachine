extends CanvasLayer
## Pantalla de carga entre escenas: carga la escena en segundo plano (`ResourceLoader.load_threaded_request`),
## muestra una barra de progreso con un consejo y hace un fundido al entrar.
## Sin class_name: lo crea GameManager (`GameManager.change_scene(path)` / `reload_scene()`). Todo cambio de
## escena del juego pasa por acá en vez de `change_scene_to_file`.

const MIN_VISIBLE_SECONDS: float = 0.35
const FADE_SECONDS: float = 0.16

const TIPS: Array[String] = [
	"El Bruto Acorazado no salta: subite a una plataforma y castigalo desde arriba.",
	"La runa de Afilado suma daño antes de la armadura: rinde mucho contra blindados.",
	"[R] recarga antes de que se vacíe el cargador. Cambiar de arma cancela la recarga.",
	"Las pociones se usan con los botones laterales del ratón o los casilleros 4 a 6.",
	"Los checkpoints guardan dónde reaparecés si caés en combate.",
	"El Herrero engarza y quita runas de los sockets de tus armas.",
	"Repetir un sector es la forma más rápida de juntar monedas y experiencia.",
	"En Opciones > Accesibilidad podés agrandar la interfaz o activar el filtro para daltonismo.",
	"Con [C] ves la ficha del personaje con el DPS real de tu arma.",
	"La dificultad se cambia en cualquier momento desde Opciones > Juego.",
]

var _path: String = ""
var _loading: bool = false
var _elapsed: float = 0.0
var _progress: Array = []

var _root: Control = null
var _bar: ProgressBar = null
var _title: Label = null
var _tip: Label = null


func _ready() -> void:
	layer = 180
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	set_process(false)


func is_loading() -> bool:
	return _loading


func go(path: String) -> void:
	if _loading or path.is_empty():
		return
	_path = path
	_loading = true
	_elapsed = 0.0
	_title.text = "CARGANDO %s" % _scene_title(path)
	_tip.text = TIPS[randi() % TIPS.size()]
	_bar.value = 0.0
	_root.visible = true
	_root.modulate.a = 0.0
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, FADE_SECONDS)
	await fade_in.finished
	# El nivel que se deja queda congelado detrás de la pantalla de carga
	get_tree().paused = true
	var err: Error = ResourceLoader.load_threaded_request(path, "PackedScene", false)
	if err != OK:
		push_warning("[SceneLoader] No se pudo cargar en segundo plano %s (%s); carga directa." % [path, error_string(err)])
		_finish_direct()
		return
	set_process(true)


func _process(delta: float) -> void:
	if not _loading:
		set_process(false)
		return
	_elapsed += delta / maxf(Engine.time_scale, 0.001)
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_path, _progress)
	if not _progress.is_empty():
		_bar.value = maxf(_bar.value, float(_progress[0]) * 100.0)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			if _elapsed < MIN_VISIBLE_SECONDS:
				return
			set_process(false)
			var packed: PackedScene = ResourceLoader.load_threaded_get(_path) as PackedScene
			if packed == null:
				_finish_direct()
				return
			_bar.value = 100.0
			get_tree().change_scene_to_packed(packed)
			_fade_out()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
			push_warning("[SceneLoader] Falló la carga en segundo plano de %s; carga directa." % _path)
			_finish_direct()


func _finish_direct() -> void:
	get_tree().change_scene_to_file(_path)
	_fade_out()


func _unpause() -> void:
	if get_tree() != null:
		get_tree().paused = false


func _fade_out() -> void:
	_unpause()
	# Dos cuadros: la escena nueva entra al árbol y dibuja su primer cuadro detrás de la pantalla de carga
	await get_tree().process_frame
	await get_tree().process_frame
	var fade: Tween = create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, FADE_SECONDS)
	await fade.finished
	_root.visible = false
	_loading = false


func _scene_title(path: String) -> String:
	var file: String = path.get_file().get_basename()
	if file == "base_camp":
		return "CAMPAMENTO BASE"
	if file == "main_menu":
		return "MENÚ PRINCIPAL"
	if file == "test_level":
		return "BANCO DE PRUEBAS"
	if file.begins_with("level_"):
		var parts: PackedStringArray = file.trim_prefix("level_").split("_")
		if parts.size() == 2:
			return "SECTOR %d-%d" % [int(parts[0]), int(parts[1])]
	return file.to_upper()


func _build() -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.03, 0.035, 0.05, 1.0)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(520.0, 0.0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(0.95, 0.72, 0.35))
	box.add_child(_title)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0.0, 18.0)
	_bar.show_percentage = false
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.09, 0.08)
	bg.border_color = Color(0.45, 0.33, 0.18)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(3)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.55, 0.2)
	fill.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)

	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_font_size_override("font_size", 13)
	_tip.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	box.add_child(_tip)
