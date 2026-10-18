extends Node
## Gestor Central de Partida (Autoload / Controlador Global).
## Administra los estados de juego (PLAYING, GAME_OVER, VICTORY),
## la detección de derrota y reaparición en checkpoints,
## la victoria al completar sectores y el menú de pausa / retorno al menú principal.

const SettingsScript = preload("res://core/settings.gd")
const SceneLoaderScript = preload("res://core/scene_loader.gd")
const ErrorLoggerScript = preload("res://core/error_logger.gd")
const PerfMonitorScript = preload("res://core/debug/perf_monitor.gd")

enum GameState { PLAYING, GAME_OVER, VICTORY }

signal game_over_triggered
signal level_completed(stats: Dictionary)
signal state_changed(new_state: GameState)
signal overhead_visibility_toggled(is_visible: bool)

## Truco de monedas: tipear este código (solo letras sin acción asignada en el juego) da monedas.
const CHEAT_COINS_CODE: String = "TOPTOP"
const CHEAT_COINS_AMOUNT: int = 1000

static var instance: GameManager = null

var current_state: GameState = GameState.PLAYING
var show_overhead_bars: bool = true
var _cheat_buffer: String = ""

# UI de Overlays (Pausa, Derrota, Victoria)
var _canvas_layer: CanvasLayer = null
var _overlay_background: ColorRect = null
var _defeat_panel: PanelContainer = null
var _pause_panel: PanelContainer = null
var _victory_panel: PanelContainer = null
var _victory_stats_label: Label = null
var _btn_next_sector: Button = null
## Sector al que lleva el botón SIGUIENTE SECTOR de la pantalla de victoria (vacío = no se ofrece).
var _next_sector_path: String = ""
var _scene_loader: CanvasLayer = null


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	ErrorLoggerScript.install()
	_setup_overlay_ui()
	_scene_loader = SceneLoaderScript.new() as CanvasLayer
	_scene_loader.name = "SceneLoader"
	add_child(_scene_loader)
	# Las acciones deben existir antes de cargar ajustes: la barra (hotbar_*) no está en project.godot
	InputSetup.setup_inputs()
	SettingsScript.load_and_apply(self)
	print("[GameManager] Inicializado en modo PLAYING.")


func _exit_tree() -> void:
	ErrorLoggerScript.uninstall()


static func get_instance() -> Node:
	return instance


## Cambia de escena pasando por la pantalla de carga (carga en segundo plano + barra de progreso).
func change_scene(path: String) -> void:
	if _scene_loader != null and is_instance_valid(_scene_loader):
		_scene_loader.call("go", path)
	else:
		get_tree().change_scene_to_file(path)


## Recarga la escena actual pasando por la pantalla de carga.
func reload_scene() -> void:
	var cur: Node = get_tree().current_scene
	if cur == null or cur.scene_file_path.is_empty():
		get_tree().reload_current_scene()
		return
	change_scene(cur.scene_file_path)


## Retorna true si la escena activa corresponde al banco de pruebas (Sandbox).
func is_sandbox() -> bool:
	var cur: Node = get_tree().current_scene
	if cur == null:
		return false
	if cur is TestLevel:
		return true
	var path: String = cur.scene_file_path
	return path.ends_with("test_level.tscn") or path.ends_with("stress_room.tscn") or path.ends_with("cinematic_bench.tscn")


## Retorna true si la escena activa es el Menú Principal.
func is_main_menu() -> bool:
	var cur: Node = get_tree().current_scene
	if cur == null:
		return false
	var path: String = cur.scene_file_path
	return path.ends_with("main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	
	var key_event: InputEventKey = event as InputEventKey
	var key: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode

	_track_cheat_input(key)

	# Manejo de tecla Escape
	if key == KEY_ESCAPE:
		if is_main_menu():
			return
		
		get_viewport().set_input_as_handled()
		if current_state == GameState.GAME_OVER or current_state == GameState.VICTORY:
			return_to_main_menu()
		elif current_state == GameState.PLAYING:
			toggle_pause()
		return
	
	# Manejo de tecla R (Respawn tras Game Over)
	if key == KEY_R and current_state == GameState.GAME_OVER:
		get_viewport().set_input_as_handled()
		respawn_at_checkpoint()
		return
	
	# Manejo de tecla F2 (Alternar Placas Superiores / Overhead UI)
	if key == KEY_F2:
		get_viewport().set_input_as_handled()
		show_overhead_bars = not show_overhead_bars
		overhead_visibility_toggled.emit(show_overhead_bars)
		print("[GameManager] Visibilidad de placas superiores: %s" % ("ACTIVADA" if show_overhead_bars else "DESACTIVADA"))
		return

	# Tecla F9: monitor de rendimiento con registro a disco en cualquier escena (menos el menú)
	if key == KEY_F9 and not is_main_menu():
		get_viewport().set_input_as_handled()
		toggle_perf_monitor()
		return


## Agrega o quita el monitor de rendimiento (core/debug/perf_monitor.gd) de la escena actual.
## Si la escena trae uno fijo (Sala de Estrés), solo muestra u oculta su panel.
func toggle_perf_monitor() -> void:
	var cur: Node = get_tree().current_scene
	if cur == null:
		return
	var existing: Node = cur.get_node_or_null("PerfMonitor")
	if existing != null:
		if bool(existing.get("persistent")):
			existing.call("toggle_overlay")
		else:
			existing.queue_free()
			print("[GameManager] Monitor de rendimiento desactivado (registro cerrado).")
		return
	var monitor: Node = PerfMonitorScript.new()
	monitor.set("tag", cur.scene_file_path.get_file().get_basename())
	cur.add_child(monitor)
	print("[GameManager] Monitor de rendimiento activado (F9 para quitarlo).")


## Acumula las últimas letras tipeadas y dispara el truco de monedas al completar el código.
func _track_cheat_input(key: Key) -> void:
	if key < KEY_A or key > KEY_Z or is_main_menu():
		return
	_cheat_buffer = (_cheat_buffer + char(key)).right(CHEAT_COINS_CODE.length())
	if _cheat_buffer == CHEAT_COINS_CODE:
		_cheat_buffer = ""
		var player: Player = get_tree().get_first_node_in_group(&"player") as Player
		if player != null and player.stats_manager != null:
			# Suma directa para no ensuciar la telemetría de monedas juntadas
			player.stats_manager.coins += CHEAT_COINS_AMOUNT
			player.stats_manager.coins_changed.emit(player.stats_manager.coins)
			print("[GameManager] Truco activado: +%d monedas." % CHEAT_COINS_AMOUNT)


## Callback invocado cuando la salud del jugador llega a 0.
func on_player_died(player: Player) -> void:
	if current_state != GameState.PLAYING:
		return
	
	# Modo Sandbox: reaparición inmediata sin pausar ni mostrar pantalla de derrota
	if is_sandbox():
		print("[GameManager] Jugador cayó en Sandbox. Reaparición instantánea.")
		var cur_scene: Node = get_tree().current_scene
		var spawn_pos: Vector2 = Vector2(180, 575)
		if cur_scene != null and "initial_spawn_position" in cur_scene:
			spawn_pos = cur_scene.initial_spawn_position
		if player != null:
			player.respawn(spawn_pos)
		return
	
	# Modo Campaña: pausar y desplegar overlay de derrota
	current_state = GameState.GAME_OVER
	game_over_triggered.emit()
	state_changed.emit(current_state)
	get_tree().paused = true
	_show_defeat_overlay()
	GameFeel.music_push(self, &"death")
	print("[GameManager] Jugador derrotado en Campaña. Esperando [R] para reaparecer.")


## Reaparece al jugador en el último checkpoint registrado en SaveManager.
func respawn_at_checkpoint() -> void:
	if current_state != GameState.GAME_OVER:
		return
	
	_hide_all_overlays()
	GameFeel.music_pop(self, &"death")
	get_tree().paused = false
	current_state = GameState.PLAYING
	state_changed.emit(current_state)
	
	var cur_scene: Node = get_tree().current_scene
	var fallback_pos: Vector2 = Vector2(160, 220)
	if cur_scene != null and "initial_spawn_position" in cur_scene:
		fallback_pos = cur_scene.initial_spawn_position
	
	var target_pos: Vector2 = SaveManager.get_respawn_point(fallback_pos)
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.respawn(target_pos)
		print("[GameManager] Jugador reaparecido en checkpoint: %s" % target_pos)


## Registra la culminación exitosa del sector y despliega la pantalla de victoria.
func complete_level(stats: Dictionary) -> void:
	current_state = GameState.VICTORY
	var mod_mgr: ZoneModifierManager = ZoneModifierManager.get_instance()
	if mod_mgr != null and mod_mgr.active_contract != null:
		var metrics_mgr: MetricsManager = MetricsManager.get_instance()
		if metrics_mgr != null:
			metrics_mgr.record_contract_completed()
	
	# Sector terminado: el checkpoint de reanudación ya no sirve
	SaveManager.clear_resume_point()
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()
	
	level_completed.emit(stats)
	state_changed.emit(current_state)
	get_tree().paused = true
	_show_victory_overlay(stats)
	GameFeel.music_push(self, &"victory")
	print("[GameManager] ¡Sector completado con éxito! Desplegando victoria y guardando progreso.")


## Alterna el menú de pausa durante la partida.
func toggle_pause() -> void:
	if current_state != GameState.PLAYING:
		return
	
	var will_pause: bool = not get_tree().paused
	get_tree().paused = will_pause
	if will_pause:
		_show_pause_overlay()
	else:
		_hide_all_overlays()


## Reinicia y repite el nivel actual para permitir farmeo continuo con progresión acumulada.
func repeat_current_level() -> void:
	_hide_all_overlays()
	get_tree().paused = false
	current_state = GameState.PLAYING
	state_changed.emit(current_state)
	
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()
	
	reload_scene()
	print("[GameManager] Repitiendo nivel actual para farmeo.")


## Pasa directo al siguiente sector desde la pantalla de victoria (el progreso ya quedó guardado).
func go_to_next_sector() -> void:
	if _next_sector_path.is_empty():
		return
	var next_path: String = _next_sector_path
	_hide_all_overlays()
	get_tree().paused = false
	current_state = GameState.PLAYING
	state_changed.emit(current_state)

	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()

	change_scene(next_path)
	print("[GameManager] Avanzando al siguiente sector: %s" % next_path)


## Retorna limpiamente al campamento base despausando el árbol de escena.
func return_to_base_camp() -> void:
	_hide_all_overlays()
	get_tree().paused = false
	current_state = GameState.PLAYING
	state_changed.emit(current_state)
	
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()
	
	change_scene("res://scenes/hub/base_camp.tscn")
	print("[GameManager] Retornando al Campamento Base con progreso persistido.")


## Retorna limpiamente al menú principal despausando el árbol de escena.
func return_to_main_menu() -> void:
	_hide_all_overlays()
	get_tree().paused = false
	current_state = GameState.PLAYING
	state_changed.emit(current_state)
	change_scene("res://scenes/main_menu.tscn")
	print("[GameManager] Retornando al Menú Principal.")


## Reinicia el sector activo actual.
func restart_current_sector() -> void:
	_hide_all_overlays()
	get_tree().paused = false
	current_state = GameState.PLAYING
	state_changed.emit(current_state)
	reload_scene()


# ==============================================================================
# Construcción y Control de Overlays de Interfaz
# ==============================================================================

func _setup_overlay_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "GameManagerOverlays"
	_canvas_layer.layer = 100
	_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas_layer)
	
	# Fondo oscurecido
	_overlay_background = ColorRect.new()
	_overlay_background.name = "Background"
	_overlay_background.color = Color(0.02, 0.03, 0.05, 0.85)
	_overlay_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_background.visible = false
	_canvas_layer.add_child(_overlay_background)
	
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay_background.add_child(center)
	
	# 1. Panel de Derrota
	_defeat_panel = _create_card_panel(Color(0.18, 0.05, 0.07, 0.95), Color(0.85, 0.2, 0.25, 0.9))
	center.add_child(_defeat_panel)
	var defeat_vbox: VBoxContainer = VBoxContainer.new()
	defeat_vbox.add_theme_constant_override("separation", 14)
	_defeat_panel.add_child(defeat_vbox)
	
	var defeat_title: Label = _create_label("SECTOR FALLIDO", 26, Color(1.0, 0.25, 0.3))
	defeat_vbox.add_child(defeat_title)
	
	var defeat_desc: Label = _create_label("El chasis de combate ha sido neutralizado.\nPresiona [R] para reaparecer en el último checkpoint.", 14, Color(0.85, 0.85, 0.9))
	defeat_vbox.add_child(defeat_desc)
	
	var btn_respawn: Button = _create_button("REAPARECER [R]", Color(0.2, 0.65, 0.35))
	btn_respawn.pressed.connect(respawn_at_checkpoint)
	defeat_vbox.add_child(btn_respawn)
	
	var btn_defeat_menu: Button = _create_button("VOLVER AL MENÚ [ESC]", Color(0.3, 0.35, 0.45))
	btn_defeat_menu.pressed.connect(return_to_main_menu)
	defeat_vbox.add_child(btn_defeat_menu)
	
	# 2. Panel de Pausa
	_pause_panel = _create_card_panel(Color(0.06, 0.08, 0.12, 0.95), Color(0.25, 0.45, 0.65, 0.9))
	center.add_child(_pause_panel)
	var pause_vbox: VBoxContainer = VBoxContainer.new()
	pause_vbox.add_theme_constant_override("separation", 14)
	_pause_panel.add_child(pause_vbox)
	
	var pause_title: Label = _create_label("PAUSA", 26, Color(0.35, 0.8, 1.0))
	pause_vbox.add_child(pause_title)
	
	var btn_resume: Button = _create_button("CONTINUAR [ESC]", Color(0.2, 0.55, 0.85))
	btn_resume.pressed.connect(toggle_pause)
	pause_vbox.add_child(btn_resume)
	
	var btn_options: Button = _create_button("OPCIONES", Color(0.3, 0.5, 0.6))
	btn_options.pressed.connect(func() -> void: SettingsScript.open_window(self))
	pause_vbox.add_child(btn_options)

	var btn_restart: Button = _create_button("REINICIAR SECTOR", Color(0.35, 0.4, 0.5))
	btn_restart.pressed.connect(restart_current_sector)
	pause_vbox.add_child(btn_restart)
	
	var btn_pause_menu: Button = _create_button("VOLVER AL MENÚ PRINCIPAL", Color(0.3, 0.35, 0.45))
	btn_pause_menu.pressed.connect(return_to_main_menu)
	pause_vbox.add_child(btn_pause_menu)
	
	# 3. Panel de Victoria
	_victory_panel = _create_card_panel(Color(0.05, 0.14, 0.09, 0.95), Color(0.25, 0.85, 0.45, 0.9))
	center.add_child(_victory_panel)
	var victory_vbox: VBoxContainer = VBoxContainer.new()
	victory_vbox.add_theme_constant_override("separation", 14)
	_victory_panel.add_child(victory_vbox)
	
	var victory_title: Label = _create_label("¡SECTOR COMPLETADO!", 26, Color(0.3, 1.0, 0.5))
	victory_vbox.add_child(victory_title)
	
	_victory_stats_label = _create_label("Extracción balística exitosa.\nMonedas: 0", 14, Color(0.9, 0.95, 0.9))
	victory_vbox.add_child(_victory_stats_label)
	
	_btn_next_sector = _create_button("SIGUIENTE SECTOR", Color(0.95, 0.75, 0.25))
	_btn_next_sector.pressed.connect(go_to_next_sector)
	victory_vbox.add_child(_btn_next_sector)

	var btn_repeat_level: Button = _create_button("REPETIR NIVEL [FARMEAR]", Color(0.2, 0.65, 0.8))
	btn_repeat_level.pressed.connect(repeat_current_level)
	victory_vbox.add_child(btn_repeat_level)
	
	var btn_victory_camp: Button = _create_button("VOLVER AL CAMPAMENTO BASE", Color(0.2, 0.7, 0.4))
	btn_victory_camp.pressed.connect(return_to_base_camp)
	victory_vbox.add_child(btn_victory_camp)
	
	var btn_victory_menu: Button = _create_button("VOLVER AL MENÚ PRINCIPAL", Color(0.3, 0.35, 0.45))
	btn_victory_menu.pressed.connect(return_to_main_menu)
	victory_vbox.add_child(btn_victory_menu)
	
	_hide_all_overlays()


func _hide_all_overlays() -> void:
	if _overlay_background != null:
		_overlay_background.visible = false
	if _defeat_panel != null:
		_defeat_panel.visible = false
	if _pause_panel != null:
		_pause_panel.visible = false
	if _victory_panel != null:
		_victory_panel.visible = false


func _show_defeat_overlay() -> void:
	_hide_all_overlays()
	_overlay_background.visible = true
	_defeat_panel.visible = true


func _show_pause_overlay() -> void:
	_hide_all_overlays()
	_overlay_background.visible = true
	_pause_panel.visible = true


func _show_victory_overlay(stats: Dictionary) -> void:
	_hide_all_overlays()
	_overlay_background.visible = true
	_victory_panel.visible = true
	_next_sector_path = str(stats.get("next_level_path", ""))
	if _btn_next_sector != null:
		_btn_next_sector.visible = not _next_sector_path.is_empty()
		if _btn_next_sector.visible:
			_btn_next_sector.grab_focus()
	if _victory_stats_label != null:
		var coins: int = int(stats.get("coins", 0))
		var level: int = int(stats.get("level", 1))
		var sector_name: String = str(stats.get("sector", "Sector 1"))
		var unlocked_weapon: String = str(stats.get("unlocked_weapon", ""))
		var weapon_reward_str: String = ""
		if not unlocked_weapon.is_empty():
			weapon_reward_str = "\n\n★ ¡NUEVA ARMA DESBLOQUEADA: %s!" % unlocked_weapon.to_upper()
		_victory_stats_label.text = "¡Extracción balística exitosa en %s!\n• Nivel del Chasis: %d\n• Monedas Acumuladas: %d%s" % [sector_name, level, coins, weapon_reward_str]


func _create_card_panel(bg_color: Color, border_color: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 240)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 24.0
	style.content_margin_top = 20.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _create_button(text: String, accent_color: Color) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 36)
	btn.focus_mode = Control.FOCUS_ALL
	
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.15, 0.2, 0.9)
	normal_style.border_color = accent_color
	normal_style.border_width_bottom = 1
	normal_style.border_width_top = 1
	normal_style.border_width_left = 1
	normal_style.border_width_right = 1
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	
	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = accent_color
	
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)
	return btn
