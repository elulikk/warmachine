extends CanvasLayer
## Ventana de opciones del juego (video, audio, juego, accesibilidad, controles). Se construye por código.
## Se abre con `SettingsScript.open_window(ctx)` desde el menú principal y desde la pausa.
## Cada cambio se aplica y se guarda al instante (ver `core/settings.gd`). Los cambios de pantalla (modo,
## resolución, monitor) piden confirmación: si no se confirman en 15 s vuelven solos a lo anterior.

const SettingsScript = preload("res://core/settings.gd")

const BG: Color = Color(0.06, 0.08, 0.12, 0.98)
const BORDER: Color = Color(0.25, 0.45, 0.65, 0.95)
const ACCENT: Color = Color(0.35, 0.8, 1.0)
const HINT: Color = Color(0.7, 0.8, 0.9)
const WARN: Color = Color(1.0, 0.75, 0.35)

## Segundos para confirmar un cambio de pantalla antes de que se revierta.
const CONFIRM_SECONDS: float = 15.0
const DISPLAY_KEYS: Array[String] = ["display_mode", "resolution", "monitor"]

var _tabs: TabContainer = null
var _building: bool = false

var _rebind_action: String = ""
var _rebind_slot: String = ""
var _rebind_buttons: Dictionary = {}  ## "acción|casillero" -> Button
var _rebind_hint: Label = null

var _confirm_panel: PanelContainer = null
var _confirm_label: Label = null
var _confirm_keep_button: Button = null
var _confirm_left: float = 0.0
var _confirm_snapshot: Dictionary = {}


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_building = true
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var view: Vector2 = get_viewport().get_visible_rect().size
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(720.0, view.x - 32.0), minf(540.0, view.y - 32.0))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "OPCIONES"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_tabs)
	_tabs.add_child(_scrolled(_build_video()))
	_tabs.add_child(_scrolled(_build_audio()))
	_tabs.add_child(_scrolled(_build_gameplay()))
	_tabs.add_child(_scrolled(_build_accessibility()))
	_tabs.add_child(_scrolled(_build_controls()))
	var titles: Array[String] = ["Video", "Audio", "Juego", "Accesibilidad", "Controles"]
	for i in range(titles.size()):
		_tabs.set_tab_title(i, titles[i])

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var reset: Button = Button.new()
	reset.text = "Restablecer todo"
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var close: Button = Button.new()
	close.text = "Cerrar [ESC]"
	close.custom_minimum_size = Vector2(150.0, 36.0)
	close.pressed.connect(close_window)
	buttons.add_child(close)
	close.grab_focus()

	_build_confirm_panel(dim)
	_building = false


# ------------------------------------------------------------------ helpers de construcción

func _scrolled(page: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = page.name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	return scroll


func _new_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	return page


func _section(page: Control, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ACCENT)
	label.add_theme_font_size_override("font_size", 15)
	page.add_child(label)


func _note(page: Control, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", HINT)
	label.add_theme_font_size_override("font_size", 12)
	page.add_child(label)
	return label


func _row(page: Control, text: String, control: Control) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(250.0, 0.0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	page.add_child(row)


func _option(items: Array[String], selected: int, on_pick: Callable) -> OptionButton:
	var opt: OptionButton = OptionButton.new()
	for item: String in items:
		opt.add_item(item)
	opt.select(clampi(selected, 0, maxi(items.size() - 1, 0)))
	opt.item_selected.connect(func(index: int) -> void:
		if not _building:
			on_pick.call(index))
	return opt


## `live = false` aplica el valor recién al soltar el control (para opciones que cambian el tamaño de la ventana).
func _slider(value: float, min_v: float, max_v: float, step: float, on_change: Callable, as_percent: bool = true, live: bool = true) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0.0, 24.0)
	var readout: Label = Label.new()
	readout.custom_minimum_size = Vector2(54.0, 0.0)
	readout.text = ("%d %%" % int(roundf(value * 100.0))) if as_percent else "%.1f" % value
	var dragging: Array[bool] = [false]
	slider.drag_started.connect(func() -> void: dragging[0] = true)
	slider.drag_ended.connect(func(changed: bool) -> void:
		dragging[0] = false
		if not live and changed and not _building:
			on_change.call(slider.value))
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = ("%d %%" % int(roundf(v * 100.0))) if as_percent else "%.1f" % v
		if _building:
			return
		if live or not dragging[0]:
			on_change.call(v))
	row.add_child(slider)
	row.add_child(readout)
	return row


func _check(value: bool, on_toggle: Callable) -> CheckBox:
	var box: CheckBox = CheckBox.new()
	box.button_pressed = value
	box.toggled.connect(func(pressed: bool) -> void:
		if not _building:
			on_toggle.call(pressed))
	return box


func _put(key: String, value: Variant) -> void:
	SettingsScript.set_value(self, key, value)


# ------------------------------------------------------------------ pestañas

func _build_video() -> Control:
	var page: VBoxContainer = _new_page()
	page.name = "Video"
	_section(page, "Pantalla")
	_row(page, "Modo de pantalla", _option(SettingsScript.DISPLAY_LABELS, SettingsScript.get_int("display_mode"),
		func(i: int) -> void: _put_display("display_mode", i)))
	var screens: Array[String] = ["Automático (el actual)"]
	screens.append_array(SettingsScript.screen_labels())
	_row(page, "Monitor", _option(screens, SettingsScript.get_int("monitor") + 1,
		func(i: int) -> void: _put_display("monitor", i - 1)))
	var resolutions: Array[Vector2i] = SettingsScript.available_resolutions()
	var res_labels: Array[String] = []
	var current: Vector2i = SettingsScript.get_value("resolution") as Vector2i
	var selected: int = 0
	for i in range(resolutions.size()):
		res_labels.append("%d x %d" % [resolutions[i].x, resolutions[i].y])
		if resolutions[i] == current:
			selected = i
	var res_option: OptionButton = _option(res_labels, selected, func(i: int) -> void:
		_put_display("resolution", resolutions[i]))
	res_option.disabled = SettingsScript.get_int("display_mode") != SettingsScript.DISPLAY_WINDOWED
	_row(page, "Resolución (modo ventana)", res_option)
	_row(page, "Sincronización vertical", _option(SettingsScript.VSYNC_LABELS, SettingsScript.get_int("vsync"),
		func(i: int) -> void: _put("vsync", i)))
	var fps_labels: Array[String] = []
	var fps_selected: int = 0
	for i in range(SettingsScript.FPS_VALUES.size()):
		var v: int = SettingsScript.FPS_VALUES[i]
		fps_labels.append("Sin límite" if v == 0 else "%d FPS" % v)
		if v == SettingsScript.get_int("max_fps"):
			fps_selected = i
	_row(page, "FPS máximos", _option(fps_labels, fps_selected, func(i: int) -> void:
		_put("max_fps", SettingsScript.FPS_VALUES[i])))
	_row(page, "Contador de FPS", _check(SettingsScript.get_bool("show_fps"), func(on: bool) -> void:
		_put("show_fps", on)))

	_section(page, "Calidad")
	_row(page, "Calidad gráfica", _option(SettingsScript.QUALITY_LABELS, SettingsScript.get_int("quality"),
		func(i: int) -> void:
			_put("quality", i)
			_rebuild()))
	if SettingsScript.msaa_supported():
		_row(page, "Suavizado de bordes (MSAA 2D)", _option(SettingsScript.MSAA_LABELS, SettingsScript.get_int("msaa"),
			func(i: int) -> void:
				_put("msaa", i)
				_rebuild()))
	_row(page, "Densidad de partículas", _slider(SettingsScript.get_float("particles"), 0.25, 1.0, 0.05,
		func(v: float) -> void: _put("particles", v)))
	_row(page, "Estilo del fuego y del ácido", _option(["Sprites (liviano)", "Partículas", "Shaders"] as Array[String],
		SettingsScript.get_int("fire_style"), func(i: int) -> void: _put("fire_style", i)))
	_row(page, "Enemigos lejanos como sprite", _check(SettingsScript.get_bool("enemy_lod"),
		func(on: bool) -> void: _put("enemy_lod", on)))
	for entry: Array in [["fx_vignette", "Viñeta"], ["fx_grain", "Grano de película"], ["fx_bloom", "Resplandor (bloom)"]]:
		var key: String = str(entry[0])
		_row(page, str(entry[1]), _check(SettingsScript.get_bool(key), func(on: bool) -> void:
			_put(key, on)
			_rebuild()))
	_row(page, "Fondos de paralaje (capas)", _check(SettingsScript.get_bool("parallax_bg"), func(on: bool) -> void:
		_put("parallax_bg", on)))
	_note(page, "Baja: sin efectos y la mitad de partículas. Media: viñeta. Alta: viñeta y grano. Ultra: además resplandor.")
	return page


func _build_audio() -> Control:
	var page: VBoxContainer = _new_page()
	page.name = "Audio"
	_row(page, "Volumen general", _slider(SettingsScript.get_float("master_volume"), 0.0, 1.0, 0.05,
		func(v: float) -> void: _put("master_volume", v)))
	_row(page, "Música", _slider(SettingsScript.get_float("music_volume"), 0.0, 1.0, 0.05,
		func(v: float) -> void: _put("music_volume", v)))
	_row(page, "Efectos de sonido", _slider(SettingsScript.get_float("sfx_volume"), 0.0, 1.0, 0.05,
		func(v: float) -> void: _put("sfx_volume", v)))
	_row(page, "Silenciar al perder el foco", _check(SettingsScript.get_bool("mute_unfocused"), func(on: bool) -> void:
		_put("mute_unfocused", on)))
	return page


func _build_gameplay() -> Control:
	var page: VBoxContainer = _new_page()
	page.name = "Juego"
	_row(page, "Dificultad", _option(SettingsScript.DIFFICULTY_LABELS, SettingsScript.get_int("difficulty"),
		func(i: int) -> void:
			_put("difficulty", i)
			_rebuild()))
	var preset: Dictionary = SettingsScript.DIFFICULTY_PRESETS[clampi(SettingsScript.get_int("difficulty"), 0, 3)]
	_note(page, "Daño de los enemigos x%.2f, vida de los enemigos x%.2f. Los enemigos que ya están en el nivel conservan su vida; los nuevos aparecen con la dificultad elegida." % [
		float(preset["enemy_damage"]), float(preset["enemy_health"])])
	_row(page, "Intensidad del temblor de cámara", _slider(SettingsScript.get_float("screen_shake"), 0.0, 1.5, 0.1,
		func(v: float) -> void: _put("screen_shake", v)))
	_row(page, "Números de daño", _check(SettingsScript.get_bool("damage_numbers"), func(on: bool) -> void:
		_put("damage_numbers", on)))
	return page


func _build_accessibility() -> Control:
	var page: VBoxContainer = _new_page()
	page.name = "Accesibilidad"
	_section(page, "Interfaz")
	_row(page, "Escala de la interfaz y el texto", _slider(SettingsScript.ui_scale(), SettingsScript.UI_SCALE_MIN,
		SettingsScript.UI_SCALE_MAX, 0.05, func(v: float) -> void:
			_put("ui_scale", v)
			_rebuild(), true, false))
	_note(page, "Agranda menús, HUD y texto. La cámara compensa: se ve la misma porción del nivel.")
	_section(page, "Color")
	_row(page, "Filtro para daltonismo", _option(SettingsScript.COLORBLIND_LABELS, SettingsScript.get_int("colorblind"),
		func(i: int) -> void: _put("colorblind", i)))
	_row(page, "Intensidad del filtro", _slider(SettingsScript.get_float("colorblind_strength"), 0.0, 1.0, 0.05,
		func(v: float) -> void: _put("colorblind_strength", v)))
	_note(page, "Corrige toda la imagen (juego e interfaz) para separar los colores que se confunden: rarezas, vida, escudos y estados.")
	_section(page, "Movimiento y destellos")
	_row(page, "Reducir destellos", _check(SettingsScript.get_bool("reduce_flashes"), func(on: bool) -> void:
		_put("reduce_flashes", on)))
	_row(page, "Congelar al impactar (hit stop)", _check(SettingsScript.get_bool("hit_stop"), func(on: bool) -> void:
		_put("hit_stop", on)))
	_row(page, "Temblor de cámara", _slider(SettingsScript.get_float("screen_shake"), 0.0, 1.5, 0.1,
		func(v: float) -> void: _put("screen_shake", v)))
	_note(page, "Con el temblor en 0 % la cámara no se sacude. Reducir destellos quita los fogonazos blancos de muertes e impactos.")
	return page


func _build_controls() -> Control:
	var page: VBoxContainer = _new_page()
	page.name = "Controles"
	_rebind_hint = _note(page, "Hacé clic en un casillero y presioná la tecla, el botón del ratón o el del mando. ESC cancela. Si otra acción ya lo usaba, intercambian.")
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	for entry: Array in [["Acción", 210.0], ["Teclado / ratón", 170.0], ["Mando", 170.0]]:
		var label: Label = Label.new()
		label.text = str(entry[0])
		label.custom_minimum_size = Vector2(float(entry[1]), 0.0)
		label.add_theme_color_override("font_color", ACCENT)
		header.add_child(label)
	page.add_child(header)
	_rebind_buttons.clear()
	for action: String in SettingsScript.REMAPPABLE.keys():
		if not InputMap.has_action(action):
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label: Label = Label.new()
		name_label.text = str(SettingsScript.REMAPPABLE[action])
		name_label.custom_minimum_size = Vector2(210.0, 0.0)
		row.add_child(name_label)
		for slot: String in [SettingsScript.SLOT_PC, SettingsScript.SLOT_JOY]:
			var button: Button = Button.new()
			button.custom_minimum_size = Vector2(170.0, 28.0)
			button.text = SettingsScript.binding_label(action, slot)
			button.pressed.connect(_start_rebind.bind(action, slot))
			_rebind_buttons["%s|%s" % [action, slot]] = button
			row.add_child(button)
		var restore: Button = Button.new()
		restore.text = "↺"
		restore.tooltip_text = "Volver a la asignación de fábrica"
		restore.custom_minimum_size = Vector2(32.0, 28.0)
		restore.pressed.connect(func() -> void:
			SettingsScript.reset_binding(action)
			_refresh_bindings())
		row.add_child(restore)
		page.add_child(row)
	return page


# ------------------------------------------------------------------ pantalla con confirmación

## Aplica un cambio de pantalla y pide confirmarlo; si no se confirma en 15 s vuelve a lo anterior.
func _put_display(key: String, value: Variant) -> void:
	if _confirm_snapshot.is_empty():
		for k: String in DISPLAY_KEYS:
			_confirm_snapshot[k] = SettingsScript.get_value(k)
	_put(key, value)
	_rebuild_keep_confirm()


func _build_confirm_panel(parent: Control) -> void:
	_confirm_panel = PanelContainer.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.05, 0.98)
	style.border_color = WARN
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	_confirm_panel.add_theme_stylebox_override("panel", style)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	center.add_child(_confirm_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_confirm_panel.add_child(box)
	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.add_theme_color_override("font_color", WARN)
	box.add_child(_confirm_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var keep: Button = Button.new()
	keep.text = "Mantener"
	keep.custom_minimum_size = Vector2(140.0, 34.0)
	keep.pressed.connect(_confirm_keep)
	row.add_child(keep)
	_confirm_keep_button = keep
	var revert: Button = Button.new()
	revert.text = "Volver atrás"
	revert.custom_minimum_size = Vector2(140.0, 34.0)
	revert.pressed.connect(_confirm_revert)
	row.add_child(revert)
	_confirm_panel.visible = false


func _rebuild_keep_confirm() -> void:
	_confirm_left = CONFIRM_SECONDS
	await _rebuild()
	_show_confirm()


func _show_confirm() -> void:
	if _confirm_panel == null or _confirm_snapshot.is_empty():
		return
	_confirm_panel.visible = true
	_update_confirm_text()
	if _confirm_keep_button != null:
		_confirm_keep_button.grab_focus()


func _update_confirm_text() -> void:
	if _confirm_label != null:
		_confirm_label.text = "¿Mantener esta configuración de pantalla?\nSe vuelve a la anterior en %d s." % int(ceilf(_confirm_left))


func _process(delta: float) -> void:
	if _confirm_snapshot.is_empty() or _confirm_panel == null or not _confirm_panel.visible:
		return
	_confirm_left -= delta / maxf(Engine.time_scale, 0.001)
	_update_confirm_text()
	if _confirm_left <= 0.0:
		_confirm_revert()


func _confirm_keep() -> void:
	_confirm_snapshot.clear()
	if _confirm_panel != null:
		_confirm_panel.visible = false


func _confirm_revert() -> void:
	var snapshot: Dictionary = _confirm_snapshot.duplicate()
	_confirm_snapshot.clear()
	for k: String in snapshot.keys():
		SettingsScript.values[k] = snapshot[k]
	SettingsScript.apply_all(self)
	SettingsScript.save()
	_rebuild()


# ------------------------------------------------------------------ comportamiento

## Reconstruye la ventana (cuando un preajuste cambia otras opciones) conservando la pestaña actual.
func _rebuild() -> void:
	var tab: int = _tabs.current_tab if _tabs != null else 0
	for child: Node in get_children():
		child.queue_free()
	_rebind_action = ""
	await get_tree().process_frame
	_build()
	_tabs.current_tab = tab


func _refresh_bindings() -> void:
	for id: String in _rebind_buttons.keys():
		var parts: PackedStringArray = id.split("|")
		var button: Button = _rebind_buttons[id] as Button
		if button != null and is_instance_valid(button):
			button.text = SettingsScript.binding_label(parts[0], parts[1])


func _start_rebind(action: String, slot: String) -> void:
	_refresh_bindings()
	_rebind_action = action
	_rebind_slot = slot
	var button: Button = _rebind_buttons.get("%s|%s" % [action, slot]) as Button
	if button != null:
		button.text = "Presioná una tecla..." if slot == SettingsScript.SLOT_PC else "Presioná un botón..."


## Captura en _input (antes que la interfaz) para poder asignar también clics del ratón.
func _input(event: InputEvent) -> void:
	if _rebind_action.is_empty():
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_ESCAPE:
		_rebind_action = ""
		_refresh_bindings()
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed() or event.is_echo():
		return
	var desc: Dictionary = SettingsScript.descriptor_from_event(event)
	if desc.is_empty() or SettingsScript.slot_of(desc) != _rebind_slot:
		if event is InputEventMouseButton or event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	var action: String = _rebind_action
	_rebind_action = ""
	var conflict: String = SettingsScript.rebind_event(self, action, desc)
	_refresh_bindings()
	if _rebind_hint != null:
		if conflict.is_empty():
			_rebind_hint.text = "«%s» ahora usa %s." % [str(SettingsScript.REMAPPABLE[action]), SettingsScript.describe(desc)]
			_rebind_hint.add_theme_color_override("font_color", HINT)
		else:
			_rebind_hint.text = "Conflicto: «%s» ya usaba %s. Se intercambiaron las asignaciones." % [
				str(SettingsScript.REMAPPABLE[conflict]), SettingsScript.describe(desc)]
			_rebind_hint.add_theme_color_override("font_color", WARN)
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_ESCAPE:
		if _confirm_panel != null and _confirm_panel.visible:
			_confirm_revert()
		else:
			close_window()
		get_viewport().set_input_as_handled()


func _on_reset() -> void:
	SettingsScript.reset_all(self)
	_confirm_snapshot.clear()
	_rebuild()


func close_window() -> void:
	# Cerrar sin confirmar un cambio de pantalla lo mantiene (el jugador ya lo vio funcionando)
	_confirm_snapshot.clear()
	queue_free()
