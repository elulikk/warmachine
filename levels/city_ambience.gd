extends Node
## Ambiente sonoro de la ciudad (capítulo 1, El Presente), en exteriores.
## Dos capas, todas lejanas: loops de fondo (murmullo de gente, tráfico) y eventos sueltos que suenan
## cada tanto (un auto que pasa, un bocinazo, un gato, un ladrido).
## Sin class_name: lo crea LevelBase (`preload`). Si un archivo todavía no está en `assets/audio/ambiente/`,
## se omite: el nivel funciona igual, sin audio de ambiente.

const SfxScript = preload("res://core/sfx.gd")

const DIR: String = "res://assets/audio/ambiente/"
## Loops de fondo que suenan todo el tiempo. `db`: volumen de esa capa.
const LOOPS: Array[Dictionary] = [
	{"file": "amb_murmullo_lejano.mp3", "db": -16.0},
	{"file": "amb_trafico_fondo.mp3", "db": -18.0},
]
## Eventos sueltos. `files`: variantes (se elige una al azar); `db`: volumen del evento.
const EVENTS: Array[Dictionary] = [
	{"files": ["evt_auto_pasa.mp3"], "db": -14.0},
	{"files": ["evt_bocinazo.mp3"], "db": -16.0},
	{"files": ["evt_gato_maullido.mp3"], "db": -18.0},
	{"files": ["evt_ladrido.mp3"], "db": -17.0},
]
## Tiempo entre un evento y el siguiente, en segundos.
const EVENT_MIN_SECONDS: float = 9.0
const EVENT_MAX_SECONDS: float = 22.0

## Eventos cuyo archivo sí existe: { "streams": Array[AudioStream], "db": float }.
var _event_pool: Array[Dictionary] = []
var _timer: Timer = null


func _ready() -> void:
	SfxScript.ensure_buses()
	for entry: Dictionary in LOOPS:
		var stream: AudioStream = _load_stream(DIR + String(entry["file"]))
		if stream == null:
			continue
		stream.set("loop", true)
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = float(entry["db"])
		player.bus = SfxScript.SFX_BUS
		add_child(player)
		player.play()

	for entry: Dictionary in EVENTS:
		var streams: Array[AudioStream] = []
		for file: String in entry["files"]:
			var stream: AudioStream = _load_stream(DIR + file)
			if stream != null:
				streams.append(stream)
		if not streams.is_empty():
			_event_pool.append({"streams": streams, "db": float(entry["db"])})

	if not _event_pool.is_empty():
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.timeout.connect(_on_event_timeout)
		add_child(_timer)
		_schedule_event()


## Espera un tiempo al azar y vuelve a armar el próximo evento.
func _schedule_event() -> void:
	_timer.start(randf_range(EVENT_MIN_SECONDS, EVENT_MAX_SECONDS))


func _on_event_timeout() -> void:
	var pick: Dictionary = _event_pool.pick_random()
	var streams: Array[AudioStream] = pick["streams"]
	SfxScript.play_stream(self, streams.pick_random(), &"amb_evento", Vector2.INF, float(pick["db"]), randf_range(0.92, 1.08))
	_schedule_event()


## Carga un audio de la carpeta de ambiente. Si el editor no lo importó (run.bat arranca sin pasar por él),
## lee el .mp3 directo del archivo, igual que core/music.gd con los .ogg.
static func _load_stream(path: String) -> AudioStream:
	if FileAccess.file_exists(path + ".import"):
		var stream: AudioStream = load(path) as AudioStream
		if stream != null:
			return stream
	if FileAccess.file_exists(path):
		return AudioStreamMP3.load_from_file(path)
	return null
