extends RefCounted
## Gestor de la banda sonora (carpeta `res://ost/`). Reproduce una pista a la vez con fundido cruzado.
## Sin class_name a propósito: se carga por preload desde GameFeel
## (`GameFeel.music_set_base(self, &"camp")`, `music_push`, `music_pop`, `music_set_situation`).
##
## Qué pista suena se decide por prioridad:
## 1. Anulaciones (`push` / `pop`): tienda, derrota, victoria. La última pedida gana.
## 2. Situación (`set_situation`): combate, élite o jefe. La fija el MusicDirector del nivel.
## 3. Base (`set_base`): la música de la escena (menú, campamento, exploración).
## `set_base` se llama al cargar una escena y limpia las anulaciones y la situación anteriores.
## Excepción: si una pelea terminó hace poco y la nueva escena es de exploración, la pista de pelea
## sigue sonando (ver CARRY_SECONDS) para que no se corte entre dos combates seguidos.
##
## Formato: Godot no lee .m4a, por eso las pistas están convertidas a .ogg. Si el editor todavía no
## las importó (run.bat arranca el juego sin pasar por el editor), se cargan directo del archivo.

const SfxScript = preload("res://core/sfx.gd")

## Pistas disponibles. `loop`: se repite; `db`: ajuste de volumen de esa pista.
const TRACKS: Dictionary = {
	&"menu": {"path": "res://ost/menu.ogg", "loop": true, "db": 0.0},
	&"camp": {"path": "res://ost/camp.ogg", "loop": true, "db": 0.0},
	&"shop": {"path": "res://ost/shop.ogg", "loop": true, "db": 0.0},
	&"explore": {"path": "res://ost/explore.ogg", "loop": true, "db": 0.0},
	&"combat": {"path": "res://ost/combat.ogg", "loop": true, "db": 0.0},
	&"elite": {"path": "res://ost/elite.ogg", "loop": true, "db": 0.0},
	&"boss": {"path": "res://ost/boss.ogg", "loop": true, "db": 0.0},
	# Discoteca del presente (4-7): el usuario pone el tema después; hasta entonces suena la exploración
	&"club": {"path": "res://ost/club.ogg", "loop": true, "db": 0.0},
	# Nivel 1-1 (Flow Music, "Monotonous Intro Style"). +1 dB para igualar la sonoridad de explore.ogg
	&"nivel1": {"path": "res://ost/nivel1.ogg", "loop": true, "db": 1.0},
	&"victory": {"path": "res://ost/victory.ogg", "loop": false, "db": 0.0},
	&"death": {"path": "res://ost/death.ogg", "loop": false, "db": 0.0},
}

## Volumen general de la música respecto de los efectos (dB).
const BASE_DB: float = -7.0
const SILENT_DB: float = -60.0
const FADE_IN_SECONDS: float = 1.4
const FADE_OUT_SECONDS: float = 1.0
## Segundos que la pista de pelea sigue sonando después de que termina, mientras se carga el
## siguiente nivel y sus enemigos todavía no dan la pelea. Si no aparece una nueva, vuelve la exploración.
const CARRY_SECONDS: float = 15.0

static var _host: Node = null
static var _players: Array[AudioStreamPlayer] = []
static var _active: int = 0
static var _streams: Dictionary = {}
static var _base: StringName = &""
static var _situation: StringName = &""
static var _overrides: Array[StringName] = []
static var _current: StringName = &""
static var _tween: Tween = null
## Última pista de pelea que terminó, para arrastrarla al cambiar de nivel.
static var _fight_track: StringName = &""
## Invalida los temporizadores pendientes cada vez que cambia la pelea o la escena.
static var _fight_gen: int = 0


# ==============================================================================
# API pública
# ==============================================================================

## Fija la música de la escena. Limpia anulaciones y situación previas, salvo una pelea
## que acaba de terminar y pasa a otro nivel de exploración (se mantiene CARRY_SECONDS).
static func set_base(ctx: Node, track: StringName) -> void:
	var carried: StringName = _fight_track if track == &"explore" else &""
	_fight_track = &""
	_fight_gen += 1
	_base = track
	_situation = carried
	_overrides.clear()
	if carried != &"":
		_start_timer(ctx)
	_apply(ctx)


## Fija la música de combate / élite / jefe (o vacío para volver a la base).
## Al terminar una pelea, la pista se recuerda CARRY_SECONDS por si la siguiente escena arranca enseguida.
static func set_situation(ctx: Node, track: StringName) -> void:
	_fight_gen += 1
	if track != &"":
		_fight_track = &""
	elif _situation != &"":
		_fight_track = _situation
		_start_timer(ctx)
	if _situation == track:
		return
	_situation = track
	_apply(ctx)


## Anula temporalmente la música (tienda, derrota, victoria). Se deshace con `pop`.
static func push(ctx: Node, track: StringName) -> void:
	if not _overrides.is_empty() and _overrides.back() == track:
		return
	_overrides.append(track)
	_apply(ctx)


## Quita una anulación puesta con `push`.
static func pop(ctx: Node, track: StringName) -> void:
	var idx: int = _overrides.rfind(track)
	if idx < 0:
		return
	_overrides.remove_at(idx)
	_apply(ctx)


## Silencia la música con un fundido (sin tocar base ni anulaciones).
static func stop(ctx: Node) -> void:
	_current = &""
	if ctx == null or not ctx.is_inside_tree() or not _ensure_host(ctx.get_tree()):
		return
	_fade_to(&"")


## Volumen del bus Music en escala lineal (0.0 a 1.0), para un futuro menú de opciones.
static func set_music_volume(linear: float) -> void:
	SfxScript.ensure_buses()
	var idx: int = AudioServer.get_bus_index(SfxScript.MUSIC_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


## Pista que debería estar sonando según las prioridades.
static func resolved_track() -> StringName:
	if not _overrides.is_empty():
		return _overrides.back()
	if _situation != &"":
		return _situation
	return _base


# ==============================================================================
# Reproducción
# ==============================================================================

## Programa la caducidad de la pista de pelea recordada. Si antes aparece otra pelea o cambia la escena,
## el temporizador queda invalidado por `_fight_gen`.
static func _start_timer(ctx: Node) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	var timer: SceneTreeTimer = ctx.get_tree().create_timer(CARRY_SECONDS)
	timer.timeout.connect(_on_carry_timeout.bind(_fight_gen))


static func _on_carry_timeout(gen: int) -> void:
	if gen != _fight_gen:
		return
	_fight_track = &""
	_situation = &""
	_apply(_host)


static func _apply(ctx: Node) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	if not _ensure_host(ctx.get_tree()):
		return # el estado queda guardado; al entrar el anfitrión al árbol se aplica
	var target: StringName = resolved_track()
	if target == _current:
		return
	_current = target
	_fade_to(target)


## Fundido cruzado hacia `track` (vacío = solo apagar la actual).
static func _fade_to(track: StringName) -> void:
	if _host == null or not is_instance_valid(_host) or _players.size() < 2:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var old_player: AudioStreamPlayer = _players[_active]
	var next_index: int = 1 - _active
	var new_player: AudioStreamPlayer = _players[next_index]
	new_player.stop()

	_tween = _host.create_tween()
	_tween.set_parallel(true)
	if old_player.playing:
		_tween.tween_property(old_player, "volume_db", SILENT_DB, FADE_OUT_SECONDS)
		_tween.tween_callback(old_player.stop).set_delay(FADE_OUT_SECONDS)

	if track == &"":
		return
	var stream: AudioStream = _get_stream(track)
	if stream == null:
		push_warning("[Music] No se pudo cargar la pista '%s'." % String(track))
		return
	var info: Dictionary = TRACKS[track] as Dictionary
	new_player.stream = stream
	new_player.volume_db = SILENT_DB
	new_player.play()
	_tween.tween_property(new_player, "volume_db", BASE_DB + float(info["db"]), FADE_IN_SECONDS)
	_active = next_index


static func _get_stream(track: StringName) -> AudioStream:
	if _streams.has(track):
		return _streams[track] as AudioStream
	if not TRACKS.has(track):
		return null
	var info: Dictionary = TRACKS[track] as Dictionary
	var path: String = String(info["path"])
	var stream: AudioStream = null
	# Importada por el editor: carga normal. Si no, se lee el .ogg directo del archivo.
	if FileAccess.file_exists(path + ".import"):
		stream = load(path) as AudioStream
	if stream == null and FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = bool(info["loop"])
	if stream != null:
		_streams[track] = stream
	return stream


## Crea el anfitrión (dos reproductores para el fundido cruzado) colgado de la raíz.
## Devuelve true si ya está dentro del árbol.
static func _ensure_host(tree: SceneTree) -> bool:
	if _host != null and is_instance_valid(_host):
		return _host.is_inside_tree()
	if tree == null or tree.root == null:
		return false
	SfxScript.ensure_buses()
	_host = Node.new()
	_host.name = "MusicHost"
	_host.process_mode = Node.PROCESS_MODE_ALWAYS
	_players.clear()
	_active = 0
	for i in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SfxScript.MUSIC_BUS
		_host.add_child(player)
		_players.append(player)
	_host.ready.connect(_on_host_ready)
	tree.root.add_child.call_deferred(_host)
	return false


static func _on_host_ready() -> void:
	_current = &""
	_apply(_host)
