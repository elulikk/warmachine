extends RefCounted
## Contenido de la cinta de la Sala de Estrés (el widget en sí es `ui/debug/ribbon.gd`, genérico).
## Sin class_name a propósito: lo carga `stress_room.gd` por `preload`.
##
## Para sumar una opción: agregar un control a un grupo dentro de la pestaña que corresponda.
## Para sumar una pestaña: escribir una función `_tab_xxx(room, ribbon)` y llamarla desde `build()`.
## Los controles solo llaman métodos públicos de la sala (`set_*`, `queue_batch`, `kill_all`...) y leen sus constantes;
## el estado vive en la sala. `room` va sin tipo a propósito: la sala precarga este archivo y un tipo sería un ciclo.

const RibbonScript = preload("res://ui/debug/ribbon.gd")
const RibbonTheme = preload("res://ui/debug/ribbon_theme.gd")


static func build(room, ribbon: RibbonScript) -> void:
	_tab_enemies(room, ribbon)
	_tab_spawning(room, ribbon)
	_tab_player(room, ribbon)
	_tab_effects(room, ribbon)
	_tab_arena(room, ribbon)
	_tab_diagnostics(room, ribbon)
	ribbon.build_shortcuts_tab("shortcuts", "Atajos")
	_status_bar(room, ribbon)
	ribbon.select_tab("enemies")


# ==============================================================================
# Pestañas
# ==============================================================================

static func _tab_enemies(room, ribbon: RibbonScript) -> void:
	ribbon.add_tab("enemies", "Enemigos", "Qué aparece, cuántos y cuándo")

	var batch := ribbon.add_group("enemies", "Lote")
	batch.big_button("Generar lote", func() -> void: room.queue_batch(room.enemy_type), {
		"icon": "plus", "variant": "primary", "tip": "Pide un lote del tipo y la cantidad elegidos"})
	batch.column()
	batch.choice("type", "Tipo", room.TYPE_NAMES, room.enemy_type,
			func(i: int) -> void: room.set_enemy_type(i), {"tip": "Qué enemigo sale (o una mezcla con pesos como en la campaña)"})
	batch.segmented("batch", "Cantidad", room.BATCH_SIZES, room.BATCH_SIZES.find(room.batch_size),
			func(i: int) -> void: room.set_batch_size(room.BATCH_SIZES[i]), {"tip": "Enemigos por lote"})
	for entry: Array in [["N", "Lote corredor"], ["Z", "Lote zombi"], ["V", "Lote fantasma"],
			["B", "Lote bruto"], ["M", "Lote centinela"]]:
		ribbon.add_hint("enemies", entry[0], entry[1])
	batch.readout(func() -> String: return "N Z V B M  lote rápido por tipo", {"tip": "Teclas de lote rápido (usan la cantidad elegida)"})

	var spawner := ribbon.add_group("enemies", "Generador continuo")
	spawner.toggle("spawner", "Generador activo", room.spawner_on, func(on: bool) -> void: room.set_spawner(on),
			{"key": KEY_F5, "tip": "Mantiene la cantidad de vivos hasta el tope"})
	spawner.segmented("rate", "Ritmo /s", _labels(room.RATES, "%.0f"), room.RATES.find(room.spawn_rate),
			func(i: int) -> void: room.set_spawn_rate(room.RATES[i]), {"tip": "Enemigos que se piden por segundo"})
	spawner.choice("cap", "Tope", _labels(room.CAPS, "%d vivos"), room.CAPS.find(room.alive_cap),
			func(i: int) -> void: room.set_alive_cap(room.CAPS[i]), {"tip": "El generador se frena al llegar a esta cantidad de vivos"})

	var actions := ribbon.add_group("enemies", "Acciones")
	actions.big_button("Matar todos", room.kill_all, {
		"icon": "kill", "variant": "danger", "hint": "K", "tip": "Daño real a todos: muerte, sangre, gibs, botín y orbes (el peor cuadro)"})
	actions.column()
	actions.button("Herir a todos", room.hurt_all, {"icon": "bolt", "tip": "Un impacto normal a todos, sin matarlos"})
	actions.button("Borrar sin efectos", room.remove_all_silently, {
		"icon": "trash", "key": KEY_DELETE, "hint": "Supr", "tip": "Los quita sin muerte ni gore: vuelve a cero sin el pico"})
	actions.toggle("freeze", "Congelar enemigos", room.frozen, func(on: bool) -> void: room.set_frozen(on),
			{"key": KEY_F6, "tip": "Sin IA ni física: deja solo el costo de dibujo"})


static func _tab_spawning(room, ribbon: RibbonScript) -> void:
	ribbon.add_tab("spawning", "Aparición", "Dónde y cómo entran los enemigos")

	var where := ribbon.add_group("spawning", "Dónde")
	where.choice("zone", "Zona", room.SPAWN_ZONES, room.spawn_zone, func(i: int) -> void: room.set_spawn_zone(i),
			{"min_width": 190.0, "tip": "Área de la arena donde nacen los enemigos"})
	where.readout(func() -> String: return "Arena de %d px · el jugador está en x %d" % [
			int(room.ARENA_RIGHT - room.ARENA_LEFT), int(room.player.global_position.x) if room.player != null else 0],
			{"tip": "Largo de la arena y posición actual del jugador"})

	var how := ribbon.add_group("spawning", "Cómo")
	how.choice("per_frame", "Instanciar", _per_frame_labels(room), room.PER_FRAME.find(room.per_frame),
			func(i: int) -> void: room.set_per_frame(room.PER_FRAME[i]),
			{"min_width": 150.0, "tip": "Cuántos enemigos se crean por cuadro. 'Todos de golpe' es el peor caso"})
	how.toggle("aggro", "Aggro al aparecer", room.aggro_on_spawn, func(on: bool) -> void: room.set_aggro(on),
			{"tip": "Salen persiguiendo al jugador en vez de patrullar"})

	var loot := ribbon.add_group("spawning", "Botín")
	loot.toggle("loot", "Botín y orbes", room.loot_enabled, func(on: bool) -> void: room.set_loot(on),
			{"tip": "Si se apaga, los que aparezcan desde ahora no sueltan nada"})


static func _tab_player(room, ribbon: RibbonScript) -> void:
	ribbon.add_tab("player", "Jugador", "Estado, armas y fuego automático")

	var state := ribbon.add_group("player", "Estado")
	state.toggle("god", "Inmortal (sin empujones)", room.god_mode, func(on: bool) -> void: room.set_god_mode(on),
			{"tip": "Vida siempre llena y sin retroceso de armas ni empujones"})
	state.toggle("ammo", "Munición infinita", room.infinite_ammo, func(on: bool) -> void: room.set_infinite_ammo(on))
	state.button("Curar", room.heal_player, {"icon": "heart", "hint": "L"})

	var fire := ribbon.add_group("player", "Fuego automático")
	fire.segmented("fire", "Tiros/s", _labels(room.AUTO_FIRE_RATES, "%.0f", "Off"), room.AUTO_FIRE_RATES.find(room.auto_fire_rate),
			func(i: int) -> void: room.set_auto_fire_rate(room.AUTO_FIRE_RATES[i]),
			{"tip": "Dispara solo contra enemigos al azar: carga de proyectiles, impactos y sangre sin tener que apuntar"})
	fire.readout(func() -> String: return "Apunta a un enemigo al azar", {})


static func _tab_effects(room, ribbon: RibbonScript) -> void:
	ribbon.add_tab("effects", "Efectos", "Lluvias y estilo de los efectos")

	var sky := ribbon.add_group("effects", "Lluvia del cielo")
	sky.toggle("sky_rain", "Lluvia activa", room.sky_rain_on, func(on: bool) -> void: room.set_sky_rain(on),
			{"key": KEY_F9, "tip": "Suelta cosas desde arriba, a cada lado del jugador"})
	sky.choice("sky_kind", "Cae", room.SKY_KINDS, room.sky_kind, func(i: int) -> void: room.set_sky_kind(i),
			{"min_width": 170.0, "tip": "Lo que cae (todo pasa por el circuito real de cada efecto)"})
	sky.segmented("sky_rate", "Ritmo /s", _labels(room.SKY_RAIN_RATES, "%.0f"), room.SKY_RAIN_RATES.find(room.sky_rain_rate),
			func(i: int) -> void: room.set_sky_rain_rate(room.SKY_RAIN_RATES[i]), {"tip": "Objetos por segundo"})
	sky.column()
	sky.button("Siguiente tipo", room.next_sky_kind, {"key": KEY_F11, "tip": "Pasa al próximo tipo de la lista"})

	var weather := ribbon.add_group("effects", "Clima")
	weather.toggle("city_rain", "Lluvia de la ciudad", room.city_rain_on, func(on: bool) -> void: room.set_city_rain(on),
			{"key": KEY_F10, "tip": "Gotas que chocan con los sólidos, salpicaduras y relámpagos (como los sectores del Mundo 1)"})

	var graphics := ribbon.add_group("effects", "Gráficos")
	graphics.choice("fx_style", "Fuego/ácido", room.FX_STYLES, room.fx_style_index(),
			func(i: int) -> void: room.set_fx_style(i), {"min_width": 150.0, "tip": "Cómo se dibujan el fuego y el ácido (vale para lo que aparezca desde ahora)"})
	graphics.toggle("lod", "Enemigos lejanos como sprite", room.enemy_lod_on(),
			func(on: bool) -> void: room.set_enemy_lod(on), {"tip": "Opción 'enemy_lod': un solo sprite para los enemigos lejanos"})


static func _tab_arena(room, ribbon: RibbonScript) -> void:
	ribbon.add_tab("arena", "Arena", "Moverse por la sala y limpiarla")

	var travel := ribbon.add_group("arena", "Ir a")
	for zone: Dictionary in room.ZONES:
		var zone_x: float = float(zone["x"])
		travel.button(str(zone["name"]), func() -> void: room.teleport_to(zone_x), {
			"icon": "pin", "min_width": 120.0, "tip": "Teletransporta al jugador a x %d" % int(zone_x)})

	var marks := ribbon.add_group("arena", "Referencias")
	marks.toggle("ruler", "Regla de distancia", room.ruler_on, func(on: bool) -> void: room.set_ruler(on),
			{"tip": "Marcas cada 400 px en el piso y el nombre de cada zona"})

	var clean := ribbon.add_group("arena", "Limpieza")
	clean.button("Limpiar escombros", room.clear_debris, {
		"icon": "sweep", "key": KEY_F7, "tip": "Quita gibs, manchas, botín, orbes y números de daño"})


static func _tab_diagnostics(room, ribbon: RibbonScript) -> void:
	ribbon.add_tab("diagnostics", "Diagnóstico", "Registro de rendimiento")

	var log_group := ribbon.add_group("diagnostics", "Registro")
	log_group.button("Censo de nodos", func() -> void: room.monitor.call("log_census"), {
		"icon": "chart", "key": KEY_F8, "min_width": 160.0, "tip": "Cuenta los nodos de la escena por tipo y lo anota en el registro"})
	log_group.button("Panel de rendimiento", func() -> void: room.monitor.call("toggle_overlay"), {
		"icon": "list", "tip": "Muestra u oculta el gráfico de cuadros de arriba a la derecha"})
	log_group.button("Abrir carpeta de logs", func() -> void: room.monitor.call("open_log_folder"), {"icon": "folder"})

	var session := ribbon.add_group("diagnostics", "Sesión")
	session.big_button("Volver al\ncampamento", room.leave_room, {
		"icon": "exit", "min_width": 110.0, "tip": "Nada de lo que pasó en la sala se guarda"})


# ==============================================================================
# Barra de estado
# ==============================================================================

static func _status_bar(room, ribbon: RibbonScript) -> void:
	ribbon.add_status("st_fps", func() -> String: return "%d FPS" % int(Engine.get_frames_per_second()),
			{"min_width": 64.0, "tip": "Cuadros por segundo del juego", "color": _fps_color})
	ribbon.add_status("st_alive", func() -> String: return "Vivos %d" % room.get_tree().get_node_count_in_group(&"enemies"),
			{"min_width": 70.0})
	ribbon.add_status("st_queue", func() -> String: return "En cola %d" % room.queue_size(),
			{"min_width": 70.0, "tip": "Pedidos que esperan su turno de instanciación"})
	ribbon.add_status("st_total", func() -> String: return "Generados %d" % room.spawned_total, {"min_width": 96.0})
	ribbon.add_status("st_batch", func() -> String: return "Último lote: %d en %.1f ms" % [room.last_spawn_count, room.last_spawn_ms],
			{"min_width": 170.0, "tip": "Cuánto tardó instanciar el último cuadro de la cola"})
	ribbon.add_status("st_sky", func() -> String: return "Lluvia: %d lanzados" % room.sky_thrown, {"min_width": 120.0})
	ribbon.add_status("st_acid", func() -> String: return "Charcos de ácido %d" % room.get_tree().get_nodes_in_group(&"acid_pools").size(),
			{"min_width": 130.0})
	ribbon.add_status("st_spawner", func() -> String: return _spawner_text(room),
			{"min_width": 190.0, "color": func() -> Color: return RibbonTheme.ACCENT if room.spawner_on else RibbonTheme.TEXT_DIM})


static func _spawner_text(room) -> String:
	if not room.spawner_on:
		return "Generador apagado"
	return "Generador ON · %.0f/s · tope %d" % [room.spawn_rate, room.alive_cap]


static func _fps_color() -> Color:
	var fps: int = int(Engine.get_frames_per_second())
	if fps >= 55:
		return RibbonTheme.GOOD
	return RibbonTheme.WARN if fps >= 30 else RibbonTheme.BAD


# ==============================================================================
# Utilidades
# ==============================================================================

## Etiquetas de una lista de números ("%.0f" o "%d vivos"...). Un valor <= 0 usa `zero_label` si se da.
static func _labels(values: Array, format: String, zero_label: String = "") -> Array:
	var result: Array = []
	for value: Variant in values:
		if not zero_label.is_empty() and float(value) <= 0.0:
			result.append(zero_label)
		else:
			result.append(format % value)
	return result


static func _per_frame_labels(room) -> Array:
	var result: Array = []
	for count: int in room.PER_FRAME:
		result.append("todos de golpe" if count <= 0 else "%d por cuadro" % count)
	return result
