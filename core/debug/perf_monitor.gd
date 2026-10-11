extends Node
## Monitor de rendimiento en pantalla + registro a disco para optimizar.
## Sin class_name a propósito: se carga por `preload` (ver class-name-cache-gotcha).
##
## - Panel arriba a la derecha (capa 120): FPS, 1% bajo, tiempo de cuadro (CPU de proceso, física y GPU),
##   llamadas de dibujo, memoria, nodos, física 2D y un censo del juego (enemigos, proyectiles del pool,
##   gibs, manchas, botín, orbes, números de daño, partículas). Debajo, el gráfico de los últimos 240 cuadros
##   con líneas de 60 y 30 FPS.
## - Si `log_to_disk`, escribe en `user://logs/rendimiento/<tag>_<fecha>.csv` una muestra cada 0.5 s y en
##   `<tag>_<fecha>.txt` los eventos (lo que avise la escena con `log_event()`, los picos de más de 50 ms
##   y el censo de nodos). Al cerrarse agrega un resumen: FPS por cantidad de enemigos, percentiles y peores
##   cuadros. Los archivos se vacían a disco en cada muestra, así que sobreviven a un cierre forzado.
## - `context_provider` (Callable que devuelve String) agrega el estado de la escena a cada fila y a cada pico.
## - La Sala de Estrés lo crea fijo (`persistent`); en el resto del juego F9 lo agrega o lo quita (GameManager).

const SettingsScript = preload("res://core/settings.gd")

const LOG_DIR: String = "user://logs/rendimiento"
const SAMPLE_INTERVAL: float = 0.5
const OVERLAY_INTERVAL: float = 0.25
const GRAPH_FRAMES: int = 240
const GRAPH_SIZE: Vector2 = Vector2(300.0, 64.0)
const GRAPH_MAX_MS: float = 50.0
## Cuadros más lentos que esto cuentan como tirón (por debajo de 30 FPS).
const HITCH_MS: float = 33.4
## Cuadros más lentos que esto se anotan uno por uno en el registro de eventos.
const SPIKE_MS: float = 50.0
const SPIKE_LOG_COOLDOWN: float = 0.25
## Al arrancar la escena los primeros cuadros son lentos por la carga: no cuentan.
const WARMUP_SECONDS: float = 1.0
## Cortes de cantidad de enemigos para la tabla del resumen.
const ENEMY_BUCKETS: Array[int] = [0, 10, 25, 50, 100, 150, 200, 300, 500]
const CENSUS_TOP: int = 25

const CSV_HEADER: String = "tiempo_s,fps,fps_1pct_bajo,ms_prom,ms_max,ms_proceso,ms_fisica,ms_cpu_render,ms_gpu,draw_calls,objetos_dibujados,primitivas,vram_mb,ram_mb,nodos,objetos,huerfanos,recursos,fis_activos,fis_pares,fis_islas,enemigos,proyectiles_activos,proyectiles_pool,gibs,manchas,botin,orbes,numeros_dano,particulas,hijos_escena,contexto"

const COLOR_GOOD: Color = Color(0.45, 1.0, 0.55, 1.0)
const COLOR_WARN: Color = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_BAD: Color = Color(1.0, 0.4, 0.35, 1.0)
const COLOR_TEXT: Color = Color(0.9, 0.92, 0.95, 1.0)

@export var log_to_disk: bool = true
@export var tag: String = "sesion"
## Lo usa la Sala de Estrés: F9 solo oculta el panel en vez de quitar el monitor.
var persistent: bool = false
var context_provider: Callable = Callable()

var log_base_path: String = ""

var _layer: CanvasLayer = null
var _panel: PanelContainer = null
var _label: RichTextLabel = null
var _graph: Control = null

var _ring: PackedFloat32Array = PackedFloat32Array()
var _ring_pos: int = 0
var _ring_count: int = 0

var _elapsed: float = 0.0
var _last_usec: int = 0
var _sample_timer: float = 0.0
var _overlay_timer: float = 0.0
var _window_max_ms: float = 0.0
var _window_sum_ms: float = 0.0
var _window_frames: int = 0
var _last_spike_log: float = -10.0
var _spikes_suppressed: int = 0

var _csv: FileAccess = null
var _events: FileAccess = null

# Último censo (se refresca con cada muestra o panel)
var _stats: Dictionary = {}

# Sesión completa (para el resumen)
var _all_ms: PackedFloat32Array = PackedFloat32Array()
var _session_frames: int = 0
var _session_ms: float = 0.0
var _hitches: int = 0
var _spikes: int = 0
var _worst: Array[Dictionary] = []
var _bucket_frames: PackedInt64Array = PackedInt64Array()
var _bucket_ms: PackedFloat64Array = PackedFloat64Array()
var _bucket_max: PackedFloat32Array = PackedFloat32Array()
var _bucket_hitches: PackedInt64Array = PackedInt64Array()
var _peaks: Dictionary = {"enemigos": 0, "nodos": 0, "objetos": 0, "ram_mb": 0.0, "vram_mb": 0.0, "proyectiles": 0, "fis_pares": 0}


func _ready() -> void:
	name = "PerfMonitor"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ring.resize(GRAPH_FRAMES)
	_bucket_frames.resize(ENEMY_BUCKETS.size())
	_bucket_ms.resize(ENEMY_BUCKETS.size())
	_bucket_max.resize(ENEMY_BUCKETS.size())
	_bucket_hitches.resize(ENEMY_BUCKETS.size())
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_build_overlay()
	if log_to_disk:
		_open_logs()
	_refresh_stats()


func _exit_tree() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	close_log()
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()


func _process(delta: float) -> void:
	# Tiempo real entre cuadros: `delta` se achica durante el hit-stop (Engine.time_scale) y escondería los tirones
	var now: int = Time.get_ticks_usec()
	var ms: float = delta * 1000.0 if _last_usec == 0 else float(now - _last_usec) / 1000.0
	_last_usec = now
	_elapsed += ms / 1000.0
	delta = ms / 1000.0
	_ring[_ring_pos] = ms
	_ring_pos = (_ring_pos + 1) % GRAPH_FRAMES
	_ring_count = mini(_ring_count + 1, GRAPH_FRAMES)
	_window_sum_ms += ms
	_window_frames += 1
	_window_max_ms = maxf(_window_max_ms, ms)

	if _elapsed > WARMUP_SECONDS:
		_record_frame(ms)

	_overlay_timer += delta
	if _overlay_timer >= OVERLAY_INTERVAL:
		_overlay_timer = 0.0
		_refresh_stats()
		_update_overlay()

	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL:
		_sample_timer = 0.0
		_write_sample()
		_window_sum_ms = 0.0
		_window_frames = 0
		_window_max_ms = 0.0

	if _graph != null and _panel.visible:
		_graph.queue_redraw()


# ==============================================================================
# API
# ==============================================================================

## Anota un evento con marca de tiempo en el registro (y en la salida de Godot).
func log_event(text: String) -> void:
	var line: String = "[%8.2f s] %s" % [_elapsed, text]
	if _events != null:
		_events.store_line(line)
		_events.flush()


func toggle_overlay() -> void:
	if _panel != null:
		_panel.visible = not _panel.visible


## Cuenta todos los nodos de la escena por tipo (script o clase) y anota los más numerosos.
func log_census() -> void:
	var scene: Node = _scene_root()
	if scene == null:
		return
	var counts: Dictionary = {}
	var started: int = Time.get_ticks_usec()
	_census(scene, counts)
	var took_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	var keys: Array = counts.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(counts[a]) > int(counts[b]))
	var total: int = 0
	for key: Variant in keys:
		total += int(counts[key])
	var lines: PackedStringArray = PackedStringArray()
	lines.append("CENSO DE NODOS: %d nodos en la escena (%d tipos, contado en %.1f ms)" % [total, keys.size(), took_ms])
	for i: int in range(mini(CENSUS_TOP, keys.size())):
		lines.append("    %6d  %s" % [int(counts[keys[i]]), str(keys[i])])
	log_event("\n".join(lines))


## Escribe el resumen y cierra los archivos. Se llama solo al salir de la escena.
func close_log() -> void:
	if _events != null:
		log_census()
		_events.store_string(_summary_text())
		_events.close()
		_events = null
		print("[PerfMonitor] Registro cerrado: %s.txt" % ProjectSettings.globalize_path(log_base_path))
	if _csv != null:
		_csv.close()
		_csv = null


func open_log_folder() -> void:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	OS.shell_open(ProjectSettings.globalize_path(LOG_DIR))


# ==============================================================================
# Medición
# ==============================================================================

func _record_frame(ms: float) -> void:
	_all_ms.append(ms)
	_session_frames += 1
	_session_ms += ms
	var bucket: int = _bucket_of(int(_stats.get("enemigos", 0)))
	_bucket_frames[bucket] += 1
	_bucket_ms[bucket] += ms
	_bucket_max[bucket] = maxf(_bucket_max[bucket], ms)
	if ms > HITCH_MS:
		_hitches += 1
		_bucket_hitches[bucket] += 1
	if ms > SPIKE_MS:
		_spikes += 1
		_note_worst(ms)
		if _elapsed - _last_spike_log >= SPIKE_LOG_COOLDOWN:
			var extra: String = (" (+%d picos sin anotar)" % _spikes_suppressed) if _spikes_suppressed > 0 else ""
			_spikes_suppressed = 0
			_last_spike_log = _elapsed
			log_event("PICO %.1f ms | enemigos %d | nodos %d | %s%s" % [
				ms, int(_stats.get("enemigos", 0)), int(_stats.get("nodos", 0)), _context(), extra])
		else:
			_spikes_suppressed += 1


func _note_worst(ms: float) -> void:
	_worst.append({"ms": ms, "t": _elapsed, "enemigos": int(_stats.get("enemigos", 0)), "ctx": _context()})
	_worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ms"]) > float(b["ms"]))
	if _worst.size() > 10:
		_worst.resize(10)


func _bucket_of(enemies: int) -> int:
	var idx: int = 0
	for i: int in range(ENEMY_BUCKETS.size()):
		if enemies >= ENEMY_BUCKETS[i]:
			idx = i
	return idx


func _context() -> String:
	if context_provider.is_valid():
		return str(context_provider.call())
	return ""


func _refresh_stats() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var s: Dictionary = {}
	var vp_rid: RID = get_viewport().get_viewport_rid()
	s["fps"] = Performance.get_monitor(Performance.TIME_FPS)
	s["ms_proceso"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	s["ms_fisica"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	s["ms_cpu_render"] = RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
	s["ms_gpu"] = RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	s["draw_calls"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	s["objetos_dibujados"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	s["primitivas"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	s["vram_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	s["ram_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	s["nodos"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	s["objetos"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	s["huerfanos"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	s["recursos"] = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	s["fis_activos"] = int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
	s["fis_pares"] = int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS))
	s["fis_islas"] = int(Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT))
	s["enemigos"] = tree.get_node_count_in_group(&"enemies")
	s["gibs"] = tree.get_node_count_in_group(&"gibs")
	s["manchas"] = tree.get_node_count_in_group(&"blood_stains")

	var pool: Node = tree.get_first_node_in_group(&"projectile_pool")
	var active: int = 0
	var pooled: int = 0
	if pool != null:
		for child: Node in pool.get_children():
			pooled += 1
			if child.process_mode != Node.PROCESS_MODE_DISABLED:
				active += 1
	s["proyectiles_activos"] = active
	s["proyectiles_pool"] = pooled

	# Hijos directos de la escena: ahí caen botín, orbes, números, partículas y efectos sueltos
	var by_kind: Dictionary = {}
	var children: int = 0
	var scene: Node = _scene_root()
	if scene != null:
		for child: Node in scene.get_children():
			children += 1
			var key: String = _node_key(child)
			by_kind[key] = int(by_kind.get(key, 0)) + 1
	s["hijos_escena"] = children
	s["botin"] = int(by_kind.get("LootDrop", 0))
	s["orbes"] = int(by_kind.get("ExpOrb", 0))
	s["numeros_dano"] = int(by_kind.get("DamageNumber", 0))
	s["particulas"] = int(by_kind.get("CPUParticles2D", 0)) + int(by_kind.get("GPUParticles2D", 0))
	s["por_tipo"] = by_kind
	_stats = s

	_peaks["enemigos"] = maxi(int(_peaks["enemigos"]), int(s["enemigos"]))
	_peaks["nodos"] = maxi(int(_peaks["nodos"]), int(s["nodos"]))
	_peaks["objetos"] = maxi(int(_peaks["objetos"]), int(s["objetos"]))
	_peaks["proyectiles"] = maxi(int(_peaks["proyectiles"]), active)
	_peaks["fis_pares"] = maxi(int(_peaks["fis_pares"]), int(s["fis_pares"]))
	_peaks["ram_mb"] = maxf(float(_peaks["ram_mb"]), float(s["ram_mb"]))
	_peaks["vram_mb"] = maxf(float(_peaks["vram_mb"]), float(s["vram_mb"]))


## La escena que se mide: el padre del monitor (al cambiar de escena `current_scene` ya apunta a la nueva).
func _scene_root() -> Node:
	var parent: Node = get_parent()
	if parent != null and parent != get_tree().root:
		return parent
	return get_tree().current_scene


static func _node_key(node: Node) -> String:
	var script: Script = node.get_script() as Script
	if script != null:
		var global_name: StringName = script.get_global_name()
		if global_name != &"":
			return String(global_name)
		if not script.resource_path.is_empty():
			return script.resource_path.get_file().get_basename()
	return node.get_class()


func _census(node: Node, counts: Dictionary) -> void:
	var key: String = _node_key(node)
	counts[key] = int(counts.get(key, 0)) + 1
	for child: Node in node.get_children():
		_census(child, counts)


## FPS equivalentes al 1% de cuadros más lentos de la ventana reciente.
func _one_percent_low() -> float:
	if _ring_count == 0:
		return 0.0
	var recent: PackedFloat32Array = _ring.slice(0, _ring_count) if _ring_count < GRAPH_FRAMES else _ring.duplicate()
	recent.sort()
	var idx: int = clampi(int(floor(float(recent.size()) * 0.99)), 0, recent.size() - 1)
	return 1000.0 / maxf(recent[idx], 0.001)


# ==============================================================================
# Registro a disco
# ==============================================================================

func _open_logs() -> void:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var stamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	log_base_path = "%s/%s_%s" % [LOG_DIR, tag, stamp]
	_csv = FileAccess.open(log_base_path + ".csv", FileAccess.WRITE)
	_events = FileAccess.open(log_base_path + ".txt", FileAccess.WRITE)
	if _csv == null or _events == null:
		push_warning("[PerfMonitor] No se pudo crear el registro en %s" % log_base_path)
		return
	_csv.store_line(CSV_HEADER)
	_events.store_line(_header_text())
	_events.flush()
	print("[PerfMonitor] Registrando rendimiento en %s.csv / .txt" % ProjectSettings.globalize_path(log_base_path))


func _header_text() -> String:
	var quality_labels: Array[String] = SettingsScript.QUALITY_LABELS
	var quality: String = quality_labels[clampi(SettingsScript.get_int("quality"), 0, quality_labels.size() - 1)]
	var scene_path: String = ""
	if _scene_root() != null:
		scene_path = _scene_root().scene_file_path
	var lines: PackedStringArray = PackedStringArray([
		"=== WARMACHINE - registro de rendimiento ===",
		"Fecha: %s" % Time.get_datetime_string_from_system(false, true),
		"Versión: %s | Godot %s" % [str(ProjectSettings.get_setting("application/config/version", "dev")), str(Engine.get_version_info().get("string", ""))],
		"Sistema: %s %s | CPU: %s (%d hilos)" % [OS.get_name(), OS.get_version(), OS.get_processor_name(), OS.get_processor_count()],
		"GPU: %s | %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()],
		"Renderizador: %s | Ventana: %s | VSync: %d | Tope FPS: %d" % [
			str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
			str(DisplayServer.window_get_size()), SettingsScript.get_int("vsync"), Engine.max_fps],
		"Calidad: %s | Partículas x%.2f | Escena: %s" % [quality, SettingsScript.particle_scale(), scene_path],
		"Muestras cada %.1f s en el .csv; acá van los eventos, los picos de más de %d ms y el resumen al salir." % [SAMPLE_INTERVAL, int(SPIKE_MS)],
		"",
	])
	return "\n".join(lines)


func _write_sample() -> void:
	if _csv == null:
		return
	var avg_ms: float = _window_sum_ms / float(maxi(_window_frames, 1))
	var s: Dictionary = _stats
	var ctx: String = _context().replace(",", ";").replace("\"", "'")
	var row: PackedStringArray = PackedStringArray([
		"%.2f" % _elapsed, "%.0f" % float(s.get("fps", 0.0)), "%.0f" % _one_percent_low(),
		"%.2f" % avg_ms, "%.2f" % _window_max_ms,
		"%.2f" % float(s.get("ms_proceso", 0.0)), "%.2f" % float(s.get("ms_fisica", 0.0)),
		"%.2f" % float(s.get("ms_cpu_render", 0.0)), "%.2f" % float(s.get("ms_gpu", 0.0)),
		str(s.get("draw_calls", 0)), str(s.get("objetos_dibujados", 0)), str(s.get("primitivas", 0)),
		"%.1f" % float(s.get("vram_mb", 0.0)), "%.1f" % float(s.get("ram_mb", 0.0)),
		str(s.get("nodos", 0)), str(s.get("objetos", 0)), str(s.get("huerfanos", 0)), str(s.get("recursos", 0)),
		str(s.get("fis_activos", 0)), str(s.get("fis_pares", 0)), str(s.get("fis_islas", 0)),
		str(s.get("enemigos", 0)), str(s.get("proyectiles_activos", 0)), str(s.get("proyectiles_pool", 0)),
		str(s.get("gibs", 0)), str(s.get("manchas", 0)), str(s.get("botin", 0)), str(s.get("orbes", 0)),
		str(s.get("numeros_dano", 0)), str(s.get("particulas", 0)), str(s.get("hijos_escena", 0)),
		"\"%s\"" % ctx,
	])
	_csv.store_line(",".join(row))
	_csv.flush()
	if _events != null:
		_events.flush()


func _summary_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("")
	lines.append("=== RESUMEN (%.1f s medidos, %d cuadros) ===" % [_session_ms / 1000.0, _session_frames])
	if _session_frames == 0:
		lines.append("Sin cuadros medidos.")
		return "\n".join(lines) + "\n"
	var sorted_ms: PackedFloat32Array = _all_ms.duplicate()
	sorted_ms.sort()
	var avg_ms: float = _session_ms / float(_session_frames)
	lines.append("FPS promedio %.1f (%.2f ms) | 1%% bajo %.1f FPS | 0.1%% bajo %.1f FPS" % [
		1000.0 / avg_ms, avg_ms, 1000.0 / _percentile(sorted_ms, 0.99), 1000.0 / _percentile(sorted_ms, 0.999)])
	lines.append("Cuadro: mediana %.2f ms | p95 %.2f | p99 %.2f | peor %.2f" % [
		_percentile(sorted_ms, 0.5), _percentile(sorted_ms, 0.95), _percentile(sorted_ms, 0.99), sorted_ms[sorted_ms.size() - 1]])
	lines.append("Tirones (> %.1f ms): %d (%.2f%%) | Picos (> %d ms): %d" % [
		HITCH_MS, _hitches, 100.0 * float(_hitches) / float(_session_frames), int(SPIKE_MS), _spikes])
	lines.append("Máximos: enemigos %d | nodos %d | objetos %d | proyectiles activos %d | pares de colisión %d | RAM %.0f MB | VRAM %.0f MB" % [
		int(_peaks["enemigos"]), int(_peaks["nodos"]), int(_peaks["objetos"]), int(_peaks["proyectiles"]),
		int(_peaks["fis_pares"]), float(_peaks["ram_mb"]), float(_peaks["vram_mb"])])
	lines.append("")
	lines.append("Rendimiento según enemigos vivos:")
	lines.append("    enemigos     cuadros   FPS prom   ms prom   ms peor   tirones")
	for i: int in range(ENEMY_BUCKETS.size()):
		var frames: int = _bucket_frames[i]
		if frames == 0:
			continue
		var label: String = ("%d+" % ENEMY_BUCKETS[i]) if i == ENEMY_BUCKETS.size() - 1 else ("%d-%d" % [ENEMY_BUCKETS[i], ENEMY_BUCKETS[i + 1] - 1])
		var b_avg: float = _bucket_ms[i] / float(frames)
		lines.append("    %-10s %9d %10.1f %9.2f %9.2f %9d" % [label, frames, 1000.0 / b_avg, b_avg, _bucket_max[i], _bucket_hitches[i]])
	if not _worst.is_empty():
		lines.append("")
		lines.append("Peores cuadros:")
		for w: Dictionary in _worst:
			lines.append("    %7.1f ms a los %7.2f s | enemigos %d | %s" % [float(w["ms"]), float(w["t"]), int(w["enemigos"]), str(w["ctx"])])
	return "\n".join(lines) + "\n"


static func _percentile(sorted_ms: PackedFloat32Array, p: float) -> float:
	if sorted_ms.is_empty():
		return 0.0
	var idx: int = clampi(int(floor(float(sorted_ms.size() - 1) * p)), 0, sorted_ms.size() - 1)
	return maxf(sorted_ms[idx], 0.001)


# ==============================================================================
# Panel en pantalla
# ==============================================================================

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -GRAPH_SIZE.x - 28.0
	_panel.offset_right = -8.0
	_panel.offset_top = 68.0  # debajo del contador de monedas del HUD
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.06, 0.78)
	style.border_color = Color(0.35, 0.75, 1.0, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6.0)
	_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)

	var mono: SystemFont = SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.custom_minimum_size = Vector2(GRAPH_SIZE.x, 0.0)
	_label.add_theme_font_override("normal_font", mono)
	_label.add_theme_font_override("bold_font", mono)
	_label.add_theme_font_size_override("normal_font_size", 11)
	_label.add_theme_font_size_override("bold_font_size", 11)
	_label.add_theme_color_override("default_color", COLOR_TEXT)
	box.add_child(_label)

	_graph = Control.new()
	_graph.custom_minimum_size = GRAPH_SIZE
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.draw.connect(_draw_graph)
	box.add_child(_graph)


func _update_overlay() -> void:
	if _label == null or not _panel.visible:
		return
	var s: Dictionary = _stats
	var fps: float = float(s.get("fps", 0.0))
	var low: float = _one_percent_low()
	var avg_ms: float = _window_sum_ms / float(maxi(_window_frames, 1))
	var gpu_ms: float = float(s.get("ms_gpu", 0.0))
	var gpu_text: String = ("%.1f" % gpu_ms) if gpu_ms > 0.0 else "n/d"
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]RENDIMIENTO[/b]  [color=#8899aa]F9 oculta[/color]")
	lines.append("FPS [color=#%s]%3.0f[/color]  1%% bajo [color=#%s]%3.0f[/color]" % [_fps_color(fps).to_html(false), fps, _fps_color(low).to_html(false), low])
	lines.append("Cuadro %5.1f ms  máx %5.1f" % [avg_ms, _window_max_ms])
	lines.append("Proceso %4.1f  Física %4.1f  GPU %s" % [float(s.get("ms_proceso", 0.0)), float(s.get("ms_fisica", 0.0)), gpu_text])
	lines.append("Dibujo %d llamadas  %d objetos" % [int(s.get("draw_calls", 0)), int(s.get("objetos_dibujados", 0))])
	lines.append("Nodos %d  Objetos %d  Huérf. %d" % [int(s.get("nodos", 0)), int(s.get("objetos", 0)), int(s.get("huerfanos", 0))])
	lines.append("RAM %.0f MB  VRAM %.0f MB" % [float(s.get("ram_mb", 0.0)), float(s.get("vram_mb", 0.0))])
	lines.append("Física 2D: %d activos  %d pares" % [int(s.get("fis_activos", 0)), int(s.get("fis_pares", 0))])
	lines.append("[color=#ffcc66]Enemigos %d[/color]  Proyectiles %d/%d" % [int(s.get("enemigos", 0)), int(s.get("proyectiles_activos", 0)), int(s.get("proyectiles_pool", 0))])
	lines.append("Gibs %d  Manchas %d  Botín %d  Orbes %d" % [int(s.get("gibs", 0)), int(s.get("manchas", 0)), int(s.get("botin", 0)), int(s.get("orbes", 0))])
	lines.append("Números %d  Partículas %d  Hijos %d" % [int(s.get("numeros_dano", 0)), int(s.get("particulas", 0)), int(s.get("hijos_escena", 0))])
	lines.append("Tirones %d  Picos %d" % [_hitches, _spikes])
	if not log_base_path.is_empty():
		lines.append("[color=#8899aa]Log: %s[/color]" % log_base_path.get_file())
	_label.text = "\n".join(lines)


func _fps_color(fps: float) -> Color:
	if fps >= 55.0:
		return COLOR_GOOD
	if fps >= 30.0:
		return COLOR_WARN
	return COLOR_BAD


func _draw_graph() -> void:
	var w: float = GRAPH_SIZE.x
	var h: float = GRAPH_SIZE.y
	_graph.draw_rect(Rect2(Vector2.ZERO, GRAPH_SIZE), Color(0.0, 0.0, 0.0, 0.35))
	for target_ms: float in [16.7, 33.3]:
		var y: float = h - h * target_ms / GRAPH_MAX_MS
		_graph.draw_line(Vector2(0.0, y), Vector2(w, y), Color(1.0, 1.0, 1.0, 0.18), 1.0)
	if _ring_count == 0:
		return
	var bar_w: float = w / float(GRAPH_FRAMES)
	for i: int in range(_ring_count):
		# El más viejo a la izquierda
		var idx: int = (_ring_pos - _ring_count + i + GRAPH_FRAMES) % GRAPH_FRAMES
		var ms: float = _ring[idx]
		var bar_h: float = minf(h, h * ms / GRAPH_MAX_MS)
		var color: Color = COLOR_GOOD if ms <= 17.5 else (COLOR_WARN if ms <= HITCH_MS else COLOR_BAD)
		_graph.draw_rect(Rect2(float(GRAPH_FRAMES - _ring_count + i) * bar_w, h - bar_h, maxf(bar_w, 1.0), bar_h), color)
