class_name MainMenu
extends Control
## Menú principal de WARMACHINE, armado por código sobre la escena (que solo trae el SaveManager).
## Fondo de la ciudad con lluvia y zoom lento, columna de opciones a la izquierda (Continuar, Nueva partida,
## Cargar partida, Opciones, Banco de pruebas, Salir) y selector de las 3 ranuras de guardado que reemplaza
## a la columna. Ventanas modales para el nombre del operador y las confirmaciones (borrar / sobrescribir).

const ArtScript = preload("res://core/art/art.gd")
const SteamSkin = preload("res://ui/components/steam_skin.gd")
const SettingsScript = preload("res://core/settings.gd")
const LoadingTips = preload("res://ui/loading_tips.gd")

const FIRST_SECTOR: String = "res://levels/chapter_1/level_1_01.tscn"
const HUB_SCENE: String = "res://scenes/hub/base_camp.tscn"
const FIRST_LEVEL_SCENE: String = "res://levels/chapter_1/level_1_01.tscn"
const SANDBOX_SCENE: String = "res://core/test_level.tscn"
const STRESS_SCENE: String = "res://scenes/hub/stress_room.tscn"
const CINEMATIC_BENCH_SCENE: String = "res://scenes/hub/cinematic_bench.tscn"
const MAX_NAME_LENGTH: int = 14
const LevelSkinScript = preload("res://levels/level_skin.gd")
## Fondo del menú cuando no hay partidas (o no se reconoce dónde estaba la última).
const DEFAULT_BACKDROP: String = "res://assets/art/bg/city.jpg"

enum SlotMode { NEW_GAME, LOAD_GAME }

var _backdrop: TextureRect = null
var _rain: CPUParticles2D = null
var _menu_box: VBoxContainer = null
var _slots_box: VBoxContainer = null
var _slots_title: Label = null
var _slot_list: VBoxContainer = null
var _modal: Control = null
var _modal_input: LineEdit = null
var _modal_error: Label = null
var _mode: SlotMode = SlotMode.LOAD_GAME
var _continue_slot: int = -1
var _time: float = 0.0
var _busy: bool = false
var _last_focus: Control = null


func _ready() -> void:
	get_tree().paused = false
	GameFeel.music_set_base(self, &"menu")
	if GameManager != null and "current_state" in GameManager:
		GameManager.current_state = 0 # PLAYING
	_build()
	resized.connect(_on_resized)
	_on_resized()
	_show_menu(false)
	# Fundido desde negro
	var curtain: ColorRect = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	var tw: Tween = create_tween()
	tw.tween_property(curtain, "modulate:a", 0.0, 0.7)
	tw.tween_callback(curtain.queue_free)


func _process(delta: float) -> void:
	_time += delta
	# Zoom y paneo lentos del fondo (ida y vuelta)
	if _backdrop != null:
		var t: float = 0.5 - 0.5 * cos(_time * 0.05)
		_backdrop.pivot_offset = _backdrop.size * Vector2(0.35 + 0.3 * t, 0.5)
		var zoom: float = 1.04 + 0.06 * t
		_backdrop.scale = Vector2(zoom, zoom)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _modal != null:
		_close_modal()
	elif _slots_box.visible:
		_show_menu(true)
	else:
		return
	get_viewport().set_input_as_handled()


func _get_save_manager() -> SaveManager:
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		return sm
	return get_node_or_null("SaveManager") as SaveManager


# ==============================================================================
# Construcción
# ==============================================================================

func _build() -> void:
	var base: ColorRect = ColorRect.new()
	base.color = Color(0.03, 0.03, 0.05)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	_backdrop = TextureRect.new()
	_backdrop.texture = _menu_backdrop()
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.modulate = Color(0.68, 0.64, 0.7)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_rain = _make_rain()
	add_child(_rain)

	# Sombra a la izquierda (columna del menú) y abajo
	add_child(_gradient_rect(Vector2(0, 0), Vector2(1, 0), [0.0, 0.42, 0.75], [0.92, 0.7, 0.0]))
	add_child(_gradient_rect(Vector2(0, 0), Vector2(0, 1), [0.0, 0.7, 1.0], [0.0, 0.0, 0.7]))

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 84)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	var title: Label = _label("WARMACHINE", 68, SteamSkin.COLOR_TITLE)
	title.add_theme_font_override("font", SteamSkin.title_font())
	title.add_theme_color_override("font_outline_color", SteamSkin.COLOR_OUTLINE)
	title.add_theme_constant_override("outline_size", 10)
	column.add_child(title)
	column.add_child(_label("NADIE VIAJA.", 15, SteamSkin.COLOR_GOLD))
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(SteamSkin.COLOR_COPPER, 0.85)
	rule.custom_minimum_size = Vector2(260.0, 2.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(rule)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 14.0)
	column.add_child(gap)

	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 2)
	_menu_box.custom_minimum_size = Vector2(420.0, 0.0)
	column.add_child(_menu_box)

	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 10)
	_slots_box.custom_minimum_size = Vector2(560.0, 0.0)
	_slots_box.visible = false
	column.add_child(_slots_box)
	_slots_title = _label("", 22, SteamSkin.COLOR_GOLD)
	_slots_title.add_theme_font_override("font", SteamSkin.title_font())
	_slots_box.add_child(_slots_title)
	_slot_list = VBoxContainer.new()
	_slot_list.add_theme_constant_override("separation", 8)
	_slots_box.add_child(_slot_list)
	var back: Button = _menu_button("« VOLVER", 17)
	back.pressed.connect(_show_menu.bind(true))
	_slots_box.add_child(back)

	# Pie: frase del mundo y versión abajo a la derecha, controles abajo a la izquierda
	var quote: Label = _label("«%s»" % LoadingTips.LORE[randi() % LoadingTips.LORE.size()], 13, Color(0.85, 0.8, 0.72, 0.75))
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quote.custom_minimum_size = Vector2(380.0, 0.0)
	var version: Label = _label("v%s" % str(ProjectSettings.get_setting("application/config/version", "dev")), 12, Color(0.65, 0.6, 0.55, 0.8))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var corner: VBoxContainer = VBoxContainer.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_theme_constant_override("separation", 8)
	corner.add_child(quote)
	corner.add_child(version)
	add_child(corner)
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var keys: Label = _label("[WASD / Espacio] Moverse   [Ratón] Disparar   [I] Mochila   [E] Interactuar   [Esc] Volver", 12, Color(0.7, 0.66, 0.6, 0.7))
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)
	keys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(keys)


func _rebuild_menu_buttons() -> void:
	for child: Node in _menu_box.get_children():
		child.queue_free()
	var latest: Dictionary = _latest_save()
	_continue_slot = int(latest.get("slot_id", -1)) if bool(latest.get("exists", false)) else -1
	if _continue_slot > 0:
		var btn_continue: Button = _menu_button("CONTINUAR")
		btn_continue.pressed.connect(_on_continue_pressed)
		_menu_box.add_child(btn_continue)
		var info: Label = _label("%s · Nivel %d · %s" % [
				str(latest.get("name", "OPERADOR")).to_upper(), int(latest.get("level", 1)),
				_format_date(str(latest.get("timestamp", "")))], 13, SteamSkin.COLOR_TEXT_DIM)
		var pad: MarginContainer = MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 22)
		pad.add_theme_constant_override("margin_bottom", 6)
		pad.add_child(info)
		_menu_box.add_child(pad)
	var btn_new: Button = _menu_button("NUEVA PARTIDA")
	btn_new.pressed.connect(_open_slots.bind(SlotMode.NEW_GAME))
	_menu_box.add_child(btn_new)
	var btn_load: Button = _menu_button("CARGAR PARTIDA")
	btn_load.pressed.connect(_open_slots.bind(SlotMode.LOAD_GAME))
	btn_load.disabled = _continue_slot < 0
	_menu_box.add_child(btn_load)
	var btn_options: Button = _menu_button("OPCIONES")
	btn_options.pressed.connect(func() -> void: SettingsScript.open_window(self))
	_menu_box.add_child(btn_options)
	var btn_sandbox: Button = _menu_button("BANCO DE PRUEBAS", 17)
	btn_sandbox.pressed.connect(_on_sandbox_pressed)
	_menu_box.add_child(btn_sandbox)
	var btn_stress: Button = _menu_button("SALA DE ESTRÉS", 17)
	btn_stress.pressed.connect(_open_test_scene.bind(STRESS_SCENE, "Sala de Estrés"))
	_menu_box.add_child(btn_stress)
	var btn_cine: Button = _menu_button("BANCO DE CINEMÁTICAS", 17)
	btn_cine.pressed.connect(_open_test_scene.bind(CINEMATIC_BENCH_SCENE, "Banco de Cinemáticas"))
	_menu_box.add_child(btn_cine)
	var btn_quit: Button = _menu_button("SALIR", 17)
	btn_quit.pressed.connect(func() -> void: get_tree().quit())
	_menu_box.add_child(btn_quit)


func _rebuild_slot_cards() -> void:
	for child: Node in _slot_list.get_children():
		child.queue_free()
	var sm: SaveManager = _get_save_manager()
	if sm == null:
		return
	for slot_id: int in range(1, SaveManager.MAX_SLOTS + 1):
		_slot_list.add_child(_slot_card(sm.get_slot_preview(slot_id)))


func _slot_card(preview: Dictionary) -> PanelContainer:
	var slot_id: int = int(preview.get("slot_id", 1))
	var exists: bool = bool(preview.get("exists", false))
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", SteamSkin.slot_style())
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	if exists:
		info.add_child(_label("RANURA %d · %s" % [slot_id, str(preview.get("name", "OPERADOR")).to_upper()], 17, SteamSkin.COLOR_TITLE))
		info.add_child(_label("Nivel %d   ·   %d monedas   ·   %d sectores abiertos" % [
				int(preview.get("level", 1)), int(preview.get("coins", 0)), int(preview.get("sectors", 1))], 13, SteamSkin.COLOR_TEXT))
		info.add_child(_label("Guardado: %s" % _format_date(str(preview.get("timestamp", ""))), 12, SteamSkin.COLOR_TEXT_DIM))
	else:
		info.add_child(_label("RANURA %d · VACÍA" % slot_id, 17, SteamSkin.COLOR_TEXT_DIM))
		info.add_child(_label("Sin partida guardada", 13, Color(SteamSkin.COLOR_TEXT_DIM, 0.7)))

	if _mode == SlotMode.LOAD_GAME:
		if exists:
			var play: Button = _card_button("JUGAR", "copper")
			play.pressed.connect(_load_slot.bind(slot_id))
			row.add_child(play)
			var del: Button = _card_button("BORRAR", "dark")
			del.pressed.connect(_ask_delete.bind(slot_id, str(preview.get("name", "OPERADOR"))))
			row.add_child(del)
	else:
		if exists:
			var over: Button = _card_button("SOBRESCRIBIR", "dark")
			over.pressed.connect(_ask_overwrite.bind(slot_id, str(preview.get("name", "OPERADOR"))))
			row.add_child(over)
		else:
			var create: Button = _card_button("CREAR", "copper")
			create.pressed.connect(_ask_name.bind(slot_id))
			row.add_child(create)
	return card


# ==============================================================================
# Navegación
# ==============================================================================

func _show_menu(animated: bool) -> void:
	_rebuild_menu_buttons()
	_slots_box.visible = false
	_menu_box.visible = true
	_slide_in(_menu_box, animated)
	await get_tree().process_frame
	_focus_first(_menu_box)


func _open_slots(mode: SlotMode) -> void:
	_mode = mode
	_slots_title.text = "NUEVA PARTIDA · ELEGÍ UNA RANURA" if mode == SlotMode.NEW_GAME else "CARGAR PARTIDA"
	_rebuild_slot_cards()
	_menu_box.visible = false
	_slots_box.visible = true
	_slide_in(_slots_box, true)
	await get_tree().process_frame
	_focus_first(_slot_list)
	if get_viewport().gui_get_focus_owner() == null:
		_focus_first(_slots_box)


func _slide_in(node: Control, animated: bool) -> void:
	if not animated:
		node.modulate.a = 1.0
		return
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.2)


func _focus_first(root: Node) -> void:
	for child: Node in root.get_children():
		if child is Button and not (child as Button).disabled and (child as Control).is_visible_in_tree():
			(child as Button).grab_focus()
			return
		if child.get_child_count() > 0:
			var before: Control = get_viewport().gui_get_focus_owner()
			_focus_first(child)
			if get_viewport().gui_get_focus_owner() != before:
				return


# ==============================================================================
# Acciones
# ==============================================================================

func _on_continue_pressed() -> void:
	if _continue_slot > 0:
		_load_slot(_continue_slot)


func _load_slot(slot_id: int) -> void:
	var sm: SaveManager = _get_save_manager()
	if sm == null or _busy:
		return
	_busy = true
	sm.load_from_disk(slot_id)
	GameFeel.sfx(self, &"gate_open")
	# Si quedó un checkpoint de un sector, se vuelve ahí; si no, al campamento
	if not sm.resume_level_path.is_empty() and ResourceLoader.exists(sm.resume_level_path):
		sm.resume_pending = true
		print("[MainMenu] Slot %d cargado. Volviendo al último checkpoint: %s" % [slot_id, sm.resume_level_path])
		GameManager.change_scene(sm.resume_level_path)
		return
	print("[MainMenu] Slot %d cargado. Entrando a Base Camp." % slot_id)
	GameManager.change_scene(HUB_SCENE)


func _start_new_game(slot_id: int, char_name: String) -> void:
	var sm: SaveManager = _get_save_manager()
	if sm == null or _busy:
		return
	_busy = true
	sm.create_character(slot_id, char_name)
	# Partida nueva: directo al sector 1-01 (el campamento queda para las partidas guardadas)
	print("[MainMenu] Personaje '%s' creado en Slot %d. Entrando al sector 1-01." % [char_name, slot_id])
	GameFeel.sfx(self, &"gate_open")
	GameManager.change_scene(FIRST_LEVEL_SCENE)


## Salas de prueba sin partida (no guardan nada): Sala de Estrés y Banco de Cinemáticas.
func _open_test_scene(path: String, title: String) -> void:
	if _busy:
		return
	_busy = true
	print("[MainMenu] Cargando %s: %s" % [title, path])
	GameManager.change_scene(path)


func _on_sandbox_pressed() -> void:
	if _busy:
		return
	_busy = true
	SaveManager.clear_world_flags()
	print("[MainMenu] Cargando Banco de Pruebas (Modo Fruta): %s" % SANDBOX_SCENE)
	GameManager.change_scene(SANDBOX_SCENE)


func _ask_name(slot_id: int) -> void:
	_open_modal("NUEVO OPERADOR", "Nombre del operador para la ranura %d:" % slot_id, true,
			"COMENZAR", "copper", func() -> void:
				var char_name: String = _modal_input.text.strip_edges()
				if char_name.is_empty():
					char_name = _default_game_name()
				_close_modal()
				_start_new_game(slot_id, char_name))


## "Partida sin nombre N", con el primer N que no usa ninguna otra ranura.
func _default_game_name() -> String:
	var sm: SaveManager = _get_save_manager()
	var used: Array[String] = []
	if sm != null:
		for slot: int in range(1, SaveManager.MAX_SLOTS + 1):
			var preview: Dictionary = sm.get_slot_preview(slot)
			if bool(preview.get("exists", false)):
				used.append(str(preview.get("name", "")).to_lower())
	var n: int = 1
	while used.has("partida sin nombre %d" % n):
		n += 1
	return "Partida sin nombre %d" % n


func _ask_overwrite(slot_id: int, char_name: String) -> void:
	_open_modal("SOBRESCRIBIR PARTIDA",
			"La ranura %d tiene la partida de %s.\nSi empezás una nueva acá, se pierden sus armas, monedas y baúl para siempre." % [slot_id, char_name.to_upper()],
			false, "SOBRESCRIBIR", "dark", func() -> void:
				var sm: SaveManager = _get_save_manager()
				if sm != null:
					sm.delete_character(slot_id)
				_close_modal()
				_ask_name(slot_id))


func _ask_delete(slot_id: int, char_name: String) -> void:
	_open_modal("BORRAR PARTIDA",
			"¿Borrar a %s?\nSe pierden todas sus armas, monedas y baúl de forma permanente." % char_name.to_upper(),
			false, "BORRAR", "dark", func() -> void:
				var sm: SaveManager = _get_save_manager()
				if sm != null:
					sm.delete_character(slot_id)
				_close_modal()
				if _latest_save().is_empty():
					_show_menu(true)
				else:
					_rebuild_slot_cards()
					await get_tree().process_frame
					_focus_first(_slot_list))


# ==============================================================================
# Ventana modal
# ==============================================================================

func _open_modal(title: String, message: String, with_input: bool, confirm_text: String, confirm_kind: String, on_confirm: Callable) -> void:
	_close_modal()
	_last_focus = get_viewport().gui_get_focus_owner()
	_modal = ColorRect.new()
	(_modal as ColorRect).color = Color(0.0, 0.0, 0.0, 0.72)
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SteamSkin.window_style())
	panel.custom_minimum_size = Vector2(440.0, 0.0)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var head: Label = _label(title, 22, SteamSkin.COLOR_TITLE)
	head.add_theme_font_override("font", SteamSkin.title_font())
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var body: Label = _label(message, 14, SteamSkin.COLOR_TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	_modal_input = null
	_modal_error = _label("", 12, Color(1.0, 0.45, 0.4))
	_modal_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if with_input:
		_modal_input = LineEdit.new()
		_modal_input.max_length = MAX_NAME_LENGTH
		_modal_input.placeholder_text = "Máximo %d letras (vacío = Partida sin nombre)" % MAX_NAME_LENGTH
		_modal_input.custom_minimum_size = Vector2(0.0, 38.0)
		_modal_input.add_theme_font_size_override("font_size", 16)
		_modal_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_modal_input.add_theme_stylebox_override("normal", SteamSkin.inset_style())
		_modal_input.add_theme_stylebox_override("focus", SteamSkin.inset_style())
		_modal_input.add_theme_color_override("font_color", SteamSkin.COLOR_TEXT)
		_modal_input.text_submitted.connect(func(_t: String) -> void: on_confirm.call())
		box.add_child(_modal_input)
	box.add_child(_modal_error)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var confirm: Button = _card_button(confirm_text, confirm_kind)
	confirm.pressed.connect(on_confirm)
	buttons.add_child(confirm)
	var cancel: Button = _card_button("CANCELAR", "plate")
	cancel.pressed.connect(_close_modal)
	buttons.add_child(cancel)
	_modal.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(_modal, "modulate:a", 1.0, 0.15)
	if _modal_input != null:
		_modal_input.grab_focus()
	else:
		cancel.grab_focus()


func _close_modal() -> void:
	if _modal == null:
		return
	_modal.queue_free()
	_modal = null
	_modal_input = null
	_modal_error = null
	if _last_focus != null and is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree():
		_last_focus.grab_focus()


# ==============================================================================
# Piezas
# ==============================================================================

## Opción de la columna: texto grande sin caja; al pasar o enfocar aparece la placa con el borde dorado.
func _menu_button(text: String, font_size: int = 22) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	# Las opciones chicas (salas de prueba, salir) van más juntas para que entre la columna entera
	button.custom_minimum_size = Vector2(0.0, (30.0 if font_size >= 20 else 22.0) + font_size)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_font_override("font", SteamSkin.title_font())
	button.add_theme_color_override("font_color", SteamSkin.COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", SteamSkin.COLOR_GOLD)
	button.add_theme_color_override("font_focus_color", SteamSkin.COLOR_GOLD)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.8))
	button.add_theme_color_override("font_disabled_color", Color(SteamSkin.COLOR_TEXT_DIM, 0.4))
	button.add_theme_color_override("font_outline_color", SteamSkin.COLOR_OUTLINE)
	button.add_theme_constant_override("outline_size", 4)
	var idle: StyleBoxFlat = _menu_box_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	var lit: StyleBoxFlat = _menu_box_style(Color(0.55, 0.32, 0.16, 0.38), SteamSkin.COLOR_GOLD)
	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("disabled", idle)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("focus", lit)
	button.add_theme_stylebox_override("pressed", _menu_box_style(Color(0.35, 0.2, 0.1, 0.6), SteamSkin.COLOR_GOLD))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			button.grab_focus())
	button.focus_entered.connect(func() -> void: GameFeel.sfx(self, &"reload_shell", Vector2.INF, -8.0, 1.4))
	return button


func _menu_box_style(bg: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_left = 4
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	box.corner_radius_top_right = 3
	box.corner_radius_bottom_right = 3
	return box


## Botón de placa para las tarjetas de ranura y los modales.
func _card_button(text: String, kind: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(118.0, 40.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", SteamSkin.COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", SteamSkin.COLOR_GOLD)
	button.add_theme_color_override("font_focus_color", SteamSkin.COLOR_GOLD)
	button.add_theme_stylebox_override("normal", SteamSkin.button_style(kind, "normal"))
	button.add_theme_stylebox_override("hover", SteamSkin.button_style(kind, "hover"))
	button.add_theme_stylebox_override("focus", SteamSkin.button_style(kind, "hover"))
	button.add_theme_stylebox_override("pressed", SteamSkin.button_style(kind, "pressed"))
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(func() -> void: GameFeel.sfx(self, &"reload_shell", Vector2.INF, -8.0, 1.4))
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Degradé a negro de pantalla completa: dirección `from`→`to` (0..1), con sus offsets y opacidades.
func _gradient_rect(from: Vector2, to: Vector2, offsets: Array, alphas: Array) -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	var colors: PackedColorArray = PackedColorArray()
	for a: Variant in alphas:
		colors.append(Color(0.0, 0.0, 0.0, float(a)))
	gradient.colors = colors
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 256
	tex.height = 256
	var rect: TextureRect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Lluvia de Ciudad de Jano: gotas finas y algo inclinadas, en CPU (barato y sin compilar shaders).
func _make_rain() -> CPUParticles2D:
	var drop: GradientTexture2D = GradientTexture2D.new()
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([Color(0.75, 0.82, 0.95, 0.0), Color(0.75, 0.82, 0.95, 0.55)])
	drop.gradient = g
	drop.fill_from = Vector2(0, 0)
	drop.fill_to = Vector2(0, 1)
	drop.width = 2
	drop.height = 22
	var rain: CPUParticles2D = CPUParticles2D.new()
	rain.texture = drop
	rain.amount = 160
	rain.lifetime = 1.1
	rain.preprocess = 1.1
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.direction = Vector2(-0.18, 1.0)
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 900.0
	rain.initial_velocity_max = 1150.0
	rain.particle_flag_align_y = true
	rain.scale_amount_min = 0.6
	rain.scale_amount_max = 1.1
	rain.modulate = Color(1, 1, 1, 0.6)
	var amount: float = SettingsScript.particle_scale()
	rain.amount = maxi(20, int(160 * amount))
	return rain


func _on_resized() -> void:
	if _rain == null:
		return
	var view: Vector2 = size
	_rain.position = Vector2(view.x * 0.55, -40.0)
	_rain.emission_rect_extents = Vector2(view.x * 0.65, 10.0)


# ==============================================================================
# Datos de guardado
# ==============================================================================

## Fondo del menú: el del mundo o sector donde estaba la partida más reciente; sin partidas, la ciudad.
func _menu_backdrop() -> Texture2D:
	var where: String = str(_latest_save().get("last_scene", ""))
	var path: String = LevelSkinScript.backdrop_for_scene(where) if not where.is_empty() else ""
	var tex: Texture2D = ArtScript.tex(path) if not path.is_empty() else null
	return tex if tex != null else ArtScript.tex(DEFAULT_BACKDROP)


## Vista previa de la partida guardada más reciente, o {} si no hay ninguna.
func _latest_save() -> Dictionary:
	var sm: SaveManager = _get_save_manager()
	if sm == null:
		return {}
	var best: Dictionary = {}
	for slot_id: int in range(1, SaveManager.MAX_SLOTS + 1):
		var preview: Dictionary = sm.get_slot_preview(slot_id)
		if not bool(preview.get("exists", false)):
			continue
		if best.is_empty() or str(preview.get("timestamp", "")) > str(best.get("timestamp", "")):
			best = preview
	return best


## "2026-10-17 21:05:33" → "17/10/2026 21:05".
func _format_date(stamp: String) -> String:
	var parts: PackedStringArray = stamp.replace("T", " ").split(" ")
	if parts.size() < 2:
		return stamp
	var date: PackedStringArray = parts[0].split("-")
	if date.size() != 3:
		return stamp
	return "%s/%s/%s %s" % [date[2], date[1], date[0], parts[1].left(5)]
