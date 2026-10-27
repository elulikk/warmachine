extends RefCounted
## Estado compartido de una cinemática en curso: lo reciben todos los comandos (`run(ctx, step)`).
## Tiene las esperas "cortables", los actores, la cámara y el escenario (UI). Lo crea cinematic_player.gd.

const Registry = preload("res://core/cinematics/cinematic_registry.gd")
const ArtScript = preload("res://core/art/art.gd")

const WORLD_DIR: String = "res://assets/art/world1/"
const BG_DIR: String = "res://assets/art/bg/"
## Tope por paso de primer nivel: si un paso tarda más (un await que nunca vuelve, un `move` eterno), se corta
## y la cinemática sigue. Un paso puede pedir otro tope con la clave "timeout".
const STEP_TIMEOUT: float = 30.0
## Altura de los ojos respecto de los pies de un actor (para `focus` sobre un actor).
const EYE_OFFSET: Vector2 = Vector2(0.0, -40.0)
## Cabeza del jugador respecto de sus pies (para el primer plano).
const PLAYER_HEAD: Vector2 = Vector2(0.0, -70.0)
## Zoom del primer plano si no se pide otro.
const CLOSEUP_ZOOM: float = 5.0

## Nodo reproductor (CanvasLayer); dueño de los tweens.
var host: Node = null
var tree: SceneTree = null
## Escena donde se agregan los actores del mundo.
var level: Node = null
## Escenario de pantalla (cinematic_stage.gd).
var stage: Control = null
var camera: Camera2D = null
var cam_zoom: Vector2 = Vector2.ONE
var cam_smoothing: bool = false

## Se pidió saltar todo ([Esc] o mantener [R]): los pasos se aplican al instante.
var skipping: bool = false
## La cinemática terminó o se cortó (goto, stop, cambio de escena): todo await tiene que volver ya.
var stopped: bool = false
## [Enter]/clic: avanza la línea actual.
var advance: bool = false

## Elenco: nombre de quien habla -> id de actor (lo arma el paso `dialogue`), y zoom del primer plano.
var cast: Dictionary = {}
var closeup_zoom: float = CLOSEUP_ZOOM

var _actors: Dictionary = {}
## Tope del paso actual, en tiempo de juego (un tirón o una máquina lenta no lo disparan antes de tiempo).
var _deadline: SceneTreeTimer = null
var _timed_out: bool = false


func setup(owner_node: Node, stage_node: Control) -> void:
	host = owner_node
	tree = owner_node.get_tree()
	level = tree.current_scene
	stage = stage_node
	camera = owner_node.get_viewport().get_camera_2d()
	if camera != null:
		cam_zoom = camera.zoom
		# Con el suavizado activo la cámara no se mueve mientras el juego está en pausa
		cam_smoothing = camera.position_smoothing_enabled
		camera.position_smoothing_enabled = false


# ==============================================================================
# Ejecución de pasos
# ==============================================================================

## Paso de primer nivel: con tope de tiempo.
func run_top(step: Variant) -> void:
	var limit: float = STEP_TIMEOUT
	if step is Dictionary:
		limit = maxf(float((step as Dictionary).get("timeout", STEP_TIMEOUT)), 0.1)
	_deadline = tree.create_timer(limit, true)
	_timed_out = false
	await run_step(step)
	_deadline = null


## Ejecuta un paso (también desde `par`/`seq`). Un paso inválido se avisa y se saltea, no rompe la cinemática.
func run_step(step: Variant) -> void:
	if stopped:
		return
	var problem: String = Registry.check_step(step)
	if not problem.is_empty():
		warn("paso salteado: " + problem)
		return
	var cmd = Registry.get_command(str((step as Dictionary)["t"]))
	await cmd.run(self, step as Dictionary)


## true = el paso actual tiene que terminar ya (saltada, cortada o pasada de tiempo).
func cut() -> bool:
	if skipping or stopped:
		return true
	if _deadline != null and _deadline.time_left <= 0.0:
		if not _timed_out:
			_timed_out = true
			warn("un paso superó su tope de tiempo y se cortó")
		return true
	return false


# ==============================================================================
# Esperas (siempre cortables)
# ==============================================================================

func frame() -> void:
	if tree != null:
		await tree.process_frame


func wait(seconds: float) -> void:
	if cut() or seconds <= 0.0:
		return
	var timer: SceneTreeTimer = tree.create_timer(seconds, true)
	while timer.time_left > 0.0 and not cut():
		await frame()


## Espera `seconds` o hasta que el jugador avance ([Enter]/clic).
func wait_line(seconds: float) -> void:
	advance = false
	if cut():
		return
	var timer: SceneTreeTimer = tree.create_timer(seconds, true)
	while timer.time_left > 0.0 and not cut() and not advance:
		await frame()
	advance = false


## Lleva propiedades de `obj` a sus valores (`{"color:a": 1.0, "zoom": Vector2.ONE}`) en `seconds`.
## Si se corta, o el tiempo es 0, quedan directamente en el valor final.
func tween(obj: Object, props: Dictionary, seconds: float, trans: Tween.TransitionType = Tween.TRANS_LINEAR) -> void:
	if obj == null or not is_instance_valid(obj):
		return
	if not cut() and seconds > 0.0 and host != null and is_instance_valid(host):
		var tw: Tween = host.create_tween().set_parallel(true)
		for prop: String in props:
			tw.tween_property(obj, prop, props[prop], seconds).set_trans(trans)
		while tw.is_valid() and tw.is_running() and not cut():
			await frame()
		if tw.is_valid():
			tw.kill()
	if is_instance_valid(obj):
		for prop: String in props:
			obj.set_indexed(prop, props[prop])


# ==============================================================================
# Actores
# ==============================================================================

## "player" = el jugador; "@Ruta/Nodo" = un nodo del nivel; si no, un actor creado con `spawn`.
func actor(id: String) -> Node2D:
	if id == "player":
		return tree.get_first_node_in_group(&"player") as Node2D
	if id.begins_with("@"):
		if level == null or not is_instance_valid(level):
			return null
		return level.get_node_or_null(NodePath(id.substr(1))) as Node2D
	var found: Variant = _actors.get(id, null)
	if found == null or not is_instance_valid(found):
		return null
	return found as Node2D


## Posición de la cabeza de un actor: meta "cine_head" (la pone `spawn`), el jugador, o la altura de los ojos.
func head(node: Node2D) -> Vector2:
	if node.has_meta(&"cine_head"):
		return node.global_position + (node.get_meta(&"cine_head") as Vector2)
	if node.is_in_group(&"player"):
		return node.global_position + PLAYER_HEAD
	return node.global_position + EYE_OFFSET


func add_actor(id: String, node: Node2D) -> void:
	remove_actor(id)
	_actors[id] = node


func remove_actor(id: String) -> void:
	var found: Variant = _actors.get(id, null)
	if found != null and is_instance_valid(found):
		(found as Node).queue_free()
	_actors.erase(id)


func clear_actors() -> void:
	for id: String in _actors.keys():
		remove_actor(id)


# ==============================================================================
# Utilidades
# ==============================================================================

func has_camera() -> bool:
	return camera != null and is_instance_valid(camera)


## Devuelve la cámara a como estaba antes de la cinemática.
func restore_camera() -> void:
	if not has_camera():
		return
	camera.zoom = cam_zoom
	camera.offset = Vector2.ZERO
	camera.position_smoothing_enabled = cam_smoothing
	camera.reset_smoothing()


## Textura de `dir` + `file` (o `file` tal cual si es una ruta res://). Avisa si no existe.
func texture(dir: String, file: String) -> Texture2D:
	if file.is_empty():
		return null
	var path: String = file if file.begins_with("res://") else dir + file
	var tex: Texture2D = ArtScript.tex(path)
	if tex == null:
		warn("no existe la textura " + path)
	return tex


func warn(message: String) -> void:
	push_warning("Cinemática: " + message)
