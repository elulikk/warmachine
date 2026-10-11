class_name SaveManager
extends Node
## Administrador central de persistencia y archivos locales en disco.
## Gestiona archivos JSON en user://saves/slot_{id}.json con 3 slots de guardado,
## datos de progresión (nivel, exp, monedas), armas y equipamiento activo,
## mochila del jugador, baúl ilimitado (stash_items) y flags de mundo.

signal flag_changed(id: String, val: bool)
signal game_saved(slot_id: int)
signal game_loaded(slot_id: int)

const SAVE_DIR: String = "user://saves"
const MAX_SLOTS: int = 3

static var instance: SaveManager = null
static var active_slot_id: int = 1
## Mientras sea true, `save_to_disk()` no escribe nada. Lo activa la Sala de Estrés para que el botín,
## la experiencia y lo que pase adentro no se guarde (al volver, el campamento recarga el slot del disco).
static var saving_suspended: bool = false
const LAST_SLOT_FILE: String = "user://saves/last_active_slot.txt"
## Ranura nueva -> clave del esquema anterior, para leer partidas guardadas antes del rediseño de ranuras.
const LEGACY_EQUIP_KEYS: Dictionary = {
	"BOOTS": "FEET",
	"CHEST": "ARMOR",
	"BACK": "BODY",
	"ACCESSORY_1": "ACCESSORY"
}

var current_slot: int:
	get:
		return active_slot_id
	set(value):
		active_slot_id = clampi(value, 1, MAX_SLOTS)
		save_last_active_slot()

var character_name: String = "OPERADOR"
## Contenido del baúl. Cada entrada es una ruta `.tres` (String) o, para armas con runas, un
## Dictionary {"path": String, "runes": Array[String]}. Usar los helpers stash_* para leerlas.
var stash_items: Array = []
## Estado persistido de cada comerciante (stock limitado y recompra), por `trader_id`.
## Lo escribe `TradeSession` (core/trade/trade_session.gd); una clave ausente significa estado inicial.
var trade_state: Dictionary = {}
var unlocked_levels: Array[String] = ["res://levels/chapter_1/level_1_01.tscn"]

var world_flags: Dictionary = {}
var last_checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	instance = self
	add_to_group(&"save_manager")
	_ensure_save_dir()
	load_last_active_slot()


static func get_instance() -> SaveManager:
	return instance


## Al cerrar la ventana del juego se guarda la partida en curso (equipo, armas, mochila, baúl).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		var player: Player = get_tree().get_first_node_in_group(&"player") as Player
		if player != null and not character_name.is_empty():
			save_to_disk()


# ==============================================================================
# Baúl: conversión entre entradas guardadas y recursos
# ==============================================================================

## Ruta `.tres` de una entrada del baúl (String o Dictionary con "path").
static func stash_entry_path(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str((entry as Dictionary).get("path", ""))
	return str(entry)


## Indica si el baúl contiene un recurso con esa ruta (sin importar sus runas).
func stash_has_path(path: String) -> bool:
	for entry: Variant in stash_items:
		if stash_entry_path(entry) == path:
			return true
	return false


## Crea un recurso independiente a partir de una entrada del baúl (las armas se duplican con sus runas).
static func stash_entry_to_resource(entry: Variant) -> Resource:
	var path_str: String = stash_entry_path(entry)
	if path_str.is_empty() or not ResourceLoader.exists(path_str):
		return null
	var res: Resource = load(path_str)
	var weapon: WeaponData = res as WeaponData
	if weapon == null:
		return res

	var instance_copy: WeaponData = weapon.duplicate() as WeaponData
	instance_copy.source_resource_path = path_str
	instance_copy.socketed_runes.clear()
	if typeof(entry) == TYPE_DICTIONARY:
		var raw_runes: Array = (entry as Dictionary).get("runes", [])
		for rune_path: Variant in raw_runes:
			var rune_str: String = str(rune_path)
			if not rune_str.is_empty() and ResourceLoader.exists(rune_str):
				var rune: RuneData = load(rune_str) as RuneData
				if rune != null:
					instance_copy.socket_rune(rune)
	return instance_copy


## Convierte un recurso en entrada del baúl. Retorna null si no se puede guardar por ruta.
static func stash_resource_to_entry(res: Resource) -> Variant:
	if res == null:
		return null
	var weapon: WeaponData = res as WeaponData
	if weapon != null:
		var path_str: String = weapon.resource_path if not weapon.resource_path.is_empty() else weapon.source_resource_path
		if path_str.is_empty():
			return null
		var rune_paths: Array[String] = []
		for rune: RuneData in weapon.socketed_runes:
			if rune != null and not rune.resource_path.is_empty():
				rune_paths.append(rune.resource_path)
		if rune_paths.is_empty():
			return path_str
		return {"path": path_str, "runes": rune_paths}
	if res.resource_path.is_empty():
		return null
	return res.resource_path


static func save_last_active_slot() -> void:
	var f: FileAccess = FileAccess.open(LAST_SLOT_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(str(active_slot_id))
		f.close()


static func load_last_active_slot() -> void:
	if FileAccess.file_exists(LAST_SLOT_FILE):
		var f: FileAccess = FileAccess.open(LAST_SLOT_FILE, FileAccess.READ)
		if f != null:
			var txt: String = f.get_as_text().strip_edges()
			f.close()
			if txt.is_valid_int():
				active_slot_id = clampi(txt.to_int(), 1, MAX_SLOTS)


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# ==============================================================================
# Métodos Estáticos de Compatibilidad con Sistemas Previos
# ==============================================================================

static func set_world_flag(id: String, val: bool = true) -> void:
	if instance != null:
		instance.set_flag(id, val)


static func has_world_flag(id: String) -> bool:
	if instance != null:
		return instance.has_flag(id)
	return false


static func get_world_flag(id: String, default_value: bool = false) -> bool:
	if instance != null:
		return instance.get_flag(id, default_value)
	return default_value


static func set_respawn_point(pos: Vector2) -> void:
	if instance != null:
		instance.last_checkpoint_position = pos
		instance.has_checkpoint = true
		print("[SaveManager] Punto de reaparición actualizado a: %s" % pos)


static func get_respawn_point(default_pos: Vector2 = Vector2.ZERO) -> Vector2:
	if instance != null and instance.has_checkpoint:
		return instance.last_checkpoint_position
	return default_pos


static func has_respawn_point() -> bool:
	if instance != null:
		return instance.has_checkpoint
	return false


static func clear_world_flags() -> void:
	if instance != null:
		instance.clear_flags()
	print("[SaveManager] Flags reiniciados estáticamente.")


func set_flag(id: String, val: bool = true) -> void:
	world_flags[id] = val
	flag_changed.emit(id, val)
	print("[SaveManager] Flag '%s' establecido en: %s" % [id, val])


func has_flag(id: String) -> bool:
	return bool(world_flags.get(id, false))


func get_flag(id: String, default_value: bool = false) -> bool:
	return bool(world_flags.get(id, default_value))


func clear_flags() -> void:
	world_flags.clear()
	last_checkpoint_position = Vector2.ZERO
	has_checkpoint = false
	print("[SaveManager] Persistencia y checkpoints reiniciados.")


# ==============================================================================
# Persistencia Real a Disco con 3 Slots (JSON)
# ==============================================================================

func get_slot_path(slot_id: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, clampi(slot_id, 1, MAX_SLOTS)]


## Guarda todo el estado de la partida en el slot actual a disco.
func save_to_disk() -> bool:
	if saving_suspended:
		return false
	_ensure_save_dir()
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	
	var level_val: int = 1
	var exp_val: float = 0.0
	var exp_next_val: float = 100.0
	var coins_val: int = 0
	
	if player != null and player.stats_manager != null:
		level_val = player.stats_manager.level
		exp_val = player.stats_manager.current_exp
		exp_next_val = player.stats_manager.exp_to_next_level
		coins_val = player.stats_manager.coins
	
	# Armas activas y sus runas
	var weapons_data: Array[Dictionary] = []
	var active_weapon_index: int = 0
	if player != null and player.weapon_manager != null:
		active_weapon_index = player.weapon_manager.current_weapon_index
		for w in player.weapon_manager.weapons:
			if w != null:
				var path_to_save: String = w.resource_path if not w.resource_path.is_empty() else w.source_resource_path
				if path_to_save.is_empty():
					var known_paths: Dictionary = {
						"Cuchillo de Combate": "res://data/weapons/combat_knife.tres",
						"Pistola Criogénica": "res://data/weapons/pistol.tres",
						"Pistola": "res://data/weapons/pistol.tres",
						"Subfusil": "res://data/weapons/smg.tres",
						"SMG Táctico": "res://data/weapons/smg.tres",
						"Katana de Asalto": "res://data/weapons/katana.tres",
						"Katana": "res://data/weapons/katana.tres",
						"Martillo Pesado": "res://data/weapons/heavy_hammer.tres",
						"Espada de Hierro": "res://data/weapons/iron_sword.tres",
						"Lanzallamas de Plasma": "res://data/weapons/plasma_flamethrower.tres",
						"Bláster Corrosivo": "res://data/weapons/corrosive_blaster.tres"
					}
					path_to_save = str(known_paths.get(w.weapon_name, ""))
				if not path_to_save.is_empty():
					w.source_resource_path = path_to_save
					var runes_paths: Array[String] = []
					for r in w.socketed_runes:
						if r != null and not r.resource_path.is_empty():
							runes_paths.append(r.resource_path)
					weapons_data.append({
						"path": path_to_save,
						"runes": runes_paths
					})
	
	# Equipamiento fijo
	var equip_data: Dictionary = {}
	if player != null and player.equipment_manager != null:
		for slot in EquipmentManager.VALID_SLOTS:
			var itm: ItemData = player.equipment_manager.get_equipped_item(slot)
			equip_data[slot] = itm.resource_path if itm != null else ""
	
	# Mochila del jugador
	var backpack_paths: Array = []
	if player != null:
		var inv_mgr: Node = player.get_node_or_null("InventoryManager")
		if inv_mgr != null and inv_mgr.has_method("serialize_to_paths"):
			backpack_paths = inv_mgr.serialize_to_paths()
	
	# Consumibles (cantidades por tipo)
	var consumables_data: Dictionary = {}
	if player != null and player.consumable_manager != null:
		consumables_data = player.consumable_manager.serialize()

	# Barra de acceso rápido (referencias a armas por índice del arsenal, consumibles por id)
	var hotbar_data: Array = []
	if player != null:
		hotbar_data = player.hotbar_layout.duplicate()

	var metrics_dict: Dictionary = {}
	var metrics_mgr: MetricsManager = MetricsManager.get_instance()
	if metrics_mgr != null:
		metrics_dict = metrics_mgr.serialize()
	
	var save_dict: Dictionary = {
		"slot_id": current_slot,
		"character_name": character_name,
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"unlocked_levels": unlocked_levels,
		"world_flags": world_flags,
		"stats": {
			"level": level_val,
			"current_exp": exp_val,
			"exp_to_next_level": exp_next_val,
			"coins": coins_val
		},
		"weapons": weapons_data,
		"active_weapon": active_weapon_index,
		"equipment": equip_data,
		"backpack": backpack_paths,
		"consumables": consumables_data,
		"hotbar": hotbar_data,
		"stash_items": stash_items,
		"trade_state": trade_state,
		"metrics": metrics_dict
	}
	
	var file_path: String = get_slot_path(current_slot)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Error al abrir archivo para guardar: %s" % file_path)
		return false
	
	var json_str: String = JSON.stringify(save_dict, "\t")
	file.store_string(json_str)
	file.close()
	
	game_saved.emit(current_slot)
	print("[SaveManager] Partida guardada exitosamente en: %s" % file_path)
	return true


## Carga y aplica los datos guardados de un slot específico.
func load_from_disk(slot_id: int) -> bool:
	_ensure_save_dir()
	current_slot = clampi(slot_id, 1, MAX_SLOTS)
	var file_path: String = get_slot_path(current_slot)
	
	if not FileAccess.file_exists(file_path):
		print("[SaveManager] Archivo no encontrado para Slot %d: %s. Creando nueva partida." % [current_slot, file_path])
		_init_new_profile()
		return false
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Error al abrir archivo de guardado: %s" % file_path)
		return false
	
	var content: String = file.get_as_text()
	file.close()
	
	var test_json: Variant = JSON.parse_string(content)
	if typeof(test_json) != TYPE_DICTIONARY:
		push_error("[SaveManager] Formato JSON inválido en %s" % file_path)
		return false
	
	var data: Dictionary = test_json as Dictionary
	
	# Deserializar variables base
	character_name = str(data.get("character_name", "OPERADOR"))
	if character_name.is_empty():
		character_name = "OPERADOR"
	
	unlocked_levels.clear()
	var raw_unlocked: Array = data.get("unlocked_levels", ["res://levels/chapter_1/level_1_01.tscn"])
	for ul in raw_unlocked:
		unlocked_levels.append(str(ul))
	if not unlocked_levels.has("res://levels/chapter_1/level_1_01.tscn"):
		unlocked_levels.append("res://levels/chapter_1/level_1_01.tscn")
	
	world_flags = data.get("world_flags", {})
	
	stash_items.clear()
	var raw_stash: Array = data.get("stash_items", [])
	for si in raw_stash:
		if typeof(si) == TYPE_DICTIONARY:
			stash_items.append(si)
		else:
			stash_items.append(str(si))
	
	# Estado de comerciantes (guardados anteriores no lo traen: arranca vacío)
	trade_state = {}
	var raw_trade: Variant = data.get("trade_state", {})
	if typeof(raw_trade) == TYPE_DICTIONARY:
		trade_state = raw_trade as Dictionary
	
	# Restaurar métricas acumuladas en MetricsManager
	var metrics_mgr: MetricsManager = MetricsManager.get_instance()
	if metrics_mgr != null:
		var raw_metrics: Variant = data.get("metrics", {})
		if typeof(raw_metrics) == TYPE_DICTIONARY:
			metrics_mgr.deserialize(raw_metrics as Dictionary)
		else:
			metrics_mgr.reset_metrics()
	
	# Restaurar al Jugador si existe en la escena
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		apply_data_to_player(player, data)
	
	game_loaded.emit(current_slot)
	print("[SaveManager] Slot %d cargado exitosamente desde disco. Personaje: %s" % [current_slot, character_name])
	return true


## Crea un nuevo personaje en un slot determinado guardándolo a disco.
func create_character(slot_id: int, char_name: String) -> bool:
	_ensure_save_dir()
	current_slot = clampi(slot_id, 1, MAX_SLOTS)
	character_name = char_name.strip_edges()
	if character_name.is_empty():
		character_name = "OPERADOR"
	
	_init_new_profile()
	var saved: bool = save_to_disk()
	if saved:
		print("[SaveManager] Personaje '%s' creado con éxito en Slot %d." % [character_name, current_slot])
	return saved


## Aplica los datos leídos de disco a una instancia concreta de Player.
func apply_data_to_player(player: Player, data: Dictionary) -> void:
	if player == null:
		return
	
	# 1. Estadísticas
	var stats: Dictionary = data.get("stats", {})
	if player.stats_manager != null and not stats.is_empty():
		player.stats_manager.level = clampi(int(stats.get("level", 1)), 1, StatsManager.MAX_LEVEL)
		player.stats_manager.current_exp = float(stats.get("current_exp", 0.0))
		player.stats_manager.exp_to_next_level = float(stats.get("exp_to_next_level", 150.0))
		player.stats_manager.coins = int(stats.get("coins", 0))
		player.stats_manager.current_health = player.stats_manager.get_max_health()
		player.stats_manager.coins_changed.emit(player.stats_manager.coins)
		player.stats_manager.exp_changed.emit(player.stats_manager.current_exp, player.stats_manager.exp_to_next_level)
		player.stats_manager.leveled_up.emit(player.stats_manager.level)
		player.stats_manager.health_changed.emit(player.stats_manager.current_health, player.stats_manager.get_max_health())
	
	# 2. Armas
	if player.weapon_manager != null:
		player.weapon_manager.weapons.clear()
		var raw_weapons: Array = data.get("weapons", [])
		for w_entry in raw_weapons:
			if typeof(w_entry) == TYPE_DICTIONARY:
				var w_dict: Dictionary = w_entry as Dictionary
				var w_path: String = str(w_dict.get("path", ""))
				if not w_path.is_empty() and ResourceLoader.exists(w_path):
					var loaded_w: WeaponData = load(w_path) as WeaponData
					if loaded_w != null:
						var w_inst: WeaponData = loaded_w.duplicate()
						w_inst.source_resource_path = w_path
						w_inst.socketed_runes.clear()
						var raw_runes: Array = w_dict.get("runes", [])
						for r_path in raw_runes:
							var r_str: String = str(r_path)
							if not r_str.is_empty() and ResourceLoader.exists(r_str):
								var r_res: RuneData = load(r_str) as RuneData
								if r_res != null:
									w_inst.socket_rune(r_res)
						player.weapon_manager.weapons.append(w_inst)
		# Siempre se llama: con arsenal vacío limpia el arma activa (el personaje queda sin armas)
		var active_idx: int = int(data.get("active_weapon", 0))
		player.weapon_manager.select_weapon(clampi(active_idx, 0, maxi(0, player.weapon_manager.weapons.size() - 1)))
	
	# 3. Equipamiento fijo
	if player.equipment_manager != null:
		var equip_dict: Dictionary = data.get("equipment", {})
		for slot in EquipmentManager.VALID_SLOTS:
			var itm_path: String = str(equip_dict.get(slot, ""))
			# Partidas guardadas con el esquema anterior de ranuras
			if itm_path.is_empty() and LEGACY_EQUIP_KEYS.has(slot):
				itm_path = str(equip_dict.get(LEGACY_EQUIP_KEYS[slot], ""))
			if not itm_path.is_empty() and ResourceLoader.exists(itm_path):
				var itm_res: ItemData = load(itm_path) as ItemData
				if itm_res != null:
					player.equipment_manager.equip_item(slot, itm_res)
			else:
				player.equipment_manager.unequip_item(slot)
	
	# 4. Mochila
	if player != null:
		var inv_mgr: Node = player.get_node_or_null("InventoryManager")
		if inv_mgr != null and inv_mgr.has_method("deserialize_from_paths"):
			var raw_bp: Array = data.get("backpack", [])
			inv_mgr.deserialize_from_paths(raw_bp)

	# 5. Consumibles
	if player.consumable_manager != null:
		var raw_consumables: Variant = data.get("consumables", {})
		if typeof(raw_consumables) == TYPE_DICTIONARY:
			player.consumable_manager.deserialize(raw_consumables as Dictionary)

	# 6. Barra de acceso rápido (la resuelve la barra contra el arsenal al enlazarse)
	player.hotbar_layout = []
	var raw_hotbar: Variant = data.get("hotbar", [])
	if typeof(raw_hotbar) == TYPE_ARRAY:
		player.hotbar_layout = (raw_hotbar as Array).duplicate()


## Devuelve un resumen para el selector de partidas del menú (Nombre, Nivel, Monedas, Fecha o Inexistente).
func get_slot_preview(slot_id: int) -> Dictionary:
	_ensure_save_dir()
	var file_path: String = get_slot_path(slot_id)
	if not FileAccess.file_exists(file_path):
		return {
			"exists": false,
			"slot_id": slot_id
		}
	
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"exists": false, "slot_id": slot_id}
	
	var content: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"exists": false, "slot_id": slot_id}
	
	var dict: Dictionary = parsed as Dictionary
	var stats: Dictionary = dict.get("stats", {})
	var char_n: String = str(dict.get("character_name", "OPERADOR"))
	var timestamp: String = str(dict.get("timestamp", "Desconocido"))
	var lvl: int = int(stats.get("level", 1))
	var cns: int = int(stats.get("coins", 0))
	
	return {
		"exists": true,
		"slot_id": slot_id,
		"name": char_n,
		"level": lvl,
		"coins": cns,
		"timestamp": timestamp
	}


## Elimina el archivo de guardado de un slot y reinicia variables si era el slot activo.
func delete_character(slot_id: int) -> bool:
	_ensure_save_dir()
	var file_path: String = get_slot_path(slot_id)
	var removed: bool = true
	if FileAccess.file_exists(file_path):
		var err: Error = DirAccess.remove_absolute(file_path)
		removed = (err == OK)
	
	if slot_id == current_slot:
		character_name = "OPERADOR"
		_init_new_profile()
	
	print("[SaveManager] Personaje en Slot %d eliminado. Éxito: %s" % [slot_id, removed])
	return removed


## Compatibilidad hacia atrás
func delete_slot(slot_id: int) -> bool:
	return delete_character(slot_id)


func _init_new_profile() -> void:
	unlocked_levels = ["res://levels/chapter_1/level_1_01.tscn"]
	stash_items.clear()
	trade_state.clear()
	world_flags.clear()
	has_checkpoint = false
	last_checkpoint_position = Vector2.ZERO
	var metrics_mgr: MetricsManager = MetricsManager.get_instance()
	if metrics_mgr != null:
		metrics_mgr.reset_metrics()
