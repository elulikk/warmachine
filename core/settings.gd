extends RefCounted
## Opciones de juego del jugador (video, audio, jugabilidad, accesibilidad, controles). Todo estático: sin autoload propio.
## Sin class_name a propósito: se carga por preload (`const SettingsScript = preload("res://core/settings.gd")`).
##
## - `load_and_apply(ctx)` lee `user://settings.cfg`, aplica todo y crea el anfitrión (`SettingsHost`: contador de FPS,
##   silencio al perder el foco, posprocesado y filtro para daltonismo). Lo llama `GameManager._ready()` al arrancar.
## - `set_value(ctx, key, value)` cambia una opción, la aplica en el acto y la guarda.
## - Los sistemas que dependen de una opción la consultan con `get_float()` / `get_bool()` / `particle_scale()`,
##   `enemy_damage_mult()` / `enemy_health_mult()` (dificultad) y `reduce_flashes()`.

const CONFIG_PATH: String = "user://settings.cfg"
const HostScript = preload("res://core/settings_host.gd")

const DISPLAY_WINDOWED: int = 0
const DISPLAY_BORDERLESS: int = 1  ## Pantalla completa ventana (sin bordes, a la resolución del escritorio)
const DISPLAY_EXCLUSIVE: int = 2   ## Pantalla completa exclusiva

const DISPLAY_LABELS: Array[String] = ["Ventana", "Pantalla completa (ventana sin bordes)", "Pantalla completa exclusiva"]
const VSYNC_LABELS: Array[String] = ["Desactivada", "Activada", "Adaptativa", "Buzón (triple buffer)"]
const QUALITY_LABELS: Array[String] = ["Baja", "Media", "Alta", "Ultra", "Personalizada"]
const MSAA_LABELS: Array[String] = ["Desactivado", "2x", "4x", "8x"]
const COLORBLIND_LABELS: Array[String] = ["Desactivado", "Protanopia (rojo)", "Deuteranopia (verde)", "Tritanopia (azul)"]
const FPS_VALUES: Array[int] = [30, 60, 90, 120, 144, 165, 240, 0]  ## 0 = sin límite
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)
]

## Preajustes de calidad: msaa (índice de MSAA_LABELS), densidad de partículas y posprocesado
## (viñeta, grano de película y resplandor; ver `core/post_fx.gd`).
const QUALITY_PRESETS: Array[Dictionary] = [
	{"msaa": 0, "particles": 0.5, "fx_vignette": false, "fx_grain": false, "fx_bloom": false},
	{"msaa": 1, "particles": 0.75, "fx_vignette": true, "fx_grain": false, "fx_bloom": false},
	{"msaa": 2, "particles": 1.0, "fx_vignette": true, "fx_grain": true, "fx_bloom": false},
	{"msaa": 3, "particles": 1.0, "fx_vignette": true, "fx_grain": true, "fx_bloom": true},
]
## Opciones que forman parte del preajuste de calidad: tocarlas a mano pasa a "Personalizada".
const QUALITY_KEYS: Array[String] = ["msaa", "particles", "fx_vignette", "fx_grain", "fx_bloom"]

## Dificultad: multiplica el daño que hacen los enemigos al jugador y la vida de los enemigos.
const DIFFICULTY_LABELS: Array[String] = ["Recluta (fácil)", "Soldado (normal)", "Veterano (difícil)", "Pesadilla"]
const DIFFICULTY_PRESETS: Array[Dictionary] = [
	{"enemy_damage": 0.6, "enemy_health": 0.75},
	{"enemy_damage": 1.0, "enemy_health": 1.0},
	{"enemy_damage": 1.35, "enemy_health": 1.25},
	{"enemy_damage": 1.75, "enemy_health": 1.6},
]

## Escala de la interfaz (también agranda el texto). La cámara compensa para que el mundo se vea igual.
const UI_SCALE_MIN: float = 0.85
const UI_SCALE_MAX: float = 1.25

## Acciones reasignables (nombre de la acción -> texto en el menú). Cada una tiene un casillero de teclado/ratón
## y uno de mando; el resto de los eventos de la acción (flechas, stick, etc.) se conservan.
const REMAPPABLE: Dictionary = {
	"move_left": "Mover a la izquierda",
	"move_right": "Mover a la derecha",
	"move_up": "Arriba / apuntar arriba",
	"move_down": "Abajo",
	"jump": "Saltar",
	"dash": "Dash (con módulo)",
	"eye_laser": "Rayo láser (con casco)",
	"cloak": "Capa de invisibilidad",
	"attack": "Atacar / disparar",
	"attack_secondary": "Mano secundaria",
	"reload": "Recargar",
	"use_tool": "Herramienta",
	"throw_tactical": "Arrojadizo táctico",
	"interact": "Interactuar",
	"consumable_1": "Consumible 1",
	"consumable_2": "Consumible 2",
	"hotbar_1": "Casillero 1",
	"hotbar_2": "Casillero 2",
	"hotbar_3": "Casillero 3",
	"weapon_prev": "Arma anterior",
	"weapon_next": "Arma siguiente",
	"weapon_toggle": "Alternar arma",
	"toggle_inventory": "Inventario",
	"toggle_stats_window": "Estadísticas",
	"toggle_help": "Ayuda",
}

## Casilleros de reasignación por acción.
const SLOT_PC: String = "pc"    ## teclado o botón del ratón
const SLOT_JOY: String = "joy"  ## botón, gatillo o eje del mando

const DEFAULTS: Dictionary = {
	"display_mode": DISPLAY_WINDOWED,
	"resolution": Vector2i(1152, 648),
	"monitor": -1,  ## -1 = el monitor donde está la ventana
	"vsync": 1,
	"max_fps": 0,
	"quality": 2,
	"msaa": 2,
	"particles": 1.0,
	"fire_style": 0,  ## estilo de fuego y ácido: 0 = sprites (liviano), 1 = partículas, 2 = shaders
	"enemy_health_bars": true,  ## barras de vida sobre los enemigos (apagadas ahorran un nodo por enemigo)
	"enemy_lod": true,  ## enemigos lejanos del jugador se dibujan como un solo sprite en vez del esqueleto
	"fx_vignette": true,
	"fx_grain": true,
	"fx_bloom": false,
	"parallax_bg": true,  ## fondos por capas con paralaje; apagado = imagen fija
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"mute_unfocused": true,
	"difficulty": 1,
	"screen_shake": 1.0,
	"hit_stop": true,
	"damage_numbers": true,
	"show_fps": false,
	"ui_scale": 1.0,
	"colorblind": 0,
	"colorblind_strength": 1.0,
	"reduce_flashes": false,
}

static var values: Dictionary = {}
## acción -> {"pc": descriptor, "joy": descriptor}. Descriptor: {"type": "key"|"mouse"|"joy"|"axis", "code": int,
## "axis": int, "value": float}. Solo guarda lo que el jugador cambió.
static var bindings: Dictionary = {}
static var _default_events: Dictionary = {}
static var _loaded: bool = false
static var _host: Node = null


# ==============================================================================
# Carga, guardado y aplicación
# ==============================================================================

static func load_and_apply(ctx: Node) -> void:
	if not _loaded:
		_capture_default_events()
		values = DEFAULTS.duplicate()
		var cfg: ConfigFile = ConfigFile.new()
		if cfg.load(CONFIG_PATH) == OK:
			for key: String in DEFAULTS.keys():
				if cfg.has_section_key("settings", key):
					values[key] = cfg.get_value("settings", key, DEFAULTS[key])
			# Archivos de antes del posprocesado: los efectos salen del preajuste de calidad guardado
			var preset: int = int(values["quality"])
			if not cfg.has_section_key("settings", "fx_vignette") and preset >= 0 and preset < QUALITY_PRESETS.size():
				for k: String in ["fx_vignette", "fx_grain", "fx_bloom"]:
					values[k] = QUALITY_PRESETS[preset][k]
			for action: String in REMAPPABLE.keys():
				if cfg.has_section_key("bindings", action):
					var stored: Variant = cfg.get_value("bindings", action, {})
					if stored is Dictionary:
						bindings[action] = (stored as Dictionary).duplicate(true)
				elif cfg.has_section_key("controls", action):
					# Formato anterior: solo la tecla física principal
					bindings[action] = {SLOT_PC: {"type": "key", "code": int(cfg.get_value("controls", action, 0))}}
		_loaded = true
	_ensure_host(ctx)
	apply_all(ctx)
	# Al arrancar, la ventana en modo ventana se abre maximizada (una sola vez; no cambia la resolución guardada)
	if get_int("display_mode") == DISPLAY_WINDOWED and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


static func save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for key: String in values.keys():
		cfg.set_value("settings", key, values[key])
	for action: String in bindings.keys():
		cfg.set_value("bindings", action, bindings[action])
	cfg.save(CONFIG_PATH)


static func apply_all(ctx: Node) -> void:
	_apply_all_bindings()
	_apply_display(ctx)
	_apply_audio()
	_apply_quality(ctx)
	if _host != null and is_instance_valid(_host):
		_host.call("refresh")


## Cambia una opción, la aplica de inmediato y la guarda.
static func set_value(ctx: Node, key: String, value: Variant) -> void:
	if not _loaded:
		load_and_apply(ctx)
	values[key] = value
	if key == "quality":
		var preset: int = int(value)
		if preset >= 0 and preset < QUALITY_PRESETS.size():
			for k: String in QUALITY_KEYS:
				values[k] = QUALITY_PRESETS[preset][k]
	elif QUALITY_KEYS.has(key):
		values["quality"] = QUALITY_LABELS.size() - 1  # Personalizada
	apply_all(ctx)
	save()


static func reset_all(ctx: Node) -> void:
	values = DEFAULTS.duplicate()
	bindings.clear()
	for action: String in REMAPPABLE.keys():
		_restore_default_event(action)
	apply_all(ctx)
	save()


# ==============================================================================
# Consultas
# ==============================================================================

static func get_value(key: String) -> Variant:
	if values.is_empty():
		values = DEFAULTS.duplicate()
	return values.get(key, DEFAULTS.get(key))


static func get_float(key: String) -> float:
	return float(get_value(key))


static func get_bool(key: String) -> bool:
	return bool(get_value(key))


static func get_int(key: String) -> int:
	return int(get_value(key))


## Multiplicador de la cantidad de partículas (calidad gráfica).
static func particle_scale() -> float:
	return clampf(get_float("particles"), 0.1, 1.0)


static func _difficulty() -> Dictionary:
	return DIFFICULTY_PRESETS[clampi(get_int("difficulty"), 0, DIFFICULTY_PRESETS.size() - 1)]


## Multiplicador del daño que reciben el jugador (por enemigos, proyectiles y contacto).
static func enemy_damage_mult() -> float:
	return float(_difficulty()["enemy_damage"])


## Multiplicador de la vida máxima de los enemigos (lo aplica HealthComponent al aparecer).
static func enemy_health_mult() -> float:
	return float(_difficulty()["enemy_health"])


## Accesibilidad: sin destellos blancos a pantalla ni en impactos.
static func reduce_flashes() -> bool:
	return get_bool("reduce_flashes")


static func ui_scale() -> float:
	return clampf(get_float("ui_scale"), UI_SCALE_MIN, UI_SCALE_MAX)


# ==============================================================================
# Video
# ==============================================================================

## Monitor elegido (o el actual si no hay uno elegido o ya no está conectado).
static func target_screen() -> int:
	var chosen: int = get_int("monitor")
	if chosen >= 0 and chosen < DisplayServer.get_screen_count():
		return chosen
	return DisplayServer.window_get_current_screen()


static func screen_labels() -> Array[String]:
	var labels: Array[String] = []
	for i in range(DisplayServer.get_screen_count()):
		var size: Vector2i = DisplayServer.screen_get_size(i)
		var primary: String = " (principal)" if i == DisplayServer.get_primary_screen() else ""
		labels.append("Monitor %d: %d x %d%s" % [i + 1, size.x, size.y, primary])
	return labels


static func _apply_display(ctx: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Lanzamientos de prueba (smoke-test): la ventana queda como la deja override.cfg, chica, fuera de pantalla y sin foco
	if OS.get_environment("WARMACHINE_QUIET") == "1":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		return
	var mode: int = get_int("display_mode")
	var window: Window = ctx.get_window() if ctx != null and ctx.is_inside_tree() else null
	var screen: int = target_screen()
	# Para cambiar de monitor la ventana tiene que estar en modo ventana
	if screen != DisplayServer.window_get_current_screen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_current_screen(screen)
	match mode:
		DISPLAY_EXCLUSIVE:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DISPLAY_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var res: Vector2i = get_value("resolution") as Vector2i
			var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
			res = Vector2i(mini(res.x, screen_size.x), mini(res.y, screen_size.y))
			DisplayServer.window_set_size(res)
			var origin: Vector2i = DisplayServer.screen_get_position(screen)
			DisplayServer.window_set_position(origin + (screen_size - res) / 2)
	var vsync_modes: Array[int] = [
		DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED,
		DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_MAILBOX
	]
	DisplayServer.window_set_vsync_mode(vsync_modes[clampi(get_int("vsync"), 0, 3)] as DisplayServer.VSyncMode)
	Engine.max_fps = get_int("max_fps")
	if window != null:
		window.min_size = Vector2i(960, 540)
		window.content_scale_factor = ui_scale()


## Resoluciones que entran en el monitor elegido.
static func available_resolutions() -> Array[Vector2i]:
	var screen_size: Vector2i = DisplayServer.screen_get_size(target_screen())
	var list: Array[Vector2i] = []
	for res: Vector2i in RESOLUTIONS:
		if res.x <= screen_size.x and res.y <= screen_size.y:
			list.append(res)
	if list.is_empty():
		list.append(RESOLUTIONS[0])
	return list


static func _apply_quality(ctx: Node) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	var viewport: Viewport = ctx.get_viewport()
	if viewport == null:
		return
	# gl_compatibility (OpenGL 3) no soporta MSAA 2D: se guarda la opción pero no se aplica (evita el aviso del motor)
	if not msaa_supported():
		return
	var levels: Array[int] = [
		Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X
	]
	viewport.msaa_2d = levels[clampi(get_int("msaa"), 0, 3)] as Viewport.MSAA


## El MSAA 2D solo existe en los renderizadores Forward+ y Mobile (Vulkan/D3D12/Metal).
static func msaa_supported() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


# ==============================================================================
# Audio
# ==============================================================================

static func _apply_audio() -> void:
	var master: int = AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, _to_db(get_float("master_volume")))
	# Los buses SFX y Music los crea Sfx.ensure_buses()
	var sfx_script: GDScript = load("res://core/sfx.gd") as GDScript
	if sfx_script != null:
		sfx_script.call("ensure_buses")
	var sfx_idx: int = AudioServer.get_bus_index(&"SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, _to_db(get_float("sfx_volume")))
	var music_idx: int = AudioServer.get_bus_index(&"Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, _to_db(get_float("music_volume")))


static func _to_db(linear: float) -> float:
	return -80.0 if linear <= 0.001 else linear_to_db(clampf(linear, 0.0, 1.0))


# ==============================================================================
# Controles
# ==============================================================================

static func _capture_default_events() -> void:
	for action: String in REMAPPABLE.keys():
		if not InputMap.has_action(action):
			continue
		var list: Array[InputEvent] = []
		for ev: InputEvent in InputMap.action_get_events(action):
			list.append(ev.duplicate() as InputEvent)
		_default_events[action] = list


## Convierte un evento de entrada en descriptor guardable, o {} si no sirve para reasignar.
static func descriptor_from_event(event: InputEvent) -> Dictionary:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null:
		var code: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		return {"type": "key", "code": int(code)}
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event != null:
		return {"type": "mouse", "code": int(mouse_event.button_index)}
	var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
	if joy_event != null:
		return {"type": "joy", "code": int(joy_event.button_index)}
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion != null and absf(motion.axis_value) >= 0.5:
		return {"type": "axis", "axis": int(motion.axis), "value": signf(motion.axis_value)}
	return {}


static func _event_from_descriptor(desc: Dictionary) -> InputEvent:
	match str(desc.get("type", "")):
		"key":
			var key_event: InputEventKey = InputEventKey.new()
			key_event.physical_keycode = int(desc.get("code", 0)) as Key
			return key_event
		"mouse":
			var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
			mouse_event.button_index = int(desc.get("code", 0)) as MouseButton
			return mouse_event
		"joy":
			var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
			joy_event.button_index = int(desc.get("code", 0)) as JoyButton
			return joy_event
		"axis":
			var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			motion.axis = int(desc.get("axis", 0)) as JoyAxis
			motion.axis_value = float(desc.get("value", 1.0))
			return motion
	return null


static func slot_of(desc: Dictionary) -> String:
	var kind: String = str(desc.get("type", ""))
	return SLOT_JOY if kind == "joy" or kind == "axis" else SLOT_PC


static func _event_slot(ev: InputEvent) -> String:
	if ev is InputEventKey or ev is InputEventMouseButton:
		return SLOT_PC
	if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
		return SLOT_JOY
	return ""


static func _same_descriptor(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or str(a.get("type")) != str(b.get("type")):
		return false
	if str(a.get("type")) == "axis":
		return int(a.get("axis", -1)) == int(b.get("axis", -2)) and signf(float(a.get("value", 0.0))) == signf(float(b.get("value", 0.0)))
	return int(a.get("code", -1)) == int(b.get("code", -2))


## Descriptor principal actual de una acción en un casillero (`SLOT_PC` o `SLOT_JOY`), o {} si no tiene.
static func current_descriptor(action: String, slot: String) -> Dictionary:
	if not InputMap.has_action(action):
		return {}
	for ev: InputEvent in InputMap.action_get_events(action):
		if _event_slot(ev) == slot:
			var desc: Dictionary = descriptor_from_event(ev)
			if ev is InputEventJoypadMotion:
				var motion: InputEventJoypadMotion = ev as InputEventJoypadMotion
				desc = {"type": "axis", "axis": int(motion.axis), "value": signf(motion.axis_value)}
			if not desc.is_empty():
				return desc
	return {}


## Nombre legible del evento principal de una acción en un casillero.
static func binding_label(action: String, slot: String = SLOT_PC) -> String:
	return describe(current_descriptor(action, slot))


## Compatibilidad: nombre de la tecla/botón principal de teclado o ratón.
static func key_label(action: String) -> String:
	return binding_label(action, SLOT_PC)


static func describe(desc: Dictionary) -> String:
	match str(desc.get("type", "")):
		"key":
			var code: Key = int(desc.get("code", 0)) as Key
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
		"mouse":
			var names: Dictionary = {
				MOUSE_BUTTON_LEFT: "Clic izquierdo", MOUSE_BUTTON_RIGHT: "Clic derecho", MOUSE_BUTTON_MIDDLE: "Clic central",
				MOUSE_BUTTON_WHEEL_UP: "Rueda arriba", MOUSE_BUTTON_WHEEL_DOWN: "Rueda abajo",
				MOUSE_BUTTON_WHEEL_LEFT: "Rueda izquierda", MOUSE_BUTTON_WHEEL_RIGHT: "Rueda derecha",
				MOUSE_BUTTON_XBUTTON1: "Ratón 4", MOUSE_BUTTON_XBUTTON2: "Ratón 5",
			}
			return str(names.get(int(desc.get("code", 0)), "Ratón %d" % int(desc.get("code", 0))))
		"joy":
			var buttons: Dictionary = {
				JOY_BUTTON_A: "A / Cruz", JOY_BUTTON_B: "B / Círculo", JOY_BUTTON_X: "X / Cuadrado", JOY_BUTTON_Y: "Y / Triángulo",
				JOY_BUTTON_BACK: "Select / Back", JOY_BUTTON_GUIDE: "Guía", JOY_BUTTON_START: "Start",
				JOY_BUTTON_LEFT_STICK: "Stick izq. (L3)", JOY_BUTTON_RIGHT_STICK: "Stick der. (R3)",
				JOY_BUTTON_LEFT_SHOULDER: "LB / L1", JOY_BUTTON_RIGHT_SHOULDER: "RB / R1",
				JOY_BUTTON_DPAD_UP: "Cruceta arriba", JOY_BUTTON_DPAD_DOWN: "Cruceta abajo",
				JOY_BUTTON_DPAD_LEFT: "Cruceta izq.", JOY_BUTTON_DPAD_RIGHT: "Cruceta der.",
			}
			return str(buttons.get(int(desc.get("code", 0)), "Botón %d" % int(desc.get("code", 0))))
		"axis":
			var axis: int = int(desc.get("axis", 0))
			var positive: bool = float(desc.get("value", 1.0)) > 0.0
			match axis:
				JOY_AXIS_TRIGGER_LEFT:
					return "LT / L2"
				JOY_AXIS_TRIGGER_RIGHT:
					return "RT / R2"
				JOY_AXIS_LEFT_X:
					return "Stick izq. " + ("→" if positive else "←")
				JOY_AXIS_LEFT_Y:
					return "Stick izq. " + ("↓" if positive else "↑")
				JOY_AXIS_RIGHT_X:
					return "Stick der. " + ("→" if positive else "←")
				JOY_AXIS_RIGHT_Y:
					return "Stick der. " + ("↓" if positive else "↑")
			return "Eje %d" % axis
	return "-"


## Otra acción reasignable que ya usa este evento como principal en el mismo casillero ("" si no hay conflicto).
static func find_conflict(action: String, desc: Dictionary) -> String:
	var slot: String = slot_of(desc)
	for other: String in REMAPPABLE.keys():
		if other == action:
			continue
		if _same_descriptor(current_descriptor(other, slot), desc):
			return other
	return ""


## Asigna un evento como principal de la acción en su casillero. Si otra acción lo usaba, intercambian
## (la otra se queda con el evento anterior de esta). Devuelve el nombre de la acción con la que hubo conflicto.
static func rebind_event(_ctx: Node, action: String, desc: Dictionary) -> String:
	if desc.is_empty():
		return ""
	var slot: String = slot_of(desc)
	var conflict: String = find_conflict(action, desc)
	if not conflict.is_empty():
		var previous: Dictionary = current_descriptor(action, slot)
		_store_binding(conflict, slot, previous)
	_store_binding(action, slot, desc)
	_apply_all_bindings()
	save()
	return conflict


## Compatibilidad con la versión anterior: reasigna solo una tecla física.
static func rebind(ctx: Node, action: String, physical_keycode: int) -> void:
	rebind_event(ctx, action, {"type": "key", "code": physical_keycode})


## Vuelve una acción a sus eventos de fábrica.
static func reset_binding(action: String) -> void:
	bindings.erase(action)
	_restore_default_event(action)
	save()


static func _store_binding(action: String, slot: String, desc: Dictionary) -> void:
	var entry: Dictionary = (bindings.get(action, {}) as Dictionary).duplicate(true)
	if desc.is_empty():
		entry[slot] = {"type": "none"}
	else:
		entry[slot] = desc.duplicate(true)
	bindings[action] = entry


static func _apply_all_bindings() -> void:
	for action: String in REMAPPABLE.keys():
		if not InputMap.has_action(action):
			continue
		_restore_default_event(action)
		var entry: Dictionary = bindings.get(action, {}) as Dictionary
		for slot: String in [SLOT_PC, SLOT_JOY]:
			if entry.has(slot):
				_replace_primary(action, slot, entry[slot] as Dictionary)


## Reemplaza el primer evento del casillero por el nuevo (o lo quita si el descriptor es "none").
static func _replace_primary(action: String, slot: String, desc: Dictionary) -> void:
	var fresh: InputEvent = _event_from_descriptor(desc)
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var replaced: bool = false
	for ev: InputEvent in events:
		if not replaced and _event_slot(ev) == slot:
			replaced = true
			if fresh != null:
				InputMap.action_add_event(action, fresh)
			continue
		# No duplicar el evento nuevo si ya estaba como secundario
		if fresh != null and _same_descriptor(descriptor_from_event(ev), desc):
			continue
		InputMap.action_add_event(action, ev)
	if not replaced and fresh != null:
		InputMap.action_add_event(action, fresh)


static func _restore_default_event(action: String) -> void:
	if not _default_events.has(action) or not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for ev: InputEvent in (_default_events[action] as Array):
		InputMap.action_add_event(action, ev.duplicate() as InputEvent)


# ==============================================================================
# Anfitrión (FPS, foco, posprocesado) y ventana de opciones
# ==============================================================================

static func _ensure_host(ctx: Node) -> void:
	if _host != null and is_instance_valid(_host):
		return
	if ctx == null or not ctx.is_inside_tree():
		return
	_host = (HostScript as GDScript).new() as Node
	_host.name = "SettingsHost"
	ctx.get_tree().root.add_child.call_deferred(_host)


## Abre la ventana de opciones (sobre cualquier pantalla, también en pausa).
static func open_window(ctx: Node) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	var root: Node = ctx.get_tree().root
	if root.get_node_or_null("SettingsWindow") != null:
		return
	var win: Node = (load("res://ui/settings_window.gd") as GDScript).new() as Node
	win.name = "SettingsWindow"
	root.add_child(win)
