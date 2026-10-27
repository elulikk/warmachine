extends PanelContainer
## Cinta de opciones ("ribbon") reutilizable para herramientas de depuración: pestañas arriba, grupos de controles
## en el cuerpo, barra de estado abajo. Sin class_name a propósito: se carga por `preload`.
##
## Es genérica: no sabe nada de la Sala de Estrés. Quien la usa solo declara contenido:
##
##     var ribbon = RibbonScript.new("MI HERRAMIENTA")
##     ribbon.add_tab("enemigos", "Enemigos")
##     var g = ribbon.add_group("enemigos", "Generador")
##     g.toggle("spawner", "Activo", false, func(on: bool) -> void: ..., {"key": KEY_F5, "tip": "..."})
##     g.segmented("rate", "Ritmo", ["1", "5", "10"], 1, func(i: int) -> void: ...)
##     ribbon.add_status("fps", func() -> String: return "%d FPS" % Engine.get_frames_per_second())
##     ribbon.build_shortcuts_tab("atajos", "Atajos")   # lista sola las teclas declaradas
##
## - Va anclada arriba a todo el ancho; avisa con `layout_changed` cuando cambia su alto (contraer, ocultar) para que
##   quien la usa corra el HUD y la cámara.
## - Doble clic en una pestaña (o el botón de la derecha) contrae la cinta; la tecla `toggle_key` (F4) la oculta.
## - `set_value(id, valor)` sincroniza un control desde código sin disparar su señal (cuando otro atajo cambió el estado).
## - Las teclas declaradas con `key` se despachan acá (`_unhandled_input`) aunque la cinta esté oculta.

const RibbonTheme = preload("res://ui/debug/ribbon_theme.gd")
const GroupScript = preload("res://ui/debug/ribbon_group.gd")

## El alto de la cinta cambió (contraída, expandida u oculta). Hay que leer `effective_height()`.
signal layout_changed
signal tab_changed(tab_id: String)

## Alto fijo del cuerpo: todas las pestañas miden lo mismo para que la cinta no salte al cambiar de una a otra.
const BODY_HEIGHT: float = 108.0
const REFRESH_INTERVAL: float = 0.25

var title_text: String = ""
var toggle_key: Key = KEY_F4
var collapsed: bool = false

var _tab_row: HBoxContainer = null
var _tab_spacer: Control = null
var _body: PanelContainer = null
var _page_holder: MarginContainer = null
var _status_row: HBoxContainer = null
var _collapse_button: Button = null
var _tab_group: ButtonGroup = ButtonGroup.new()

var _tab_order: Array[String] = []
var _tab_titles: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _tab_pages: Dictionary = {}
var _page_groups: Dictionary = {}
var _active_tab: String = ""

var _controls: Dictionary = {}
## Entradas {key, label, tab, group, action} de teclas manejadas por la cinta.
var _key_bindings: Array[Dictionary] = []
## Todas las teclas que se muestran en la pestaña de atajos, en el orden en que se declararon: {key_text, label, tab}.
var _shortcut_list: Array[Dictionary] = []
var _live: Array[Dictionary] = []
var _refresh_timer: float = 0.0


## `left_inset`: espacio a la izquierda del título (por si algo de la pantalla, como el contador de FPS, lo tapa).
func _init(title: String = "", left_inset: float = 0.0) -> void:
	title_text = title
	theme = RibbonTheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_theme_stylebox_override("panel", _bottom_edge_style())

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Fila de pestañas
	var tab_bar: PanelContainer = PanelContainer.new()
	tab_bar.add_theme_stylebox_override("panel", RibbonTheme.box(RibbonTheme.BG_BAR, Color(0, 0, 0, 0), 0, 0, Vector4(8, 4, 8, 0)))
	root.add_child(tab_bar)
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 2)
	tab_bar.add_child(_tab_row)
	var title_label: Label = Label.new()
	title_label.text = title.to_upper()
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", RibbonTheme.ACCENT)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_label.custom_minimum_size.x = 0.0
	if left_inset > 0.0:
		_tab_row.add_child(_spacer(left_inset))
	_tab_row.add_child(title_label)
	_tab_row.add_child(_spacer(14.0))
	_tab_spacer = Control.new()
	_tab_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_row.add_child(_tab_spacer)
	var hint: Label = Label.new()
	hint.text = "%s oculta  ·  doble clic en una pestaña contrae" % OS.get_keycode_string(toggle_key)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", RibbonTheme.TEXT_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tab_row.add_child(hint)
	_collapse_button = Button.new()
	_collapse_button.theme_type_variation = &"RibbonTab"
	_collapse_button.focus_mode = Control.FOCUS_NONE
	_collapse_button.tooltip_text = "Contraer o expandir la cinta"
	_collapse_button.icon = RibbonTheme.icon("up", 0.6)
	_collapse_button.pressed.connect(func() -> void: set_collapsed(not collapsed))
	_tab_row.add_child(_collapse_button)

	# Cuerpo
	_body = PanelContainer.new()
	_body.custom_minimum_size.y = BODY_HEIGHT
	var body_style: StyleBoxFlat = RibbonTheme.box(RibbonTheme.BG_BODY, RibbonTheme.BORDER, 0, 0, Vector4(0, 0, 0, 0))
	body_style.border_width_top = 1
	_body.add_theme_stylebox_override("panel", body_style)
	root.add_child(_body)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	_page_holder = MarginContainer.new()
	_page_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_holder.add_theme_constant_override("margin_left", 10)
	_page_holder.add_theme_constant_override("margin_right", 10)
	_page_holder.add_theme_constant_override("margin_top", 6)
	_page_holder.add_theme_constant_override("margin_bottom", 3)
	scroll.add_child(_page_holder)

	# Barra de estado
	var status_bar: PanelContainer = PanelContainer.new()
	status_bar.add_theme_stylebox_override("panel", RibbonTheme.box(RibbonTheme.BG_DEEP, Color(0, 0, 0, 0), 0, 0, Vector4(12, 3, 12, 3)))
	root.add_child(status_bar)
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 0)
	status_bar.add_child(_status_row)

	resized.connect(func() -> void: layout_changed.emit())
	visibility_changed.connect(func() -> void: layout_changed.emit())


# ==============================================================================
# Estructura
# ==============================================================================

func add_tab(tab_id: String, tab_title: String, tip: String = "") -> void:
	var button: Button = Button.new()
	button.theme_type_variation = &"RibbonTab"
	button.text = tab_title
	button.toggle_mode = true
	button.button_group = _tab_group
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tip
	button.pressed.connect(_on_tab_pressed.bind(tab_id))
	button.gui_input.connect(_on_tab_gui_input)
	_tab_row.add_child(button)
	_tab_row.move_child(button, _tab_spacer.get_index())

	var page: HBoxContainer = HBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	page.visible = false
	_page_holder.add_child(page)

	_tab_order.append(tab_id)
	_tab_titles[tab_id] = tab_title
	_tab_buttons[tab_id] = button
	_tab_pages[tab_id] = page
	_page_groups[tab_id] = 0
	if _active_tab.is_empty():
		select_tab(tab_id)


## Agrega un grupo al final de la pestaña (con un separador vertical antes si no es el primero).
func add_group(tab_id: String, group_title: String) -> GroupScript:
	var page: HBoxContainer = _tab_pages[tab_id] as HBoxContainer
	if int(_page_groups[tab_id]) > 0:
		page.add_child(VSeparator.new())
	_page_groups[tab_id] = int(_page_groups[tab_id]) + 1
	var group: GroupScript = GroupScript.new(self, tab_id, group_title)
	page.add_child(group)
	return group


func select_tab(tab_id: String) -> void:
	if not _tab_pages.has(tab_id):
		return
	_active_tab = tab_id
	for other: String in _tab_order:
		(_tab_pages[other] as Control).visible = other == tab_id
		(_tab_buttons[other] as Button).set_pressed_no_signal(other == tab_id)
	tab_changed.emit(tab_id)


func set_collapsed(on: bool) -> void:
	collapsed = on
	_body.visible = not on
	_collapse_button.icon = RibbonTheme.icon("down" if on else "up", 0.6)
	# Con la cinta contraída el alto baja; hay que forzar el recálculo del contenedor
	custom_minimum_size.y = 0.0
	size.y = 0.0


## Alto que ocupa hoy en pantalla (0 si está oculta). Es lo que hay que reservar en el HUD y la cámara.
func effective_height() -> float:
	return size.y if visible else 0.0


## Barra de estado: `provider() -> String` se vuelve a leer 4 veces por segundo. `color() -> Color` es opcional.
func add_status(id: String, provider: Callable, opts: Dictionary = {}) -> Label:
	if _status_row.get_child_count() > 0:
		_status_row.add_child(VSeparator.new())
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", RibbonTheme.TEXT_DIM)
	label.custom_minimum_size.x = float(opts.get("min_width", 0.0))
	label.text = str(provider.call())
	if opts.has("tip"):
		label.tooltip_text = str(opts["tip"])
		label.mouse_filter = Control.MOUSE_FILTER_STOP
	_status_row.add_child(label)
	register_live(label, provider, opts.get("color", Callable()))
	_controls[id] = label
	return label


# ==============================================================================
# Registro de controles, teclas y textos vivos (lo usan los grupos)
# ==============================================================================

func register_control(id: String, control: Control) -> void:
	if _controls.has(id):
		push_warning("Ribbon: el id '%s' ya existe; se reemplaza." % id)
	_controls[id] = control


func register_live(label: Label, provider: Callable, color_provider: Variant) -> void:
	var color_callable: Callable = color_provider if color_provider is Callable else Callable()
	_live.append({"label": label, "provider": provider, "color": color_callable})


## Declara una tecla que ejecuta `action`. Sale en la pestaña de atajos bajo `tab_id` / `group_title`.
func bind_key(key: int, action: Callable, label: String, tab_id: String, key_text: String = "") -> void:
	for entry: Dictionary in _key_bindings:
		if int(entry["key"]) == key:
			push_warning("Ribbon: la tecla %s ya está asignada." % OS.get_keycode_string(key as Key))
			return
	_key_bindings.append({"key": key, "action": action})
	_shortcut_list.append({"key_text": key_text if not key_text.is_empty() else OS.get_keycode_string(key as Key), "label": label, "tab": tab_id})


## Anota en la pestaña de atajos una tecla que maneja otro (por ejemplo una acción del Input Map).
func add_hint(tab_id: String, key_text: String, label: String) -> void:
	_shortcut_list.append({"key_text": key_text, "label": label, "tab": tab_id})


## Cambia un control desde código sin disparar su señal. Sirve para reflejar un estado que cambió por otro camino.
func set_value(id: String, value: Variant) -> void:
	var control: Control = _controls.get(id) as Control
	if control == null:
		return
	if control is OptionButton:
		(control as OptionButton).select(int(value))
	elif control is BaseButton:
		(control as BaseButton).set_pressed_no_signal(bool(value))
	elif control is HBoxContainer:
		var index: int = int(value)
		for i: int in range(control.get_child_count()):
			var chip: BaseButton = control.get_child(i) as BaseButton
			if chip != null:
				chip.set_pressed_no_signal(i == index)


func get_control(id: String) -> Control:
	return _controls.get(id) as Control


## Pestaña de atajos armada sola con todo lo que se declaró con `key` o `hint`, un grupo por pestaña de origen.
func build_shortcuts_tab(tab_id: String, tab_title: String) -> void:
	add_tab(tab_id, tab_title, "Todas las teclas de esta herramienta")
	var by_tab: Dictionary = {}
	for entry: Dictionary in _shortcut_list:
		var list: Array = by_tab.get(entry["tab"], []) as Array
		list.append([str(entry["key_text"]), str(entry["label"])])
		by_tab[entry["tab"]] = list
	list_global_shortcuts(by_tab)
	for source_tab: String in _tab_order:
		if not by_tab.has(source_tab):
			continue
		var group: GroupScript = add_group(tab_id, str(_tab_titles[source_tab]))
		for pair: Array in (by_tab[source_tab] as Array):
			group.shortcut_row(str(pair[0]), str(pair[1]))


## Teclas propias de la cinta (se agregan a la primera pestaña que tenga atajos).
func list_global_shortcuts(by_tab: Dictionary) -> void:
	var first: String = _tab_order[0] if not _tab_order.is_empty() else ""
	if first.is_empty():
		return
	var list: Array = by_tab.get(first, []) as Array
	list.insert(0, [OS.get_keycode_string(toggle_key), "Mostrar u ocultar la cinta"])
	by_tab[first] = list


# ==============================================================================
# Bucle
# ==============================================================================

func _ready() -> void:
	refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		refresh()


## Vuelve a leer todos los textos vivos (barra de estado y lecturas de los grupos).
func refresh() -> void:
	for entry: Dictionary in _live:
		var label: Label = entry["label"] as Label
		if not is_instance_valid(label):
			continue
		label.text = str((entry["provider"] as Callable).call())
		var color_callable: Callable = entry["color"] as Callable
		if color_callable.is_valid():
			label.add_theme_color_override("font_color", color_callable.call() as Color)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo or key_event.ctrl_pressed or key_event.alt_pressed:
		return
	var key: int = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
	if key == toggle_key:
		visible = not visible
		get_viewport().set_input_as_handled()
		return
	for entry: Dictionary in _key_bindings:
		if int(entry["key"]) == key:
			(entry["action"] as Callable).call()
			get_viewport().set_input_as_handled()
			return


func _on_tab_pressed(tab_id: String) -> void:
	select_tab(tab_id)
	if collapsed:
		set_collapsed(false)


func _on_tab_gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.double_click and mouse.button_index == MOUSE_BUTTON_LEFT:
		set_collapsed(not collapsed)


func _bottom_edge_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = RibbonTheme.box(RibbonTheme.BG_DEEP, RibbonTheme.ACCENT_DIM, 0, 0, Vector4(0, 0, 0, 0))
	style.border_width_bottom = 2
	return style


func _spacer(width: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.x = width
	return spacer
