class_name MapSelector
extends Area2D
## Terminal interactiva del Campamento Base para iniciar expediciones.
## Al presionar [E], despliega la Matriz de Despliegue Táctico con los 5 Capítulos
## y los 50 niveles de la campaña conectados a LevelRegistry. Permite seleccionar
## cualquier sector para prueba, avance de campaña o farmeo continuo.

const PropSkin = preload("res://entities/props/prop_skin.gd")
@onready var prompt_container: PanelContainer = $Visuals/PromptContainer

var _player_in_range: bool = false
var _selector_window: PanelContainer = null
var _canvas_layer: CanvasLayer = null
var _current_chapter: int = 1
var _tabs_container: HBoxContainer = null
var _levels_grid: GridContainer = null
var _chapter_title_label: Label = null


func _ready() -> void:
	PropSkin.apply(self, "map")
	collision_layer = 0
	collision_mask = 2 # Player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_container != null:
		prompt_container.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _selector_window != null and _selector_window.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			close_selector()
			return
		if event.is_action_pressed("interact") and _player_in_range:
			get_viewport().set_input_as_handled()
			close_selector()
			return
	elif _player_in_range and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		open_selector()


func toggle_selector() -> void:
	if _selector_window != null and _selector_window.visible:
		close_selector()
	else:
		open_selector()


func open_selector() -> void:
	if _selector_window == null:
		_create_selector_window()
	
	_reposition_window()
	_selector_window.visible = true
	_select_chapter(_current_chapter)


func close_selector() -> void:
	if _selector_window != null:
		_selector_window.visible = false


func _create_selector_window() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 25
	get_tree().root.add_child(_canvas_layer)
	
	_selector_window = PanelContainer.new()
	_selector_window.custom_minimum_size = Vector2(720, 480)
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	style.border_color = Color(0.2, 0.65, 0.85, 0.9)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 18.0
	style.content_margin_top = 14.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 14.0
	_selector_window.add_theme_stylebox_override("panel", style)
	
	_canvas_layer.add_child(_selector_window)
	
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	_selector_window.add_child(main_vbox)
	
	# 1. Cabecera con título y botón de cierre
	var header_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title_vbox: VBoxContainer = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_vbox)
	
	var title_label: Label = Label.new()
	title_label.text = "TERMINAL DE EXPEDICIONES // MATRIZ DE DESPLIEGUE TÁCTICO"
	title_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	title_label.add_theme_font_size_override("font_size", 14)
	title_vbox.add_child(title_label)
	
	var desc_label: Label = Label.new()
	desc_label.text = "Selecciona un sector para iniciar despliegue o repetir misiones para farmeo de recursos."
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	desc_label.add_theme_font_size_override("font_size", 10)
	title_vbox.add_child(desc_label)
	
	var close_x_btn: Button = Button.new()
	close_x_btn.text = " ✕ "
	close_x_btn.custom_minimum_size = Vector2(28, 28)
	close_x_btn.pressed.connect(close_selector)
	header_hbox.add_child(close_x_btn)
	
	var sep1: HSeparator = HSeparator.new()
	main_vbox.add_child(sep1)
	
	# 2. Pestañas de Capítulos (1 a 5)
	_tabs_container = HBoxContainer.new()
	_tabs_container.add_theme_constant_override("separation", 8)
	main_vbox.add_child(_tabs_container)
	
	# 3. Banner del Capítulo Seleccionado
	_chapter_title_label = Label.new()
	_chapter_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_title_label.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(_chapter_title_label)
	
	var sep2: HSeparator = HSeparator.new()
	main_vbox.add_child(sep2)
	
	# 4. Grilla de los 10 Niveles del Capítulo (2 columnas x 5 filas)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	_levels_grid = GridContainer.new()
	_levels_grid.columns = 2
	_levels_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_levels_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_levels_grid.add_theme_constant_override("h_separation", 10)
	_levels_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_levels_grid)
	
	var sep3: HSeparator = HSeparator.new()
	main_vbox.add_child(sep3)
	
	# 5. Barra inferior con notas y botón de cerrar
	var footer_hbox: HBoxContainer = HBoxContainer.new()
	main_vbox.add_child(footer_hbox)
	
	var tip_label: Label = Label.new()
	tip_label.text = "Tip: Cada sector conserva tu oro, nivel y equipo. La compuerta de salida guarda tu progreso."
	tip_label.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	tip_label.add_theme_font_size_override("font_size", 10)
	tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(tip_label)
	
	var close_btn: Button = Button.new()
	close_btn.text = "CERRAR TERMINAL [ESC]"
	close_btn.custom_minimum_size = Vector2(160, 32)
	close_btn.pressed.connect(close_selector)
	footer_hbox.add_child(close_btn)


func _reposition_window() -> void:
	if _selector_window == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var win_w: float = 720.0
	var win_h: float = 480.0
	_selector_window.global_position = Vector2(
		maxf(20.0, (vp_size.x - win_w) * 0.5),
		maxf(20.0, (vp_size.y - win_h) * 0.5)
	)


func _select_chapter(chap_num: int) -> void:
	_current_chapter = clampi(chap_num, 1, LevelRegistry.TOTAL_CHAPTERS)
	_render_chapter_tabs()
	_render_levels_grid()


func _render_chapter_tabs() -> void:
	if _tabs_container == null:
		return
	
	for child in _tabs_container.get_children():
		child.queue_free()
	
	for c in range(1, LevelRegistry.TOTAL_CHAPTERS + 1):
		var btn: Button = Button.new()
		btn.text = "CAPÍTULO %d" % c
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		
		var chap_color: Color = Color(0.2, 0.65, 0.85)
		if LevelRegistry.CHAPTER_COLORS.has(c):
			chap_color = LevelRegistry.CHAPTER_COLORS[c]
		
		var is_active: bool = (c == _current_chapter)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
		
		if is_active:
			style.bg_color = Color(chap_color.r * 0.35, chap_color.g * 0.35, chap_color.b * 0.35, 0.95)
			style.border_color = chap_color
			style.border_width_bottom = 3
			style.border_width_top = 1
			style.border_width_left = 1
			style.border_width_right = 1
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			style.bg_color = Color(0.1, 0.13, 0.18, 0.85)
			style.border_color = Color(0.25, 0.3, 0.4, 0.6)
			style.border_width_bottom = 1
			style.border_width_top = 1
			style.border_width_left = 1
			style.border_width_right = 1
			btn.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		
		var hover_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
		hover_style.border_color = chap_color
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", hover_style)
		
		btn.pressed.connect(_select_chapter.bind(c))
		_tabs_container.add_child(btn)
	
	if _chapter_title_label != null:
		var name_str: String = "CAPÍTULO %d" % _current_chapter
		if LevelRegistry.CHAPTER_NAMES.has(_current_chapter):
			name_str = LevelRegistry.CHAPTER_NAMES[_current_chapter]
		var chap_color: Color = Color(0.3, 0.85, 1.0)
		if LevelRegistry.CHAPTER_COLORS.has(_current_chapter):
			chap_color = LevelRegistry.CHAPTER_COLORS[_current_chapter]
		
		_chapter_title_label.text = "◈ %s ◈" % name_str
		_chapter_title_label.add_theme_color_override("font_color", chap_color)


func _render_levels_grid() -> void:
	if _levels_grid == null:
		return
	
	for child in _levels_grid.get_children():
		child.queue_free()
	
	var chap_color: Color = Color(0.2, 0.65, 0.85)
	if LevelRegistry.CHAPTER_COLORS.has(_current_chapter):
		chap_color = LevelRegistry.CHAPTER_COLORS[_current_chapter]
	
	var levels_info: Array[Dictionary] = LevelRegistry.get_levels_for_chapter(_current_chapter)
	var sm: SaveManager = SaveManager.get_instance()
	
	for lvl in levels_info:
		var lvl_path: String = str(lvl.get("path", ""))
		var lvl_num: int = int(lvl.get("number", 1))
		var is_boss: bool = bool(lvl.get("is_boss", false))
		var title: String = str(lvl.get("title", "Sector %d-%02d" % [_current_chapter, lvl_num]))
		
		var is_unlocked: bool = true
		if sm != null:
			# Si SaveManager tiene lista de desbloqueados, lo indicamos visualmente
			is_unlocked = sm.unlocked_levels.has(lvl_path) or (lvl_num == 1 and _current_chapter == 1)
		
		var btn: Button = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		
		if is_boss:
			btn.text = "★ %s [JEFE FINAL]" % title
		else:
			btn.text = "▶ %s" % title
		
		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_right = 4
		btn_style.corner_radius_bottom_left = 4
		btn_style.content_margin_left = 12.0
		btn_style.content_margin_right = 12.0
		
		if is_boss:
			btn_style.bg_color = Color(0.22, 0.08, 0.1, 0.9)
			btn_style.border_color = Color(1.0, 0.35, 0.3, 0.9)
			btn_style.border_width_bottom = 2
			btn_style.border_width_top = 1
			btn_style.border_width_left = 1
			btn_style.border_width_right = 1
			btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.6))
		else:
			btn_style.bg_color = Color(0.09, 0.12, 0.17, 0.9)
			btn_style.border_color = Color(0.2, 0.3, 0.42, 0.7)
			btn_style.border_width_bottom = 1
			btn_style.border_width_top = 1
			btn_style.border_width_left = 1
			btn_style.border_width_right = 1
			btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		
		var btn_hover: StyleBoxFlat = btn_style.duplicate() as StyleBoxFlat
		btn_hover.bg_color = Color(chap_color.r * 0.25, chap_color.g * 0.25, chap_color.b * 0.25, 0.95)
		btn_hover.border_color = chap_color
		
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_hover)
		btn.add_theme_stylebox_override("focus", btn_hover)
		
		# Bloqueo real: sin contenido todavía, o sin desbloquear (se gana extrayendo el sector anterior)
		if not LevelRegistry.is_implemented(lvl_path):
			btn.text = "%s  —  PENDIENTE" % title
			btn.disabled = true
		elif not is_unlocked:
			btn.text = "🔒 %s  —  BLOQUEADO" % title
			btn.disabled = true
		if btn.disabled:
			btn.add_theme_stylebox_override("disabled", btn_style)
			btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.46, 0.54))

		btn.pressed.connect(_on_level_selected.bind(lvl_path))
		_levels_grid.add_child(btn)


func _on_level_selected(level_path: String) -> void:
	close_selector()
	
	# Autoguardar antes de iniciar la misión
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()
	
	print("[MapSelector] Iniciando expedición hacia: %s" % level_path)
	GameManager.change_scene(level_path)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_in_range = true
		if prompt_container != null:
			prompt_container.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_in_range = false
		if prompt_container != null:
			prompt_container.visible = false
		close_selector()
