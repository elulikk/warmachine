extends Node2D
## Banco de Cinemáticas: al entrar se reproducen solas, una atrás de otra y en bucle, situaciones de cinemática
## (diálogo, cámara, actores, pantalla, paralelo, robustez, estrés) para ver cómo funciona y cómo se ve el motor
## (core/cinematics/) sin jugar el juego. Cada corrida anota su duración y el costo por cuadro.
## Sin class_name a propósito (ver class-name-cache-gotcha). No guarda nada.
##
## Teclas: 1-7 salta a esa situación · 9 pausa/reanuda la cadena · F4 muestra/oculta el panel.
## Durante la cinemática valen los controles de siempre: [Enter] avanza, [Esc] o mantener [R] la salta (sigue la próxima).
## Para sumar una situación: escribir `_demo_<nombre>() -> Array` y agregarla a `_demos`.

const LevelSkinScript = preload("res://levels/level_skin.gd")
const Cine = preload("res://core/cinematics/cinematic_player.gd")

const ARENA_LEFT: float = 0.0
const ARENA_RIGHT: float = 3200.0
const FLOOR_TOP: float = 536.0
const PLAYER_START: Vector2 = Vector2(1600.0, 520.0)
## Actores de la demo de estrés.
const STRESS_ACTORS: int = 120
## Respiro entre una situación y la siguiente, y antes de la primera.
const GAP_SECONDS: float = 1.0
const START_DELAY: float = 0.8
const MOBS: Array[String] = [
	"mob_thug.png", "mob_rat.png", "mob_thief.png", "mob_gunman.png", "mob_bouncer.png",
	"mob_hitman_smg.png", "mob_hitman_elite.png", "mob_time_agent.png",
]

@onready var player: Node2D = $Player

var _demos: Array[Dictionary] = []
var _ui: CanvasLayer
var _panel: PanelContainer
var _results: Label
var _auto: bool = false
var _show_panel: bool = true
var _auto_runs: int = 0
var _running: String = ""
var _t0: int = 0
var _frames: int = 0
var _sum_ms: float = 0.0
var _worst_ms: float = 0.0
var _last_tick: int = 0


func _ready() -> void:
	SaveManager.saving_suspended = true
	_build_arena()
	LevelSkinScript.apply(self, 0)
	get_tree().paused = false
	if GameManager != null:
		GameManager.current_state = GameManager.GameState.PLAYING
	if player != null:
		player.global_position = PLAYER_START
		player.set("invulnerable", true)
		var hud: Node = get_node_or_null("HUD")
		if hud != null and hud.has_method("setup_with_player"):
			hud.call("setup_with_player", player)
	SaveManager.set_respawn_point(PLAYER_START)
	# Mide con la señal de cuadro del árbol: sigue llegando aunque la cinemática pause el juego
	get_tree().process_frame.connect(_measure)
	_demos = [
		{"name": "Diálogo", "build": _demo_dialogue},
		{"name": "Cámara", "build": _demo_camera},
		{"name": "Actores", "build": _demo_actors},
		{"name": "Pantalla", "build": _demo_screen},
		{"name": "Paralelo", "build": _demo_parallel},
		{"name": "Robustez", "build": _demo_robust},
		{"name": "Estrés (%d actores)" % STRESS_ACTORS, "build": _demo_stress},
	]
	_build_panel()
	print("[CineBench] Banco de Cinemáticas listo: la cadena arranca sola. 1-7 salta, 9 pausa, F4 panel.")
	_auto = true
	_report("Cadena automática ENCENDIDA (9 la pausa)")
	await get_tree().create_timer(START_DELAY).timeout
	_launch(0)


func _exit_tree() -> void:
	SaveManager.saving_suspended = false


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = (event as InputEventKey).keycode
	if key == KEY_F4:
		_show_panel = not _show_panel
		_panel.visible = _show_panel
	elif key == KEY_9:
		_toggle_auto()
	elif key >= KEY_1 and key < KEY_1 + _demos.size():
		_launch(int(key - KEY_1))
	else:
		return
	get_viewport().set_input_as_handled()


func _measure() -> void:
	if _running.is_empty():
		return
	# Tiempo real entre cuadros (el delta del juego no sirve: puede estar en pausa)
	var now: int = Time.get_ticks_usec()
	if _last_tick > 0:
		var ms: float = float(now - _last_tick) / 1000.0
		_frames += 1
		_sum_ms += ms
		_worst_ms = maxf(_worst_ms, ms)
	_last_tick = now


# ==============================================================================
# Lanzar y medir
# ==============================================================================

func _launch(index: int) -> void:
	if index < 0 or index >= _demos.size() or Cine.active:
		return
	if player != null:
		player.global_position = PLAYER_START
	var demo: Dictionary = _demos[index]
	var steps: Array = (demo["build"] as Callable).call() as Array
	var problems: PackedStringArray = Cine.validate(steps)
	_running = str(demo["name"])
	_t0 = Time.get_ticks_msec()
	_frames = 0
	_sum_ms = 0.0
	_worst_ms = 0.0
	_last_tick = 0
	_panel.visible = false  # que se vea la cinemática limpia; vuelve al terminar
	var node: Node = Cine.play(self, steps, _on_done.bind(index, problems.size()))
	if node == null:
		_running = ""
		_report("No arrancó: %s" % str(demo["name"]))


func _on_done(index: int, problems: int) -> void:
	var name_: String = _running
	_running = ""
	var secs: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var avg: float = _sum_ms / maxf(float(_frames), 1.0)
	var line: String = "%s: %.2f s · %d cuadros · prom %.2f ms (%.0f FPS) · peor %.2f ms · avisos de validación %d · pausa=%s" % [
		name_, secs, _frames, avg, 1000.0 / maxf(avg, 0.001), _worst_ms, problems, str(get_tree().paused)]
	print("[CineBench] " + line)
	_report(line)
	_panel.visible = _show_panel
	_auto_runs += 1
	if not _auto:
		return
	await get_tree().create_timer(GAP_SECONDS).timeout
	if _auto and not Cine.active and is_inside_tree():
		_launch((index + 1) % _demos.size())


func _toggle_auto() -> void:
	_auto = not _auto
	_report("Cadena automática: %s" % ("ENCENDIDA" if _auto else "en pausa tras %d corridas (9 la reanuda)" % _auto_runs))
	if _auto and not Cine.active:
		_launch(0)


func _report(line: String) -> void:
	var lines: PackedStringArray = _results.text.split("\n", false)
	lines.append(line)
	while lines.size() > 12:
		lines.remove_at(0)
	_results.text = "\n".join(lines)


# ==============================================================================
# Demos (cada una devuelve una lista de pasos)
# ==============================================================================

func _ground(dx: float) -> Vector2:
	return Vector2(PLAYER_START.x + dx, FLOOR_TOP)


## Plano y contraplano: la cámara va a la cabeza de quien habla y solo se ve el subtítulo.
func _demo_dialogue() -> Array:
	return [
		{"t": "spawn", "id": "agente", "file": "time_agent.png", "pos": _ground(140), "h": 84.0},
		{"t": "focus", "pos": _ground(70) + Vector2(0, -50), "zoom": 1.6, "s": 0.8},
		{"t": "dialogue", "cast": {"GUNTHER": "player", "AGENTE": "agente"}},
		{"t": "say", "who": "GUNTHER", "text": "¿Quién te mandó?"},
		{"t": "say", "who": "AGENTE", "text": "Nadie que vos puedas conocer. Todavía."},
		{"t": "say", "who": "GUNTHER", "text": "Doce años buscando esa voz.", "thought": true},
		{"t": "say", "who": "AGENTE", "text": "Corte directo, sin deslizar la cámara.", "cut": true},
		{"t": "say", "who": "GUNTHER", "text": "Y esta, más cerca todavía.", "zoom": 7.0},
		{"t": "say", "who": "NARRADOR", "text": "Una voz sin actor: subtítulo y la cámara se queda quieta.", "s": 3.0},
		{"t": "remove", "id": "agente"},
		{"t": "release", "s": 0.6},
	]


func _demo_camera() -> Array:
	return [
		{"t": "focus", "pos": _ground(-600) + Vector2(0, -120), "zoom": 0.8, "s": 1.0},
		{"t": "focus", "pos": _ground(600) + Vector2(0, -60), "zoom": 1.6, "s": 1.0},
		{"t": "shake", "amp": 8.0, "s": 0.5},
		{"t": "focus", "id": "player", "zoom": 2.0, "s": 0.8},
		{"t": "wait", "s": 0.4},
		{"t": "release", "s": 0.8},
	]


func _demo_actors() -> Array:
	return [
		{"t": "focus", "pos": _ground(0) + Vector2(0, -80), "zoom": 1.1, "s": 0.6},
		{"t": "spawn", "id": "a", "file": "time_agent.png", "pos": _ground(-500), "h": 66.0},
		{"t": "spawn", "id": "b", "file": "mob_thug.png", "pos": _ground(500), "h": 64.0, "flip": true},
		{"t": "spawn", "id": "heli", "file": "helicopter.png", "pos": _ground(-900) + Vector2(0, -320), "h": 150.0, "flip": true},
		{"t": "par", "steps": [
			{"t": "move", "id": "a", "to": _ground(-120), "s": 1.4},
			{"t": "move", "id": "b", "to": _ground(120), "s": 1.4},
			{"t": "move", "id": "heli", "to": _ground(0) + Vector2(0, -260), "s": 2.0},
			{"t": "shake", "amp": 2.0, "s": 2.0},
		]},
		{"t": "move", "id": "player", "to": PLAYER_START + Vector2(0, -60), "s": 0.4},
		{"t": "move", "id": "player", "to": PLAYER_START, "s": 0.3},
		{"t": "par", "steps": [
			{"t": "move", "id": "heli", "to": _ground(1200) + Vector2(0, -420), "s": 1.6},
			{"t": "move", "id": "a", "to": _ground(-900), "s": 1.2},
			{"t": "move", "id": "b", "to": _ground(900), "s": 1.2},
		]},
		{"t": "remove", "id": "a"},
		{"t": "remove", "id": "b"},
		{"t": "remove", "id": "heli"},
		{"t": "release", "s": 0.5},
	]


func _demo_screen() -> Array:
	return [
		{"t": "fade", "to": 1.0, "s": 0.5},
		{"t": "bg", "file": "city_houses.jpg"},
		{"t": "fade", "to": 0.0, "s": 0.8},
		{"t": "show", "id": "s1", "file": "gunther_full.png", "x": 0.3, "y": 0.86, "h": 0.5},
		{"t": "show", "id": "s2", "file": "time_agent.png", "x": 0.72, "y": 0.62, "h": 0.32, "tint": Color(0.04, 0.04, 0.06)},
		{"t": "title", "text": "BANCO DE CINEMÁTICAS", "s": 1.2},
		{"t": "flash", "s": 0.4},
		{"t": "flash", "s": 0.6, "color": Color(1.0, 0.2, 0.1)},
		{"t": "hide", "id": "s2"},
		{"t": "bg", "file": "box_corridor.jpg"},
		{"t": "wait", "s": 0.8},
		{"t": "hide", "id": "s1"},
		{"t": "fade", "to": 1.0, "s": 0.5},
		{"t": "bg", "file": ""},
		{"t": "fade", "to": 0.0, "s": 0.5},
	]


func _demo_parallel() -> Array:
	return [
		{"t": "spawn", "id": "a", "file": "mob_rat.png", "pos": _ground(-400), "h": 40.0},
		{"t": "par", "steps": [
			{"t": "seq", "steps": [
				{"t": "move", "id": "a", "to": _ground(-100), "s": 0.8},
				{"t": "move", "id": "a", "to": _ground(-300), "s": 0.8},
				{"t": "move", "id": "a", "to": _ground(-50), "s": 0.6},
			]},
			{"t": "seq", "steps": [
				{"t": "say", "who": "GUNTHER", "text": "Hablo mientras la rata va y viene.", "s": 1.4},
				{"t": "say", "who": "GUNTHER", "text": "Y la cámara se mueve a la vez.", "s": 1.2},
			]},
			{"t": "focus", "pos": _ground(-200) + Vector2(0, -60), "zoom": 1.5, "s": 2.2},
		]},
		{"t": "remove", "id": "a"},
		{"t": "release", "s": 0.5},
	]


## Pasos rotos a propósito: la cinemática tiene que avisar, saltearlos y terminar igual.
func _demo_robust() -> Array:
	var hang: Callable = func() -> void:
		await get_tree().create_timer(3600.0, true).timeout
	return [
		{"t": "say", "who": "NARRADOR", "text": "Vienen pasos rotos. Tiene que seguir igual.", "s": 1.6},
		{"t": "no_existe"},
		{"x": "sin tipo"},
		"no soy un diccionario",
		{"t": "move", "id": "fantasma", "to": _ground(0), "s": 1.0},
		{"t": "move", "id": "player"},
		{"t": "spawn", "id": "x", "file": "no_existe.png", "pos": _ground(0)},
		{"t": "call", "fn": hang, "timeout": 1.0},
		{"t": "par", "steps": [{"t": "call", "fn": hang}, {"t": "wait", "s": 0.3}], "timeout": 1.0},
		{"t": "say", "who": "NARRADOR", "text": "Llegué al final: el motor aguantó.", "s": 1.6},
	]


func _demo_stress() -> Array:
	var spawns: Array = []
	var moves: Array = []
	for i: int in STRESS_ACTORS:
		var id: String = "m%d" % i
		var x: float = -1400.0 + float(i % 40) * 70.0
		var lift: float = -float(i / 40) * 60.0
		spawns.append({"t": "spawn", "id": id, "file": MOBS[i % MOBS.size()], "pos": _ground(x) + Vector2(0, lift), "h": 56.0, "flip": i % 2 == 1})
		moves.append({"t": "seq", "steps": [
			{"t": "move", "id": id, "to": _ground(-x * 0.5) + Vector2(0, lift), "s": 1.2 + float(i % 7) * 0.15},
			{"t": "move", "id": id, "to": _ground(x) + Vector2(0, lift), "s": 1.0},
		]})
	var removes: Array = []
	for i: int in STRESS_ACTORS:
		removes.append({"t": "remove", "id": "m%d" % i})
	var parallel: Array = moves.duplicate()
	parallel.append({"t": "shake", "amp": 3.0, "s": 2.0})
	parallel.append({"t": "say", "who": "GUNTHER", "text": "%d actores moviéndose a la vez." % STRESS_ACTORS, "s": 2.0})
	parallel.append({"t": "focus", "pos": _ground(0) + Vector2(0, -100), "zoom": 0.7, "s": 1.0})
	var steps: Array = []
	steps.append({"t": "seq", "steps": spawns})
	steps.append({"t": "par", "steps": parallel})
	steps.append({"t": "seq", "steps": removes})
	steps.append({"t": "release", "s": 0.5})
	return steps



# ==============================================================================
# Escenario y panel
# ==============================================================================

func _build_arena() -> void:
	var environment: Node2D = Node2D.new()
	environment.name = "Environment"
	add_child(environment)
	move_child(environment, 0)
	var width: float = ARENA_RIGHT - ARENA_LEFT
	_add_block(environment, "MainFloor", Rect2(ARENA_LEFT - 40.0, FLOOR_TOP, width + 80.0, 48.0))
	_add_block(environment, "LeftWall", Rect2(ARENA_LEFT - 80.0, -500.0, 80.0, 1084.0))
	_add_block(environment, "RightWall", Rect2(ARENA_RIGHT, -500.0, 80.0, 1084.0))


## Bloque sólido al estilo de los niveles para que LevelSkin lo revista (igual que la Sala de Estrés).
func _add_block(parent: Node2D, block_name: String, rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = block_name
	body.add_to_group(&"world")
	body.collision_mask = 0
	body.position = rect.get_center()
	parent.add_child(body)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	var color_rect: ColorRect = ColorRect.new()
	color_rect.name = "ColorRect"
	color_rect.color = Color(0.14, 0.12, 0.13, 1.0)
	color_rect.position = -rect.size * 0.5
	color_rect.size = rect.size
	body.add_child(color_rect)
	var border: ColorRect = ColorRect.new()
	border.name = "TopBorder"
	border.color = Color(0.85, 0.45, 0.2, 1.0)
	border.position = -rect.size * 0.5
	border.size = Vector2(rect.size.x, 3.0)
	body.add_child(border)


func _build_panel() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 50
	add_child(_ui)
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.07, 0.85)
	style.border_color = Color(0.85, 0.45, 0.2, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_ui.add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panel.add_child(col)
	var title: Label = Label.new()
	title.text = "BANCO DE CINEMÁTICAS  ·  F4 oculta"
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	col.add_child(title)
	for i: int in _demos.size():
		var button: Button = Button.new()
		button.text = "%d  %s" % [i + 1, str(_demos[i]["name"])]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_launch.bind(i))
		col.add_child(button)
	var auto: Button = Button.new()
	auto.text = "9  Pausar / reanudar la cadena"
	auto.alignment = HORIZONTAL_ALIGNMENT_LEFT
	auto.focus_mode = Control.FOCUS_NONE
	auto.pressed.connect(_toggle_auto)
	col.add_child(auto)
	_results = Label.new()
	_results.custom_minimum_size = Vector2(620, 0)
	_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results.add_theme_font_size_override("font_size", 11)
	col.add_child(_results)
