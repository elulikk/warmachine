class_name InventoryManager
extends Node
## Gestor de la Mochila del Jugador con capacidad de 20 casilleros.
## Administra adición, remoción, intercambio y persistencia de recursos en el inventario.

signal inventory_updated
signal item_added(res: Resource, slot_index: int)
signal item_removed(res: Resource, slot_index: int)

const CAPACITY: int = 20
const CodexScript = preload("res://core/codex/codex.gd")

var backpack: Array[Resource] = []


func _ready() -> void:
	init_backpack()


func init_backpack() -> void:
	backpack.clear()
	for i in range(CAPACITY):
		backpack.append(null)


## Intenta añadir un ítem al primer casillero libre de la mochila.
func add_item(res: Resource) -> bool:
	if res == null:
		return false
	
	for i in range(backpack.size()):
		if backpack[i] == null:
			backpack[i] = res
			CodexScript.record_weapon(res)
			item_added.emit(res, i)
			inventory_updated.emit()
			print("[InventoryManager] Ítem agregado al slot %d de la mochila." % i)
			return true
	
	print("[InventoryManager] Mochila llena. No se pudo agregar el ítem.")
	return false


## Retira y retorna el ítem en la posición indicada.
func remove_item_at(index: int) -> Resource:
	if index < 0 or index >= backpack.size():
		return null
	
	var item: Resource = backpack[index]
	backpack[index] = null
	if item != null:
		item_removed.emit(item, index)
		inventory_updated.emit()
	return item


## Intercambia dos casilleros dentro de la mochila.
func swap_slots(idx_a: int, idx_b: int) -> void:
	if idx_a < 0 or idx_a >= backpack.size() or idx_b < 0 or idx_b >= backpack.size():
		return
	
	var temp: Resource = backpack[idx_a]
	backpack[idx_a] = backpack[idx_b]
	backpack[idx_b] = temp
	inventory_updated.emit()


## Coloca un ítem en un slot específico, retornando el ítem previo si lo había.
func set_item_at(index: int, res: Resource) -> Resource:
	if index < 0 or index >= backpack.size():
		return null
	
	var old: Resource = backpack[index]
	backpack[index] = res
	inventory_updated.emit()
	return old


## Obtiene el recurso en un slot determinado.
func get_item_at(index: int) -> Resource:
	if index < 0 or index >= backpack.size():
		return null
	return backpack[index]


## Comprueba si la mochila tiene al menos un espacio libre.
func has_free_space() -> bool:
	for slot in backpack:
		if slot == null:
			return true
	return false


## Serializa el contenido de la mochila en un array (rutas .tres o diccionarios con runas para armas).
func serialize_to_paths() -> Array:
	var paths: Array = []
	for res in backpack:
		if res != null:
			if res is WeaponData:
				var wpn: WeaponData = res as WeaponData
				var r_path: String = wpn.resource_path if not wpn.resource_path.is_empty() else wpn.source_resource_path
				var runes_paths: Array[String] = []
				for r in wpn.socketed_runes:
					if r != null and not r.resource_path.is_empty():
						runes_paths.append(r.resource_path)
				if runes_paths.is_empty():
					paths.append(r_path)
				else:
					paths.append({
						"path": r_path,
						"runes": runes_paths
					})
			else:
				paths.append(res.resource_path)
		else:
			paths.append("")
	return paths


## Carga los ítems de la mochila desde un array de rutas .tres o diccionarios de armas.
func deserialize_from_paths(paths: Array) -> void:
	init_backpack()
	for i in range(mini(paths.size(), CAPACITY)):
		var entry: Variant = paths[i]
		if typeof(entry) == TYPE_STRING:
			var path_str: String = str(entry)
			if not path_str.is_empty() and ResourceLoader.exists(path_str):
				var res: Resource = load(path_str)
				if res != null:
					if res is WeaponData:
						var w_inst: WeaponData = (res as WeaponData).duplicate()
						w_inst.source_resource_path = path_str
						backpack[i] = w_inst
					else:
						backpack[i] = res
		elif typeof(entry) == TYPE_DICTIONARY:
			var dict: Dictionary = entry as Dictionary
			var path_str: String = str(dict.get("path", ""))
			if not path_str.is_empty() and ResourceLoader.exists(path_str):
				var res: Resource = load(path_str)
				if res is WeaponData:
					var w_inst: WeaponData = (res as WeaponData).duplicate()
					w_inst.source_resource_path = path_str
					w_inst.socketed_runes.clear()
					var raw_runes: Array = dict.get("runes", [])
					for r_path in raw_runes:
						var r_str: String = str(r_path)
						if not r_str.is_empty() and ResourceLoader.exists(r_str):
							var r_res: RuneData = load(r_str) as RuneData
							if r_res != null:
								w_inst.socket_rune(r_res)
					backpack[i] = w_inst
				elif res != null:
					backpack[i] = res
	inventory_updated.emit()
