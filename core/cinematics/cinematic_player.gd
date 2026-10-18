extends CanvasLayer
## Motor de cinemáticas. Una cinemática es una lista de pasos (diccionarios con la clave "t") que se ejecutan
## en orden. Sin class_name: se usa por `preload` (`CinematicPlayer.play(contexto, pasos)`).
##
## Piezas (core/cinematics/):
##   cinematic_player.gd    este archivo: ciclo de vida (pausa, HUD, entrada, cierre garantizado)
##   cinematic_context.gd   estado compartido + esperas cortables, actores, cámara (lo reciben los comandos)
##   cinematic_stage.gd     UI: fondo, sprites, barras, diálogo, título, destello, fundido
##   cinematic_registry.gd  nombre de paso -> comando; validación de listas de pasos
##   cinematic_command.gd   base de los comandos (cómo escribir uno nuevo)
##   commands/*.gd          un comando por archivo
##
## Pasos (clave "t"); cualquiera acepta además "timeout" (tope en segundos, 30 por defecto):
##   wait {s}                         espera
##   say {who, text, thought?, s?, on?, zoom?, cut?}  diálogo en primer plano: la cámara va a la cabeza de quien
##                                    habla y solo aparece el subtítulo (dura según el largo del texto si no hay `s`)
##   dialogue {cast?, zoom?}          elenco de los `say` (nombre -> id de actor, p. ej. {"GUNTHER": "player"})
##   title {text, s}                  texto grande centrado
##   fade {to, s}                     fundido a negro (to = 1) o desde negro (to = 0)
##   flash {s, color?}                destello (blanco por defecto)
##   bg {file}                        fondo a pantalla completa (assets/art/bg/); "" lo quita
##   show {id, file, x, y, h, flip?, tint?}  sprite en pantalla (x, y, h en fracción de la pantalla); hide {id}
##   spawn {id, file, pos, h, flip?}  sprite en el mundo (assets/art/world1/); remove {id}
##   move {id, to, s}                 desplaza un actor ("player", un id de spawn o "@Ruta/Del/Nodo")
##   focus {pos | id, zoom, s}        la cámara se acerca a un punto o actor; release {s} la devuelve al jugador
##   shake {amp, s}                   sacudida de cámara
##   sfx {name}                       efecto de sonido
##   box {state}                      la Caja del nivel (grupo `the_box`): "open" / "closed"
##   call {fn}                        ejecuta un Callable (si devuelve una corrutina, la espera)
##   goto {path}                      cambia de escena (termina la cinemática)
##   par {steps}                      varios pasos a la vez; termina cuando terminan todos
##   seq {steps}                      varios pasos en orden (sirve como rama dentro de un `par`)
## Las rutas de archivo pueden ser absolutas (res://...) para usar arte de otra carpeta.
##
## Durante la cinemática el juego queda en pausa, el HUD se oculta y hay barras negras;
## [Enter]/clic avanza la línea, [Esc] o mantener [R] un segundo la saltan entera (los pasos que cambian el
## estado se aplican igual). Un paso inválido se avisa y se saltea; un paso que se cuelga se corta por tiempo;
## si la escena cambia a mitad de camino, la pausa, el HUD y la cámara se restauran igual.

signal finished
signal step_started(index: int, kind: String)

const ContextScript = preload("res://core/cinematics/cinematic_context.gd")
const StageScript = preload("res://core/cinematics/cinematic_stage.gd")
const Registry = preload("res://core/cinematics/cinematic_registry.gd")

const SKIP_HOLD_KEY: Key = KEY_R
const SKIP_HOLD_SECONDS: float = 1.0

static var active: bool = false
## Cinemática en curso (o null).
static var current: Node = null

var _steps: Array = []
var _ctx: RefCounted = null
var _stage = null
var _paused_by_me: bool = false
var _hidden_huds: Array[Node] = []
var _skip_hold: float = 0.0
var _closed: bool = false


## Crea el reproductor en la escena actual y arranca. Devuelve el nodo (señal `finished`) o null si no pudo
## (ya hay una en curso, contexto inválido o lista vacía).
static func play(ctx: Node, steps: Array, on_done: Callable = Callable()) -> Node:
	if active and current != null and not is_instance_valid(current):
		active = false  # quedó colgada de una escena que ya no existe
	if active or ctx == null or not ctx.is_inside_tree() or steps.is_empty():
		return null
	for problem: String in Registry.validate(steps):
		push_warning("Cinemática: " + problem)
	var node: CanvasLayer = (load("res://core/cinematics/cinematic_player.gd") as GDScript).new() as CanvasLayer
	node.set("_steps", steps)
	if on_done.is_valid():
		node.connect("finished", on_done, CONNECT_ONE_SHOT)
	var holder: Node = ctx.get_tree().current_scene
	if holder == null:
		holder = ctx
	holder.add_child(node)
	return node


## Problemas de una lista de pasos (vacío = está bien). Para chequear cinemáticas sin reproducirlas.
static func validate(steps: Array) -> PackedStringArray:
	return Registry.validate(steps)


## Salta la cinemática en curso (los pasos que cambian el estado se aplican igual).
static func skip_current() -> void:
	if current != null and is_instance_valid(current):
		current.call("skip")


func _ready() -> void:
	active = true
	current = self
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_stage = StageScript.new()
	add_child(_stage)
	_ctx = ContextScript.new()
	_ctx.call("setup", self, _stage)
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_me = true
	# Grupo `hud`: CanvasItem o CanvasLayer (los dos tienen `visible`)
	for hud: Node in get_tree().get_nodes_in_group(&"hud"):
		if (hud is CanvasItem or hud is CanvasLayer) and bool(hud.get("visible")):
			hud.set("visible", false)
			_hidden_huds.append(hud)
	_run.call_deferred()


func _exit_tree() -> void:
	# Si la escena se cambia o se borra a mitad de camino, igual se deja todo como estaba
	if not _closed:
		_ctx.set("stopped", true)
		_close()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		_ctx.set("advance", true)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Mantener [R] salta la cinemática entera: hace falta mantenerla un rato para no saltarla por accidente
	if _ctx.get("skipping") or not Input.is_physical_key_pressed(SKIP_HOLD_KEY):
		_skip_hold = 0.0
		return
	_skip_hold += delta
	if _skip_hold >= SKIP_HOLD_SECONDS:
		skip()


func skip() -> void:
	_ctx.set("skipping", true)


## Termina ya, sin el cierre animado (lo usa `goto`). Emite `finished`.
func stop() -> void:
	if _closed:
		return
	_ctx.set("stopped", true)
	_close()
	finished.emit()
	queue_free()


func _run() -> void:
	var ctx = _ctx
	ctx.tween(_stage.bar_top, {"offset_bottom": StageScript.BAR_HEIGHT}, 0.4)
	ctx.tween(_stage.bar_bottom, {"offset_top": -StageScript.BAR_HEIGHT}, 0.4)
	for i: int in _steps.size():
		if ctx.stopped or _closed:
			return
		var step: Variant = _steps[i]
		step_started.emit(i, str((step as Dictionary).get("t", "")) if step is Dictionary else "")
		await ctx.run_top(step)
	if ctx.stopped or _closed:
		return
	await _finish()


func _finish() -> void:
	_stage.hide_line()
	var ctx = _ctx
	ctx.skipping = false  # el cierre se anima aunque se haya saltado
	ctx.tween(_stage.bar_top, {"offset_bottom": 0.0}, 0.3)
	ctx.tween(_stage.bar_bottom, {"offset_top": 0.0}, 0.3)
	await ctx.tween(_stage.fade, {"color:a": 0.0}, 0.5)
	if _closed:
		return
	_close()
	finished.emit()
	queue_free()


## Restaura cámara, actores, pausa y HUD. Se ejecuta una sola vez pase lo que pase.
func _close() -> void:
	if _closed:
		return
	_closed = true
	active = false
	if current == self:
		current = null
	_ctx.call("restore_camera")
	_ctx.call("clear_actors")
	if _paused_by_me and is_inside_tree():
		get_tree().paused = false
	for hud: Node in _hidden_huds:
		if is_instance_valid(hud):
			hud.set("visible", true)
	_hidden_huds.clear()
