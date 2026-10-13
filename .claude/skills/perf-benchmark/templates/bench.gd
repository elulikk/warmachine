extends Node
## Plantilla de benchmark (descartable). Copiar a la raíz del proyecto como `_x.gd`, crear `_x.tscn` con un
## `Node` que la use y BORRAR ambos al terminar. Un proceso por combinación (ver skill perf-benchmark).
##
## Variables de entorno: BENCH_TYPE (0-5), BENCH_CAP, BENCH_RATE, BENCH_FIRE, BENCH_SECONDS.
## Salida: una línea `XT ...` con FPS promedio, mínimo y p1 (percentil 1 más bajo).

const STRESS: PackedScene = preload("res://scenes/hub/stress_room.tscn")
const WARMUP_SECONDS: float = 2.0

var _room: Node = null
var _elapsed: float = 0.0
var _measure_seconds: float = 10.0
var _samples: PackedFloat32Array = PackedFloat32Array()
var _started: bool = false


func _env_float(key: String, fallback: float) -> float:
	var value: String = OS.get_environment(key)
	return value.to_float() if not value.is_empty() else fallback


func _ready() -> void:
	# Sin esto todo da 60 fps y no se ve el margen real
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_measure_seconds = _env_float("BENCH_SECONDS", 10.0)
	_room = STRESS.instantiate()
	add_child(_room)
	await get_tree().create_timer(1.0).timeout
	_room.set("enemy_type", int(_env_float("BENCH_TYPE", 5.0)))
	_room.set("alive_cap", int(_env_float("BENCH_CAP", 100.0)))
	_room.set("spawn_rate", _env_float("BENCH_RATE", 20.0))
	_room.set("auto_fire_rate", _env_float("BENCH_FIRE", 15.0))
	_room.call("_set_spawner", true)
	_started = true


func _process(delta: float) -> void:
	if not _started:
		return
	_elapsed += delta
	if _elapsed < WARMUP_SECONDS:
		return
	_samples.append(1.0 / maxf(delta, 0.00001))
	if _elapsed >= WARMUP_SECONDS + _measure_seconds:
		_report()
		get_tree().quit()


func _report() -> void:
	var sorted: PackedFloat32Array = _samples.duplicate()
	sorted.sort()
	var total: float = 0.0
	for s: float in sorted:
		total += s
	var count: int = sorted.size()
	if count == 0:
		print("XT sin muestras")
		return
	var p1: float = sorted[int(count * 0.01)]
	print("XT fps_prom=%.1f fps_min=%.1f fps_p1=%.1f muestras=%d tipo=%s cap=%s rate=%s fuego=%s" % [
		total / float(count), sorted[0], p1, count,
		OS.get_environment("BENCH_TYPE"), OS.get_environment("BENCH_CAP"),
		OS.get_environment("BENCH_RATE"), OS.get_environment("BENCH_FIRE")])
