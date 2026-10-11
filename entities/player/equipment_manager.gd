class_name EquipmentManager
extends Node
## Administrador de ranuras de equipamiento fijo para el Jugador (HEAD, CHEST, GLOVES, BOOTS, BACK,
## ACCESSORY_1, ACCESSORY_2, TACTICAL).
## Controla la aplicación y desuscripción de modificadores de estadísticas en el StatsManager
## y confiere infusiones elementales (como "FIRE_INFUSION") a los proyectiles del arma activa.

signal item_equipped(slot: String, item: ItemData)
signal item_unequipped(slot: String, item: ItemData)

## Casco: armadura menor y bonos de combate.
const SLOT_HEAD: String = "HEAD"
## Pecho: armadura corporal (mitigación de daño).
const SLOT_CHEST: String = "CHEST"
const SLOT_GLOVES: String = "GLOVES"
const SLOT_BOOTS: String = "BOOTS"
## Espalda (jetpack o alas). Independiente del pecho para poder combinarla con la armadura.
const SLOT_BACK: String = "BACK"
const SLOT_ACCESSORY_1: String = "ACCESSORY_1"
const SLOT_ACCESSORY_2: String = "ACCESSORY_2"
const SLOT_TACTICAL: String = "TACTICAL"
## Categoría de ítem, no una ranura física: un accesorio puede ir en ACCESSORY_1 o ACCESSORY_2.
const SLOT_ACCESSORY: String = "ACCESSORY"

const VALID_SLOTS: Array[String] = [
	SLOT_HEAD, SLOT_CHEST, SLOT_GLOVES, SLOT_BOOTS, SLOT_BACK,
	SLOT_ACCESSORY_1, SLOT_ACCESSORY_2, SLOT_TACTICAL
]
const ACCESSORY_SLOTS: Array[String] = [SLOT_ACCESSORY_1, SLOT_ACCESSORY_2]

## Diccionario con los ítems actualmente equipados en cada ranura.
var equipped_items: Dictionary = {
	SLOT_HEAD: null,
	SLOT_CHEST: null,
	SLOT_GLOVES: null,
	SLOT_BOOTS: null,
	SLOT_BACK: null,
	SLOT_ACCESSORY_1: null,
	SLOT_ACCESSORY_2: null,
	SLOT_TACTICAL: null
}

var player: Player = null
@export var pickup_scene: PackedScene = preload("res://entities/items/pickup_item.tscn")


func _ready() -> void:
	player = owner as Player
	if player == null and get_parent() is Player:
		player = get_parent() as Player


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_U or event.keycode == KEY_U:
			drop_equipped_item(SLOT_ACCESSORY_1)
		elif event.physical_keycode == KEY_O or event.keycode == KEY_O:
			drop_equipped_item(SLOT_ACCESSORY_2)
		elif event.physical_keycode == KEY_J or event.keycode == KEY_J:
			drop_equipped_item(SLOT_BOOTS)
		elif event.physical_keycode == KEY_Y or event.keycode == KEY_Y:
			drop_equipped_item(SLOT_TACTICAL)


## Desequipa el ítem de la ranura especificada y lo deposita en el suelo junto al jugador como PickupItem.
func drop_equipped_item(slot: String) -> ItemData:
	var normalized_slot: String = slot.to_upper()
	if equipped_items.get(normalized_slot) == null:
		print("[EquipmentManager] La ranura [%s] ya está vacía." % normalized_slot)
		return null

	_ensure_player()
	var unequipped_item: ItemData = unequip_item(normalized_slot)
	if unequipped_item == null:
		return null

	if pickup_scene != null and player != null and player.is_inside_tree():
		var pickup_inst: Node = pickup_scene.instantiate()
		if pickup_inst is PickupItem:
			var pickup: PickupItem = pickup_inst as PickupItem
			pickup.item_data = unequipped_item
			pickup.pickup_cooldown = 0.5 # Evita recogerlo en el mismo frame de soltado

			# Posicionar ligeramente a un lado del jugador
			var drop_offset: Vector2 = Vector2(36.0, -10.0)
			if player.velocity.x < 0.0:
				drop_offset.x = -36.0

			pickup.global_position = player.global_position + drop_offset

			var container: Node = player.get_parent()
			if container == null:
				container = get_tree().current_scene
			if container == null:
				container = get_tree().root
			container.add_child(pickup)
			print("[EquipmentManager] Ítem '%s' soltado junto al jugador para poder recogerlo." % unequipped_item.item_name)

	return unequipped_item



## Equipa un ítem en la ranura indicada. Si ya existía un ítem, lo desequipa primero.
## La categoría "ACCESSORY" se resuelve a la primera ranura de accesorio libre.
func equip_item(slot: String, item: ItemData) -> bool:
	var normalized_slot: String = slot.to_upper()
	if normalized_slot == SLOT_ACCESSORY:
		normalized_slot = get_free_accessory_slot()
	if not VALID_SLOTS.has(normalized_slot):
		push_warning("[EquipmentManager] Ranura de equipamiento no válida: '%s'" % slot)
		return false

	if item == null:
		unequip_item(normalized_slot)
		return true

	# Desequipar el ítem previo de esta ranura si existía
	if equipped_items[normalized_slot] != null:
		unequip_item(normalized_slot)

	equipped_items[normalized_slot] = item

	# Aplicar modificadores sobre el StatsManager del jugador
	_ensure_player()
	if player != null:
		if player.stats_manager != null:
			item.apply_to_stats(player.stats_manager)
		_apply_item_abilities(item, true)

	item_equipped.emit(normalized_slot, item)
	print("[EquipmentManager] Equipado: '%s' en [%s]." % [item.item_name, normalized_slot])
	return true


## Desequipa el ítem de la ranura indicada y retira sus modificadores de estadísticas.
func unequip_item(slot: String) -> ItemData:
	var normalized_slot: String = slot.to_upper()
	if not VALID_SLOTS.has(normalized_slot):
		return null

	var current: ItemData = equipped_items.get(normalized_slot)
	if current == null:
		return null

	equipped_items[normalized_slot] = null

	# Remover modificadores del StatsManager del jugador y desactivar habilidades
	_ensure_player()
	if player != null:
		if player.stats_manager != null:
			current.remove_from_stats(player.stats_manager)
		_apply_item_abilities(current, false)

	item_unequipped.emit(normalized_slot, current)
	print("[EquipmentManager] Desequipado: '%s' de [%s]." % [current.item_name, normalized_slot])
	return current


func _apply_item_abilities(item: ItemData, is_equipping: bool) -> void:
	if player == null or item == null:
		return

	match item.item_id:
		"wall_jump_boots":
			player.can_wall_jump = is_equipping
		"jetpack":
			player.has_jetpack = is_equipping
			if is_equipping:
				player.jetpack_fuel = player.max_jetpack_fuel
		"feather_wings":
			player.has_wings = is_equipping
			if is_equipping:
				player.current_flaps = player.max_flaps
		"flight_ring":
			player.has_magic_flight = is_equipping


## Retorna el ítem equipado en una ranura específica.
func get_equipped_item(slot: String) -> ItemData:
	return equipped_items.get(slot.to_upper())


## Primera ranura de accesorio libre. Si ambas están ocupadas devuelve ACCESSORY_1 (la reemplaza).
func get_free_accessory_slot() -> String:
	for acc_slot in ACCESSORY_SLOTS:
		if equipped_items[acc_slot] == null:
			return acc_slot
	return SLOT_ACCESSORY_1


## Ranura física donde se equiparía el ítem, o "" si no tiene ranura de equipo (NONE).
func get_target_slot_for_item(item: ItemData) -> String:
	if item == null:
		return ""
	var category: String = item.equip_slot.to_upper()
	if category == SLOT_ACCESSORY:
		return get_free_accessory_slot()
	if VALID_SLOTS.has(category):
		return category
	return ""


## Indica si el ítem puede ocupar la ranura dada. Los accesorios entran en cualquiera de las dos.
func slot_accepts_item(slot: String, item: ItemData) -> bool:
	if item == null:
		return false
	var category: String = item.equip_slot.to_upper()
	var normalized_slot: String = slot.to_upper()
	if ACCESSORY_SLOTS.has(normalized_slot):
		return category == SLOT_ACCESSORY
	return category == normalized_slot


## Consulta la lista de estados alterados a inyectar en proyectiles disparados por el arma activa.
func get_attack_status_effects() -> Array[String]:
	var effects: Array[String] = []

	# 1. Comprobar ranuras de ACCESORIO (Infusión Ígnea / Infusión Criogénica)
	for acc_slot in ACCESSORY_SLOTS:
		var accessory: ItemData = equipped_items.get(acc_slot)
		if accessory != null:
			if accessory.tags.has("FIRE_INFUSION") or accessory.elemental_infusion.to_upper() == "FIRE" or accessory.item_id == "fire_ring":
				if not effects.has("FIRE"):
					effects.append("FIRE")
			if accessory.tags.has("ICE_INFUSION") or accessory.elemental_infusion.to_upper() == "ICE":
				if not effects.has("ICE"):
					effects.append("ICE")

	# 2. Comprobar el resto de ranuras por compatibilidad extensible
	for slot_key in equipped_items:
		if ACCESSORY_SLOTS.has(slot_key):
			continue
		var it: ItemData = equipped_items[slot_key]
		if it != null:
			if it.tags.has("FIRE_INFUSION") or it.elemental_infusion.to_upper() == "FIRE":
				if not effects.has("FIRE"):
					effects.append("FIRE")
			elif it.tags.has("ICE_INFUSION") or it.elemental_infusion.to_upper() == "ICE":
				if not effects.has("ICE"):
					effects.append("ICE")

	return effects


func _ensure_player() -> void:
	if player == null:
		player = owner as Player
	if player == null and get_parent() is Player:
		player = get_parent() as Player
