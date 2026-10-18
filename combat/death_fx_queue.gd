extends Node
## Cola de efectos de muerte con presupuesto por cuadro: evita el congelamiento cuando mueren muchos juntos
## (granadas, misiles, "matar todos"). Sin class_name a propósito: se carga por `preload`.
##
## Medido en la Sala de Estrés: cada muerte creaba en el mismo cuadro ~12 trozos, 5 emisores de partículas,
## 3 salpicaduras dibujadas, 6 manchas (con sus rayos) y 3-4 piezas de botín; 100 muertes juntas eran un cuadro
## de 80 ms y cinco más de 100-140 ms. Ahora todo eso entra acá y se crea a lo largo de los cuadros siguientes,
## gastando como mucho `FRAME_BUDGET_USEC` por cuadro (se ve como una explosión en cadena de una fracción de segundo).
##
## - Gore y explosión de muerte: si esperan más de `GORE_MAX_AGE` se descartan (en una masacre nadie lo nota).
## - Botín y orbes: nunca se pierden. Siempre salen al menos `LOOT_MIN_PER_FRAME` por cuadro y, si se acumulan
##   más de `LOOT_BACKLOG_MERGE`, salen ya fundidos (hasta 10 del mismo tipo en una pieza que vale la suma,
##   igual que `core/loot/loot_combiner.gd`).
## Una sola cola por escena (nodo `DeathFxQueue` en la escena actual), creada al primer uso.

const BloodFx = preload("res://combat/blood_fx.gd")

const NODE_NAME: String = "DeathFxQueue"
const FRAME_BUDGET_USEC: int = 2500
const GORE_MAX_AGE_MSEC: int = 500
const LOOT_MIN_PER_FRAME: int = 4
const LOOT_BACKLOG_MERGE: int = 30
const MERGE_BATCH: int = 10
## Cuántas entradas mira hacia adelante para juntar las del mismo tipo.
const MERGE_LOOKAHEAD: int = 40
const SPAWN_OFFSET: Vector2 = Vector2(0.0, -16.0)
## La experiencia que sueltan los enemigos se reduce a la mitad (el botín se reduce en LootTable.DROP_AMOUNT_MULT).
const EXP_MULT: float = 0.5

var _gore: Array[Dictionary] = []
var _loot: Array[Dictionary] = []
var dropped_gore: int = 0
## Experiencia que trae cada escena de orbe (para los que se encolan sin valor propio).
var _default_exp: Dictionary = {}


# ==============================================================================
# API (estática)
# ==============================================================================

## Explosión de muerte (chispas, destello y sonido) de `GameFeel.death_burst`.
static func burst(ctx: Node, pos: Vector2) -> void:
	var queue: Node = _get_queue(ctx)
	if queue == null:
		GameFeel.death_burst(ctx, pos)
		return
	queue.call("_push_gore", {"kind": "burst", "pos": pos})


## Lluvia de trozos, salpicaduras y charcos del final de `DamageFx`.
static func gore(ctx: Node, pos: Vector2, mechanical: bool, size_scale: float = 1.0, amount: float = 1.0) -> void:
	var queue: Node = _get_queue(ctx)
	if queue == null:
		return
	queue.call("_push_gore", {"kind": "gore", "pos": pos, "mechanical": mechanical, "size": size_scale, "amount": amount})


## Una pieza de botín (`LootDrop`). `pos` es la posición del enemigo.
static func loot(ctx: Node, scene: PackedScene, item_type: String, amount: int, pos: Vector2) -> void:
	var queue: Node = _get_queue(ctx)
	if queue == null or scene == null:
		return
	queue.call("_push_loot", {"scene": scene, "type": item_type.to_upper(), "value": float(amount), "pos": pos + SPAWN_OFFSET})


## Un orbe de experiencia. `exp_amount < 0` deja el valor que trae la escena.
static func exp_orb(ctx: Node, scene: PackedScene, exp_amount: float, pos: Vector2) -> void:
	var queue: Node = _get_queue(ctx)
	if queue == null or scene == null:
		return
	queue.call("_push_loot", {"scene": scene, "type": "EXP", "value": exp_amount, "pos": pos + SPAWN_OFFSET})


static func _get_queue(ctx: Node) -> Node:
	if ctx == null or not ctx.is_inside_tree():
		return null
	var scene: Node = ctx.get_tree().current_scene
	if scene == null:
		return null
	var queue: Node = scene.get_node_or_null(NODE_NAME)
	if queue == null:
		queue = (load("res://combat/death_fx_queue.gd") as GDScript).new() as Node
		queue.name = NODE_NAME
		# Se agrega ya para que la busquen las muertes siguientes del mismo cuadro; si la escena todavía
		# se está armando, diferido (las entradas se acumulan igual en el nodo)
		if scene.is_node_ready():
			scene.add_child(queue)
		else:
			scene.add_child.call_deferred(queue)
	return queue


## Entradas esperando (gore + botín); la Sala de Estrés lo muestra en el registro.
func pending() -> int:
	return _gore.size() + _loot.size()


func _push_gore(entry: Dictionary) -> void:
	entry["t"] = Time.get_ticks_msec()
	_gore.append(entry)


func _push_loot(entry: Dictionary) -> void:
	_loot.append(entry)


# ==============================================================================
# Proceso por cuadro
# ==============================================================================

func _process(_delta: float) -> void:
	if _gore.is_empty() and _loot.is_empty():
		return
	var started: int = Time.get_ticks_usec()
	var now: int = Time.get_ticks_msec()

	# Botín primero: nunca se descarta
	var spawned: int = 0
	while not _loot.is_empty():
		if spawned >= LOOT_MIN_PER_FRAME and Time.get_ticks_usec() - started >= FRAME_BUDGET_USEC / 2:
			break
		_spawn_next_loot()
		spawned += 1

	# Gore con lo que quede de presupuesto (al menos una entrada por cuadro); lo viejo se tira
	var done: int = 0
	while not _gore.is_empty():
		var entry: Dictionary = _gore.pop_front()
		if now - int(entry["t"]) > GORE_MAX_AGE_MSEC:
			dropped_gore += 1
			continue
		_run_gore(entry)
		done += 1
		if Time.get_ticks_usec() - started >= FRAME_BUDGET_USEC:
			break


func _run_gore(entry: Dictionary) -> void:
	var pos: Vector2 = entry["pos"]
	match str(entry["kind"]):
		"burst":
			GameFeel.death_burst(self, pos)
		"gore":
			var mechanical: bool = bool(entry["mechanical"])
			var host: Node2D = _host()
			var size_scale: float = float(entry.get("size", 1.0))
			var amount: float = float(entry.get("amount", 1.0))
			BloodFx.gibs(host, pos, maxi(1, roundi(6.0 * amount)), mechanical, 1.0, size_scale)
			BloodFx.spray(host, pos, Vector2.UP, 60.0 * amount, mechanical)
			if amount >= 0.7:
				BloodFx.spray(host, pos + Vector2(0.0, 6.0), Vector2.LEFT, 40.0, mechanical)
				BloodFx.spray(host, pos + Vector2(0.0, 6.0), Vector2.RIGHT, 40.0, mechanical)
				BloodFx.spray_sprite(host, pos, Vector2.UP, 90.0)
				BloodFx.spray_sprite(host, pos, Vector2.from_angle(deg_to_rad(-30.0)), 70.0)
				BloodFx.spray_sprite(host, pos, Vector2.from_angle(deg_to_rad(-150.0)), 70.0)
			BloodFx.stains(host, pos, Vector2.ZERO, maxi(1, roundi(6.0 * amount)), lerpf(0.9, 1.9, amount), mechanical)


## BloodFx necesita un Node2D en el árbol para ubicar el contenedor y el espacio de física.
func _host() -> Node2D:
	var scene: Node2D = get_parent() as Node2D
	return scene if scene != null else get_tree().get_first_node_in_group(&"player") as Node2D


func _spawn_next_loot() -> void:
	var first: Dictionary = _loot.pop_front()
	var batch: Array[Dictionary] = [first]
	# Con mucho atraso, sale ya fundido: junta las siguientes del mismo tipo
	if _loot.size() >= LOOT_BACKLOG_MERGE:
		var i: int = 0
		while i < mini(_loot.size(), MERGE_LOOKAHEAD) and batch.size() < MERGE_BATCH:
			var other: Dictionary = _loot[i]
			if str(other["type"]) == str(first["type"]) and other["scene"] == first["scene"]:
				batch.append(other)
				_loot.remove_at(i)
			else:
				i += 1
	var item_type: String = str(first["type"])
	var total: float = 0.0
	var center: Vector2 = Vector2.ZERO
	for entry: Dictionary in batch:
		var value: float = float(entry["value"])
		if item_type == "EXP" and value < 0.0:
			value = _scene_default_exp(entry["scene"] as PackedScene)
		if item_type == "EXP":
			value *= EXP_MULT
		total += value
		center += entry["pos"] as Vector2
	center /= float(batch.size())

	var node: Node2D = (first["scene"] as PackedScene).instantiate() as Node2D
	if node == null:
		return
	node.global_position = center
	get_parent().add_child(node)
	if item_type == "EXP":
		node.set("exp_amount", total)
	elif node.has_method("setup"):
		node.call("setup", item_type, maxi(1, int(roundf(total))))
	if batch.size() >= MERGE_BATCH and node.has_method("upgrade_merge"):
		node.call("upgrade_merge", 1, total)


func _scene_default_exp(scene: PackedScene) -> float:
	if not _default_exp.has(scene):
		var probe: Node = scene.instantiate()
		_default_exp[scene] = float(probe.get("exp_amount")) if "exp_amount" in probe else 0.0
		probe.free()
	return float(_default_exp[scene])
