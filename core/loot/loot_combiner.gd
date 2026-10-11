extends Node
## Junta el botín que se acumula en el piso para que haya menos objetos en escena.
## Sin class_name a propósito: se carga por `preload` desde `LootDrop` y `ExpOrb` (ver class-name-cache-gotcha).
##
## Cada `CHECK_INTERVAL` revisa los grupos `loot_drops` (monedas, munición, vida) y `exp_orbs` (experiencia), los reparte
## en celdas de `CELL_SIZE` px y, si en una celda y sus 8 vecinas hay `MERGE_COUNT` del mismo tipo y nivel quietos, los funde en
## uno del nivel siguiente que vale la suma (se sigue cobrando el mismo total). El nivel tope sigue
## fundiéndose en sí mismo, así la cantidad de objetos queda acotada aunque nadie junte nada.
## No conoce las clases: les pide `can_merge()`, `merge_kind()`, `merge_tier`, `merge_value()`, `upgrade_merge()` y `absorb_into()`.
## Un solo combinador por escena, creado la primera vez que aparece botín (`ensure()`).

const NODE_NAME: String = "LootCombiner"
const CHECK_INTERVAL: float = 0.4
const CELL_SIZE: float = 128.0
const MERGE_COUNT: int = 10
const GROUPS: Array[StringName] = [&"loot_drops", &"exp_orbs"]

var _timer: float = 0.0


## Crea el combinador en la escena actual si todavía no existe.
static func ensure(context: Node) -> void:
	if context == null or not context.is_inside_tree():
		return
	var scene: Node = context.get_tree().current_scene
	if scene == null or scene.get_node_or_null(NODE_NAME) != null:
		return
	var combiner: Node = (load("res://core/loot/loot_combiner.gd") as GDScript).new() as Node
	combiner.name = NODE_NAME
	scene.add_child.call_deferred(combiner)


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer < CHECK_INTERVAL:
		return
	_timer = 0.0
	for group: StringName in GROUPS:
		_combine_group(group)


func _combine_group(group: StringName) -> void:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group)
	if nodes.size() < MERGE_COUNT:
		return
	var cells: Dictionary = {}
	for node: Node in nodes:
		var item: Node2D = node as Node2D
		if item == null or not bool(item.call("can_merge")):
			continue
		var pos: Vector2 = item.global_position
		var cell: Vector2i = Vector2i(floori(pos.x / CELL_SIZE), floori(pos.y / CELL_SIZE))
		var kind: String = "%s|%d" % [str(item.call("merge_kind")), int(item.get("merge_tier"))]
		if not cells.has(kind):
			cells[kind] = {}
		var by_cell: Dictionary = cells[kind]
		if not by_cell.has(cell):
			by_cell[cell] = []
		(by_cell[cell] as Array).append(item)

	# Cada celda junta con sus 8 vecinas (área de 3x3 celdas): así no importa si el montón cae en un borde
	var used: Dictionary = {}
	for kind: String in cells.keys():
		var by_cell: Dictionary = cells[kind]
		var tier: int = int(kind.get_slice("|", 1))
		for cell: Vector2i in by_cell.keys():
			var pool: Array = []
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var near: Vector2i = cell + Vector2i(dx, dy)
					if not by_cell.has(near):
						continue
					for item: Node2D in by_cell[near]:
						if not used.has(item.get_instance_id()):
							pool.append(item)
			while pool.size() >= MERGE_COUNT:
				var batch: Array = pool.slice(0, MERGE_COUNT)
				pool = pool.slice(MERGE_COUNT)
				for item: Node2D in batch:
					used[item.get_instance_id()] = true
				_merge(batch, tier)


func _merge(batch: Array, tier: int) -> void:
	var target: Node2D = batch[0] as Node2D
	var total: float = 0.0
	var center: Vector2 = Vector2.ZERO
	for item: Node2D in batch:
		total += float(item.call("merge_value"))
		center += item.global_position
	center /= float(batch.size())
	target.global_position = Vector2(center.x, target.global_position.y)
	for i: int in range(1, batch.size()):
		(batch[i] as Node2D).call("absorb_into", target.global_position)
	target.call("upgrade_merge", tier + 1, total)
