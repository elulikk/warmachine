extends Logger
## Registro de errores del juego a `user://logs/errors_<fecha>.log` (además del `godot.log` del motor).
## Sin class_name: lo instala GameManager con `ErrorLoggerScript.install()` al arrancar.
##
## - El archivo se crea recién con el primer error: una sesión limpia no deja archivos.
## - Encabezado con versión del juego, sistema, placa de video y escena actual, para diagnosticar reportes.
## - Se conservan los últimos `KEEP_FILES` registros.
## - Godot llama a este logger desde cualquier hilo: todo pasa por un Mutex y nunca se imprime desde acá
##   (imprimir volvería a entrar al logger).

const LOG_DIR: String = "user://logs"
const PREFIX: String = "errors_"
const KEEP_FILES: int = 10
## Tope de líneas por sesión para que un error en bucle no llene el disco.
const MAX_ENTRIES: int = 400

const TYPE_NAMES: Array[String] = ["ERROR", "ADVERTENCIA", "ERROR DE SCRIPT", "ERROR DE SHADER"]

static var _instance: Logger = null

var _mutex: Mutex = Mutex.new()
var _file: FileAccess = null
var _path: String = ""
var _entries: int = 0
var _busy: bool = false
var _header: String = ""


static func install() -> void:
	if _instance != null:
		return
	var logger: Logger = (load("res://core/error_logger.gd") as GDScript).new() as Logger
	logger.call("_prepare_header")
	_instance = logger
	OS.add_logger(logger)


## Se llama al cerrar el juego (GameManager._exit_tree) para no dejar el logger colgado del motor.
static func uninstall() -> void:
	if _instance == null:
		return
	OS.remove_logger(_instance)
	_instance.call("_close")
	_instance = null


func _close() -> void:
	_mutex.lock()
	if _file != null:
		_file.close()
		_file = null
	_mutex.unlock()


## Ruta del registro de esta sesión ("" si todavía no hubo errores).
static func current_log_path() -> String:
	if _instance == null:
		return ""
	return str(_instance.get("_path"))


func _prepare_header() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version", "dev"))
	_header = "WARMACHINE %s | %s | %s %s | %s | %s\n" % [
		version,
		Engine.get_version_info().get("string", ""),
		OS.get_name(), OS.get_version(),
		RenderingServer.get_video_adapter_name(),
		Time.get_datetime_string_from_system(false, true),
	]


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	# Las advertencias quedan solo en godot.log
	if error_type == 1:
		return
	var kind: String = TYPE_NAMES[clampi(error_type, 0, TYPE_NAMES.size() - 1)]
	var text: String = rationale if not rationale.is_empty() else code
	var entry: String = "[%s] %s: %s\n    en %s (%s:%d)\n" % [Time.get_time_string_from_system(), kind, text, function, file, line]
	for bt: ScriptBacktrace in script_backtraces:
		if bt != null and not bt.is_empty():
			entry += bt.format(4, 4)
	_write(entry)


func _log_message(message: String, error: bool) -> void:
	if error:
		_write("[%s] %s\n" % [Time.get_time_string_from_system(), message.strip_edges()])


func _write(entry: String) -> void:
	_mutex.lock()
	if _busy or _entries >= MAX_ENTRIES:
		_mutex.unlock()
		return
	_busy = true
	if _file == null:
		_open()
	if _file != null:
		_file.store_string(entry)
		_entries += 1
		if _entries == MAX_ENTRIES:
			_file.store_string("... se alcanzó el tope de %d entradas; el resto queda en godot.log\n" % MAX_ENTRIES)
		_file.flush()
	_busy = false
	_mutex.unlock()


func _open() -> void:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	_prune()
	var stamp: String = Time.get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_")
	_path = "%s/%s%s.log" % [LOG_DIR, PREFIX, stamp]
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file != null:
		_file.store_string(_header)
		# El árbol solo se lee desde el hilo principal
		var tree: SceneTree = null
		if OS.get_thread_caller_id() == OS.get_main_thread_id():
			tree = Engine.get_main_loop() as SceneTree
		if tree != null and tree.current_scene != null:
			_file.store_string("Escena: %s\n" % tree.current_scene.scene_file_path)
		_file.store_string("\n")


## Borra los registros más viejos dejando lugar para el nuevo.
func _prune() -> void:
	var dir: DirAccess = DirAccess.open(LOG_DIR)
	if dir == null:
		return
	var names: Array[String] = []
	for file_name: String in dir.get_files():
		if file_name.begins_with(PREFIX) and file_name.ends_with(".log"):
			names.append(file_name)
	names.sort()
	while names.size() >= KEEP_FILES:
		dir.remove(names.pop_front())

