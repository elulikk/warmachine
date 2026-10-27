extends CanvasLayer
## Gunther habla solo mientras avanza: frases cortas como subtítulo abajo al centro, sin cortar el juego.
## Salen al pasar por puntos del nivel, al ver por primera vez un tipo de enemigo (si no está hablando) y en eventos
## (arena, checkpoint, vida baja, racha de bajas, reaparecer, quedarse quieto, jefe).
## Las frases están en `data/dialogue/gunther_lines.gd`; la voz se suma sola si existe `assets/voice/gunther/<id>.ogg`.
## Lo crea LevelBase en todos los niveles; sin frases para ese nivel solo quedan los eventos.
## Sin class_name a propósito: se carga por preload.

const Lines = preload("res://data/dialogue/gunther_lines.gd")
const CinematicPlayerScript = preload("res://core/cinematics/cinematic_player.gd")
const SfxScript = preload("res://core/sfx.gd")

const VOICE_PATH: String = "res://assets/voice/gunther/%s.ogg"
## Segundos mínimos sin hablar antes de una frase de evento (los puntos y el jefe no esperan).
const CHATTER_GAP: float = 6.0
## Pausa entre dos frases encoladas.
const QUEUE_GAP: float = 0.5
const MAX_QUEUE: int = 3
const SCAN_INTERVAL: float = 0.3
## Margen (px de pantalla) para contar a un enemigo como "visto": tiene que estar bien adentro de la vista.
const SIGHT_MARGIN: float = 60.0
const STREAK_KILLS: int = 5
const STREAK_WINDOW: float = 4.0
const LOW_HEALTH_RATIO: float = 0.3
const IDLE_SECONDS: float = 25.0
const FADE_IN: float = 0.15
const FADE_OUT: float = 0.35

var level_id: String = ""

var _player: Node2D = null
var _label: Label
var _voice: AudioStreamPlayer
## Puntos pendientes del nivel: [{id, text, x?, y?}].
var _points: Array = []
var _level_events: Dictionary = {}
var _seen_kinds: Dictionary = {}
var _queue: Array = []
var _line_left: float = 0.0
var _line_total: float = 0.0
var _queue_wait: float = 0.0
var _quiet: float = 0.0
var _cooldowns: Dictionary = {}
var _last_id: Dictionary = {}
var _scan_left: float = 0.0
var _time: float = 0.0
var _kill_times: Array[float] = []
var _last_kills: int = -1
var _was_low: bool = false
var _dead: bool = false
var _idle: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _boss_seen: bool = false
var _checkpoints_done: Dictionary = {}
var _hooked: bool = false


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 0.8
	_label.anchor_bottom = 0.8
	_label.offset_left = -460.0
	_label.offset_right = 460.0
	_label.offset_top = -60.0
	_label.offset_bottom = 0.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)
	_voice = AudioStreamPlayer.new()
	_voice.bus = SfxScript.SFX_BUS
	add_child(_voice)
	_hook.call_deferred()


## Engancha señales del nivel un cuadro después (el punto de reanudación ya movió al jugador).
func _hook() -> void:
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var level: Node = get_parent()
	_player = get_tree().get_first_node_in_group(&"player") as Node2D
	var data: Dictionary = Lines.NIVELES.get(level_id, {})
	_level_events = data.get("eventos", {})
	var points: Dictionary = data.get("puntos", {})
	for id: String in points:
		var pt: Dictionary = (points[id] as Dictionary).duplicate()
		pt["id"] = id
		# Arrancando desde un checkpoint, lo que quedó atrás no se dice
		if _player != null and _passed(pt, _player.global_position) and not _is_start_line(pt):
			continue
		_points.append(pt)
	for node: Node in level.get_children():
		if node.has_signal("encounter_started"):
			node.connect("encounter_started", _event.bind("arena_inicio"))
			node.connect("encounter_cleared", _event.bind("arena_limpia"))
		if node.has_signal("checkpoint_activated"):
			node.connect("checkpoint_activated", _on_checkpoint)
	if _player != null:
		_last_pos = _player.global_position
		if _player.has_signal("died"):
			_player.connect("died", _on_player_died)
		var stats: Object = _player.get("stats_manager")
		if stats != null and stats.has_signal("health_changed"):
			stats.connect("health_changed", _on_health_changed)
	var metrics: MetricsManager = MetricsManager.get_instance()
	if metrics != null:
		_last_kills = metrics.total_enemies_killed
		metrics.metrics_updated.connect(_on_metrics)
	_hooked = true


## La primera frase del nivel (antes del spawn) sale igual aunque se arranque de cero.
func _is_start_line(pt: Dictionary) -> bool:
	return pt.has("x") and not pt.has("y") and float(pt["x"]) < 400.0 and _player.global_position.x < 400.0


func _passed(pt: Dictionary, pos: Vector2) -> bool:
	if pt.has("x") and pos.x < float(pt["x"]):
		return false
	if pt.has("y") and pos.y > float(pt["y"]):
		return false
	return true


func _process(delta: float) -> void:
	# Pausa o cinemática: el subtítulo se esconde y todo espera
	if get_tree().paused or CinematicPlayerScript.active:
		_label.visible = false
		if _voice.playing:
			_voice.stream_paused = true
		return
	_label.visible = true
	_voice.stream_paused = false
	_time += delta
	_quiet += delta
	for key: Variant in _cooldowns.keys():
		_cooldowns[key] = float(_cooldowns[key]) - delta
	_update_line(delta)
	if not _hooked or _player == null or not is_instance_valid(_player):
		return
	var pos: Vector2 = _player.global_position
	for i: int in range(_points.size() - 1, -1, -1):
		var pt: Dictionary = _points[i]
		if _passed(pt, pos):
			_points.remove_at(i)
			say(str(pt["id"]), str(pt["text"]), true)
	if pos.distance_to(_last_pos) > 4.0:
		_idle = 0.0
		_last_pos = pos
	elif not _dead:
		_idle += delta
		if _idle >= IDLE_SECONDS:
			_idle = -INF  # una vez por cada vez que se queda quieto
			_event("quieto")
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = SCAN_INTERVAL
		_scan_enemies()


func _update_line(delta: float) -> void:
	if _line_left > 0.0:
		_line_left -= delta
		var shown: float = _line_total - _line_left
		_label.modulate.a = clampf(minf(shown / FADE_IN, _line_left / FADE_OUT), 0.0, 1.0)
		if _line_left <= 0.0:
			_label.modulate.a = 0.0
			_queue_wait = QUEUE_GAP
			_quiet = 0.0
		return
	if _queue.is_empty():
		return
	_queue_wait -= delta
	if _queue_wait > 0.0:
		return
	var next: Array = _queue.pop_front()
	_show(str(next[0]), str(next[1]))


## Dice una frase. `important` = de un punto o del jefe: se encola aunque esté hablando.
## Las de evento se descartan si está hablando o habló hace poco.
func say(id: String, text: String, important: bool = false) -> void:
	if important:
		if _queue.size() < MAX_QUEUE:
			_queue.append([id, text])
		return
	if not _can_chat():
		return
	_queue.append([id, text])


## Callado hace rato y sin nada encolado: puede soltar una frase de evento o de avistamiento.
func _can_chat() -> bool:
	return _line_left <= 0.0 and _queue.is_empty() and _quiet >= CHATTER_GAP


func _show(id: String, text: String) -> void:
	_label.text = text
	var seconds: float = clampf(float(text.length()) * 0.06 + 1.6, 2.4, 6.5)
	var path: String = VOICE_PATH % id
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path) as AudioStream
		if stream != null:
			_voice.stream = stream
			_voice.play()
			seconds = maxf(seconds, stream.get_length() + 0.3)
	_line_total = seconds
	_line_left = seconds


func _hush() -> void:
	_queue.clear()
	_line_left = 0.0
	_label.modulate.a = 0.0
	_voice.stop()


## Frase de un evento: respeta la probabilidad y la espera de REGLAS, y no repite la última.
func _event(event: String, important: bool = false) -> void:
	var rule: Array = Lines.REGLAS.get(event, [1.0, 0.0])
	if float(_cooldowns.get(event, 0.0)) > 0.0 or randf() > float(rule[0]):
		return
	var options: Dictionary = _level_events.get(event, Lines.EVENTOS.get(event, {}))
	var id: String = _pick(options, str(_last_id.get(event, "")))
	if id.is_empty():
		return
	if not important and not _can_chat():
		return  # no consume la espera si no llegó a hablar
	_cooldowns[event] = float(rule[1])
	_last_id[event] = id
	say(id, str(options[id]), important)


func _pick(options: Dictionary, avoid: String) -> String:
	var ids: Array = options.keys()
	if ids.size() > 1:
		ids.erase(avoid)
	return "" if ids.is_empty() else str(ids.pick_random())


## Enemigos en pantalla: el primero de cada tipo en el nivel y el jefe.
func _scan_enemies() -> void:
	var view: Rect2 = get_viewport().get_visible_rect().grow(-SIGHT_MARGIN)
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or enemy.is_queued_for_deletion() or not view.has_point(canvas * enemy.global_position):
			continue
		if enemy.is_in_group(&"boss"):
			if not _boss_seen:
				_boss_seen = true
				_event("jefe_visto", true)
				if enemy.has_signal("died"):
					enemy.connect("died", _event.bind("jefe_caido", true), CONNECT_ONE_SHOT)
			continue
		var kind: String = str(enemy.get("entity_name"))
		# Si está hablando, el avistamiento espera (sigue en pantalla en el próximo barrido)
		if _seen_kinds.has(kind) or not Lines.AL_VER.has(kind) or not _can_chat():
			continue
		_seen_kinds[kind] = true
		var options: Dictionary = Lines.AL_VER[kind]
		var id: String = _pick(options, "")
		say(id, str(options[id]))


func _on_checkpoint(checkpoint_id: String) -> void:
	if _checkpoints_done.has(checkpoint_id):
		return
	_checkpoints_done[checkpoint_id] = true
	_event("checkpoint")


func _on_metrics() -> void:
	var metrics: MetricsManager = MetricsManager.get_instance()
	if metrics == null or metrics.total_enemies_killed <= _last_kills:
		return
	for i: int in mini(metrics.total_enemies_killed - _last_kills, STREAK_KILLS):
		_kill_times.append(_time)
	_last_kills = metrics.total_enemies_killed
	while not _kill_times.is_empty() and _time - _kill_times[0] > STREAK_WINDOW:
		_kill_times.pop_front()
	if _kill_times.size() >= STREAK_KILLS:
		_kill_times.clear()
		_event("racha")


func _on_health_changed(current: float, max_health: float) -> void:
	if max_health <= 0.0:
		return
	var ratio: float = current / max_health
	if _dead:
		if ratio >= 0.99:
			_dead = false
			_event("reaparece", true)
		return
	if ratio < LOW_HEALTH_RATIO and current > 0.0 and not _was_low:
		_was_low = true
		_event("vida_baja")
	elif ratio > 0.5:
		_was_low = false


func _on_player_died() -> void:
	_dead = true
	_was_low = false
	_hush()
