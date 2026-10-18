extends CanvasLayer
## Pantalla de carga entre escenas: carga la escena en segundo plano (`ResourceLoader.load_threaded_request`)
## sobre un fondo pintado del destino, con el nombre del mundo y del sector, una barra de progreso de cobre
## y consejos o frases del mundo que van rotando (ui/loading_tips.gd). Fundido al entrar y al salir.
## Sin class_name: lo crea GameManager (`GameManager.change_scene(path)` / `reload_scene()`). Todo cambio de
## escena del juego pasa por acá en vez de `change_scene_to_file`.

const SteamSkin = preload("res://ui/components/steam_skin.gd")
const ArtScript = preload("res://core/art/art.gd")
const LoadingTips = preload("res://ui/loading_tips.gd")

## Tiempo mínimo en pantalla, para que el consejo se alcance a leer aunque la carga sea instantánea.
const MIN_VISIBLE_SECONDS: float = 1.1
const FADE_SECONDS: float = 0.22
const TIP_SECONDS: float = 5.0
## Velocidad máxima de la barra (porcentaje por segundo): la carga real suele saltar de 0 a 100 de golpe.
const BAR_SPEED: float = 140.0
const BG_ZOOM: float = 0.06

var _path: String = ""
var _loading: bool = false
var _loaded: bool = false
var _elapsed: float = 0.0
var _tip_elapsed: float = 0.0
var _progress: Array = []
var _target: float = 0.0
var _shown: float = 0.0
var _last_tip: String = ""

var _root: Control = null
var _bg: TextureRect = null
var _world: Label = null
var _title: Label = null
var _subtitle: Label = null
var _tip_box: Control = null
var _tip_header: Label = null
var _tip: Label = null
var _bar: ProgressBar = null
var _glint: ColorRect = null
var _status: Label = null
var _percent: Label = null
var _gear: TextureRect = null


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
	_loaded = false
	_elapsed = 0.0
	_tip_elapsed = 0.0
	_target = 0.0
	_shown = 0.0
	_fill_texts(path)
	_next_tip(false)
	_bar.value = 0.0
	_root.visible = true
	_root.modulate.a = 0.0
	var fade_in: Tween = create_tween()
	fade_in.tween_property(_root, "modulate:a", 1.0, FADE_SECONDS)
	set_process(true)
	await fade_in.finished
	# El nivel que se deja queda congelado detrás de la pantalla de carga
	get_tree().paused = true
	var err: Error = ResourceLoader.load_threaded_request(path, "PackedScene", false)
	if err != OK:
		push_warning("[SceneLoader] No se pudo cargar en segundo plano %s (%s); carga directa." % [path, error_string(err)])
		set_process(false)
		_finish_direct()
		return
	_loaded = true


func _process(delta: float) -> void:
	if not _loading:
		set_process(false)
		return
	var dt: float = delta / maxf(Engine.time_scale, 0.001)
	_elapsed += dt
	_animate(dt)
	if not _loaded:
		return
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_path, _progress)
	if not _progress.is_empty():
		_target = maxf(_target, float(_progress[0]) * 100.0)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_target = 100.0
			if _elapsed < MIN_VISIBLE_SECONDS or _shown < 99.5:
				return
			set_process(false)
			var packed: PackedScene = ResourceLoader.load_threaded_get(_path) as PackedScene
			if packed == null:
				_finish_direct()
				return
			_set_bar(100.0)
			get_tree().change_scene_to_packed(packed)
			_fade_out()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
			push_warning("[SceneLoader] Falló la carga en segundo plano de %s; carga directa." % _path)
			_finish_direct()


## Barra suavizada, brillo que la recorre, engranaje girando, zoom lento del fondo y rotación de consejos.
func _animate(dt: float) -> void:
	# Mientras carga, la barra avanza sola hasta el 85 % aunque el cargador no informe progreso
	var creep: float = minf(85.0, _elapsed * 45.0)
	var goal: float = maxf(_target, creep) if _target < 100.0 else 100.0
	_set_bar(move_toward(_shown, goal, BAR_SPEED * dt))

	var fill_w: float = _bar.size.x * _shown / 100.0
	var sweep: float = fmod(_elapsed * 1.4, 1.6)
	_glint.position = Vector2(sweep * (fill_w + _glint.size.x) - _glint.size.x, 0.0)
	_glint.size.y = _bar.size.y
	_glint.visible = fill_w > 4.0

	_gear.pivot_offset = _gear.size * 0.5
	_gear.rotation += dt * 2.2

	_bg.pivot_offset = _bg.size * 0.5
	var zoom: float = 1.0 + BG_ZOOM * clampf(_elapsed / 6.0, 0.0, 1.0)
	_bg.scale = Vector2(zoom, zoom)

	var dots: String = ".".repeat(1 + int(_elapsed * 2.5) % 3)
	if _shown >= 99.5:
		_status.text = "LISTO"
	elif _shown < 35.0:
		_status.text = "Cargando recursos" + dots
	elif _shown < 75.0:
		_status.text = "Armando el sector" + dots
	else:
		_status.text = "Despertando a los enemigos" + dots

	_tip_elapsed += dt
	if _tip_elapsed >= TIP_SECONDS:
		_tip_elapsed = 0.0
		_next_tip(true)


func _set_bar(value: float) -> void:
	_shown = value
	_bar.value = value
	_percent.text = "%d%%" % int(round(value))


func _next_tip(animated: bool) -> void:
	var line: Array[String] = LoadingTips.random_line()
	for _i: int in 4:
		if line[1] != _last_tip:
			break
		line = LoadingTips.random_line()
	_last_tip = line[1]
	if not animated:
		_tip_header.text = line[0]
		_tip.text = line[1]
		_tip_box.modulate.a = 1.0
		return
	var tw: Tween = create_tween()
	tw.tween_property(_tip_box, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		_tip_header.text = line[0]
		_tip.text = line[1])
	tw.tween_property(_tip_box, "modulate:a", 1.0, 0.35)


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


## Mundo, título, subtítulo y fondo según la escena destino.
func _fill_texts(path: String) -> void:
	var file: String = path.get_file().get_basename()
	var world: String = ""
	var title: String = file.to_upper()
	var subtitle: String = ""
	var accent: Color = SteamSkin.COLOR_GOLD
	if file == "base_camp":
		world = "EL PASILLO"
		title = "LA CAJA"
		subtitle = "Campamento base"
	elif file == "main_menu":
		title = "WARMACHINE"
		subtitle = "Menú principal"
	elif file == "test_level":
		world = "MODO FRUTA"
		title = "BANCO DE PRUEBAS"
	elif file.begins_with("level_"):
		var parts: PackedStringArray = file.trim_prefix("level_").split("_")
		if parts.size() == 2:
			var chapter: int = int(parts[0])
			var number: int = int(parts[1])
			world = str(LevelRegistry.CHAPTER_NAMES.get(chapter, "MUNDO %d" % chapter))
			accent = LevelRegistry.CHAPTER_COLORS.get(chapter, accent) as Color
			title = "SECTOR %d-%02d" % [chapter, number]
			if chapter == 1 and LevelRegistry.JANO_SECTOR_NAMES.has(number):
				subtitle = str(LevelRegistry.JANO_SECTOR_NAMES[number])
			if number == LevelRegistry.levels_in_chapter(chapter):
				subtitle = (subtitle + " · " if not subtitle.is_empty() else "") + "Sector final"
	_world.text = world
	_world.visible = not world.is_empty()
	_world.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.15))
	_title.text = title
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	_bg.texture = ArtScript.tex(LoadingTips.background_for(path))
	_bg.scale = Vector2.ONE


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var base: ColorRect = ColorRect.new()
	base.color = Color(0.02, 0.02, 0.03, 1.0)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(base)

	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.modulate = Color(0.55, 0.52, 0.55, 1.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)

	# Oscurece arriba (título) y sobre todo abajo (consejo y barra)
	_root.add_child(_gradient_rect([0.0, 0.22, 0.55, 1.0], [0.75, 0.15, 0.25, 0.94]))

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 36)
	_root.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	# Cabecera: mundo, sector y nombre del sector
	_world = _label(15, SteamSkin.COLOR_GOLD)
	column.add_child(_world)
	_title = _label(44, SteamSkin.COLOR_TITLE)
	_title.add_theme_font_override("font", SteamSkin.title_font())
	_title.add_theme_color_override("font_outline_color", SteamSkin.COLOR_OUTLINE)
	_title.add_theme_constant_override("outline_size", 8)
	column.add_child(_title)
	_subtitle = _label(17, SteamSkin.COLOR_TEXT_DIM)
	column.add_child(_subtitle)
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(SteamSkin.COLOR_COPPER, 0.8)
	rule.custom_minimum_size = Vector2(220.0, 2.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(rule)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	# Consejo: barra de acento + cabecera + texto
	var tip_row: HBoxContainer = HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", 14)
	tip_row.custom_minimum_size = Vector2(0.0, 64.0)
	_tip_box = tip_row
	column.add_child(tip_row)
	var accent_bar: ColorRect = ColorRect.new()
	accent_bar.color = SteamSkin.COLOR_COPPER
	accent_bar.custom_minimum_size = Vector2(3.0, 0.0)
	tip_row.add_child(accent_bar)
	var tip_col: VBoxContainer = VBoxContainer.new()
	tip_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_col.add_theme_constant_override("separation", 4)
	tip_row.add_child(tip_col)
	_tip_header = _label(12, SteamSkin.COLOR_GOLD)
	tip_col.add_child(_tip_header)
	_tip = _label(18, Color(0.9, 0.88, 0.84))
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(300.0, 0.0)
	tip_col.add_child(_tip)

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 18.0)
	column.add_child(gap)

	# Estado, porcentaje, barra y engranaje
	var bar_row: HBoxContainer = HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 16)
	column.add_child(bar_row)
	var bar_col: VBoxContainer = VBoxContainer.new()
	bar_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_col.add_theme_constant_override("separation", 6)
	bar_row.add_child(bar_col)
	var info_row: HBoxContainer = HBoxContainer.new()
	bar_col.add_child(info_row)
	_status = _label(13, SteamSkin.COLOR_TEXT_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(_status)
	_percent = _label(13, SteamSkin.COLOR_GOLD)
	info_row.add_child(_percent)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0.0, 14.0)
	_bar.show_percentage = false
	_bar.clip_contents = true
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.055, 0.05, 0.92)
	bg.border_color = Color(SteamSkin.COLOR_COPPER, 0.9)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(3)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.58, 0.22)
	fill.border_color = Color(1.0, 0.82, 0.45)
	fill.border_width_top = 2
	fill.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	bar_col.add_child(_bar)
	_glint = ColorRect.new()
	_glint.color = Color(1.0, 0.95, 0.8, 0.35)
	_glint.size = Vector2(48.0, 14.0)
	_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_glint)

	_gear = TextureRect.new()
	_gear.texture = ArtScript.tex("res://assets/art/ui/ico_gear.png")
	_gear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gear.custom_minimum_size = Vector2(44.0, 44.0)
	_gear.size_flags_vertical = Control.SIZE_SHRINK_END
	_gear.modulate = Color(1.0, 0.85, 0.6, 0.9)
	bar_row.add_child(_gear)


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Rectángulo de pantalla completa con un degradé vertical a negro (offsets de 0 a 1 y su opacidad).
func _gradient_rect(offsets: Array, alphas: Array) -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	var colors: PackedColorArray = PackedColorArray()
	for a: Variant in alphas:
		colors.append(Color(0.0, 0.0, 0.0, float(a)))
	gradient.colors = colors
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 4
	tex.height = 256
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
