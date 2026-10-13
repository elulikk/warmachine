class_name InventoryWindow
extends DraggableWindow
## Interfaz de Inventario y Mochila del Jugador.
## Hereda de DraggableWindow para permitir arrastre y posicionamiento libre.
## Panel izquierdo: Ranuras de equipo activo (Armas 1/2/3, 3 Sockets del arma seleccionada, y HEAD, CHEST, GLOVES, BOOTS, BACK, ACCESSORY_1/2, TACTICAL).
## Panel derecho: Grilla de 5x4 con los 20 casilleros de la mochila, y debajo las monedas y cristales de tiempo.
## Arrastrar o clic derecho transfiere recursos limpiamente entre la mochila y las ranuras equipadas.


@onready var weapon_1_slot: ItemSlot = %Weapon1Slot
@onready var weapon_2_slot: ItemSlot = %Weapon2Slot
@onready var weapon_3_slot: ItemSlot = %Weapon3Slot

@onready var socket_1_slot: ItemSlot = %Socket1Slot
@onready var socket_2_slot: ItemSlot = %Socket2Slot
@onready var socket_3_slot: ItemSlot = %Socket3Slot

@onready var equip_head_slot: ItemSlot = %EquipHeadSlot
@onready var equip_chest_slot: ItemSlot = %EquipChestSlot
@onready var equip_gloves_slot: ItemSlot = %EquipGlovesSlot
@onready var equip_boots_slot: ItemSlot = %EquipBootsSlot
@onready var equip_back_slot: ItemSlot = %EquipBackSlot
@onready var equip_accessory_1_slot: ItemSlot = %EquipAccessory1Slot
@onready var equip_accessory_2_slot: ItemSlot = %EquipAccessory2Slot
@onready var equip_tactical_slot: ItemSlot = %EquipTacticalSlot

@onready var backpack_grid: GridContainer = %BackpackGrid
@onready var currency_label: Label = %CurrencyLabel

## Segundos de espera tras el último cambio antes de guardar la partida en disco.
const AUTOSAVE_DELAY: float = 0.8

## Armas que caben en el arsenal: una por casillero de la barra de acceso rápido.
const ARSENAL_LIMIT: int = 9

var player: Player = null
var _backpack_slots: Array[ItemSlot] = []
var _autosave_pending: bool = false


func _ready() -> void:
	super._ready()
	window_title = "INVENTARIO Y ARSENAL"
	visible = false
	_init_backpack_grid()
	_connect_equipment_slots()
	
	# Centrar la ventana inicialmente
	call_deferred("_initial_position")


func _initial_position() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	global_position = Vector2(maxf(10.0, vp_size.x * 0.5 - size.x * 0.5), maxf(10.0, vp_size.y * 0.5 - size.y * 0.5))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		get_viewport().set_input_as_handled()
		toggle_window()


func open_window() -> void:
	_bind_player()
	refresh_all()
	super.open_window()


func _bind_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Player
	_connect_currency_signals()


## Monedas y cristales de tiempo: se actualizan aunque la ventana esté abierta mientras se juntan.
func _connect_currency_signals() -> void:
	if player == null or player.stats_manager == null:
		return
	var stats: StatsManager = player.stats_manager
	if not stats.coins_changed.is_connected(_on_currency_changed):
		stats.coins_changed.connect(_on_currency_changed)
	if not stats.crystals_changed.is_connected(_on_currency_changed):
		stats.crystals_changed.connect(_on_currency_changed)


func _on_currency_changed(_amount: int) -> void:
	_refresh_currency()


## Cartel de monedas; el cristal de tiempo aparece al juntar el primero.
func _refresh_currency() -> void:
	if currency_label == null or player == null or player.stats_manager == null:
		return
	var stats: StatsManager = player.stats_manager
	var text: String = "🪙 Monedas: %d" % stats.coins
	if stats.time_crystals > 0:
		text += "   ◆ Cristales: %d" % stats.time_crystals
	currency_label.text = text


func _init_backpack_grid() -> void:
	var item_slot_scene: PackedScene = preload("res://ui/components/item_slot.tscn")
	_backpack_slots.clear()
	
	# Limpiar hijos previos si los hubiere
	for c in backpack_grid.get_children():
		c.queue_free()
	
	for i in range(20):
		var slot_instance: ItemSlot = item_slot_scene.instantiate() as ItemSlot
		slot_instance.slot_type = "ANY"
		slot_instance.slot_index = i
		slot_instance.context_tag = "backpack"
		# Mochila más holgada que el equipo: casilleros de 50 px
		slot_instance.custom_minimum_size = Vector2(50, 50)
		slot_instance.accept_filter = _backpack_accepts
		slot_instance.slot_right_clicked.connect(_on_backpack_slot_right_clicked)
		slot_instance.item_dropped_on_slot.connect(_on_item_dropped_on_slot)
		backpack_grid.add_child(slot_instance)
		_backpack_slots.append(slot_instance)


## Reglas extra de la mochila como destino: qué orígenes pueden soltar sobre un casillero concreto.
## Un arma de la barra rápida puede salir aunque sea la última: el personaje puede quedarse sin armas.
func _backpack_accepts(res: Resource, payload: Dictionary, slot: ItemSlot) -> bool:
	# Ítem desplazado por un swap: el casillero de origen se libera, siempre entra
	if bool(payload.get("is_displaced", false)):
		return true
	var src_context: String = str(payload.get("context_tag", ""))
	match src_context:
		"stash":
			return slot.get_item() == null
		"hotbar":
			# De la barra rápida solo salen armas (consumibles no viven en la mochila) y a un casillero libre
			return res is WeaponData and slot.get_item() == null
		"weapon":
			# Sacar un arma del arsenal: debe quedar al menos una, o intercambiar con otra arma de la mochila
			return slot.get_item() == null or slot.get_item() is WeaponData
		"equipment", "anvil":
			var occupant: Resource = slot.get_item()
			return occupant == null or (src_context == "equipment" and occupant is ItemData)
	return true


## La barra rápida recibe armas de la mochila o del yunque; reordenar entre ranuras no está soportado.
func _weapon_slot_accepts(_res: Resource, payload: Dictionary, _slot: ItemSlot) -> bool:
	return not ["weapon", "hotbar"].has(str(payload.get("context_tag", "")))


func _connect_equipment_slots() -> void:
	# Los sockets de runas en la mochila son de solo lectura (restringidos a la forja)
	if socket_1_slot != null:
		socket_1_slot.is_read_only = true
	if socket_2_slot != null:
		socket_2_slot.is_read_only = true
	if socket_3_slot != null:
		socket_3_slot.is_read_only = true
	
	var equip_slots: Array[ItemSlot] = [
		weapon_1_slot, weapon_2_slot, weapon_3_slot,
		socket_1_slot, socket_2_slot, socket_3_slot,
		equip_head_slot, equip_chest_slot, equip_gloves_slot, equip_boots_slot,
		equip_back_slot, equip_accessory_1_slot, equip_accessory_2_slot, equip_tactical_slot
	]
	
	for slot in equip_slots:
		if slot != null:
			if not slot.slot_right_clicked.is_connected(_on_equipment_slot_right_clicked):
				slot.slot_right_clicked.connect(_on_equipment_slot_right_clicked)
			if not slot.item_dropped_on_slot.is_connected(_on_item_dropped_on_slot):
				slot.item_dropped_on_slot.connect(_on_item_dropped_on_slot)
	
	for w_slot in [weapon_1_slot, weapon_2_slot, weapon_3_slot]:
		if w_slot != null:
			w_slot.accept_filter = _weapon_slot_accepts
			if not w_slot.slot_clicked.is_connected(_on_weapon_slot_clicked):
				w_slot.slot_clicked.connect(_on_weapon_slot_clicked)


func _on_weapon_slot_clicked(slot: ItemSlot, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_LEFT and player != null and player.weapon_manager != null:
		var w_idx: int = slot.slot_index
		if w_idx >= 0 and w_idx < player.weapon_manager.weapons.size():
			player.weapon_manager.select_weapon(w_idx)
			refresh_all()


func refresh_all() -> void:
	_bind_player()
	if player == null:
		return

	_refresh_currency()

	# 1. Refrescar Mochila
	if player.inventory_manager != null:
		for i in range(_backpack_slots.size()):
			var item: Resource = player.inventory_manager.get_item_at(i)
			_backpack_slots[i].set_item(item)
	
	# 2. Refrescar Armas
	if player.weapon_manager != null:
		var wpns: Array[WeaponData] = player.weapon_manager.weapons
		var cur_idx: int = player.weapon_manager.current_weapon_index
		weapon_1_slot.set_item(wpns[0] if wpns.size() > 0 else null)
		weapon_2_slot.set_item(wpns[1] if wpns.size() > 1 else null)
		weapon_3_slot.set_item(wpns[2] if wpns.size() > 2 else null)
		
		# Marcar visualmente cuál arma está actualmente equipada
		weapon_1_slot.set_highlight(cur_idx == 0 and wpns.size() > 0)
		weapon_2_slot.set_highlight(cur_idx == 1 and wpns.size() > 1)
		weapon_3_slot.set_highlight(cur_idx == 2 and wpns.size() > 2)
		
		# Sockets del arma seleccionada
		var cur_weapon: WeaponData = player.weapon_manager.current_weapon
		if cur_weapon != null:
			var runes: Array[RuneData] = cur_weapon.socketed_runes
			socket_1_slot.set_item(runes[0] if runes.size() > 0 else null)
			socket_2_slot.set_item(runes[1] if runes.size() > 1 else null)
			socket_3_slot.set_item(runes[2] if runes.size() > 2 else null)
		else:
			socket_1_slot.clear_slot()
			socket_2_slot.clear_slot()
			socket_3_slot.clear_slot()
	
	# 3. Refrescar Equipamiento Fijo
	if player.equipment_manager != null:
		var em: EquipmentManager = player.equipment_manager
		equip_head_slot.set_item(em.get_equipped_item(EquipmentManager.SLOT_HEAD))
		equip_chest_slot.set_item(em.get_equipped_item(EquipmentManager.SLOT_CHEST))
		equip_gloves_slot.set_item(em.get_equipped_item(EquipmentManager.SLOT_GLOVES))
		equip_boots_slot.set_item(em.get_equipped_item(EquipmentManager.SLOT_BOOTS))
		equip_back_slot.set_item(em.get_equipped_item(EquipmentManager.SLOT_BACK))
		equip_accessory_1_slot.set_item(em.get_equipped_item(EquipmentManager.SLOT_ACCESSORY_1))
		equip_accessory_2_slot.set_item(em.get_equipped_item(EquipmentManager.SLOT_ACCESSORY_2))
		equip_tactical_slot.set_item(em.get_equipped_item(EquipmentManager.SLOT_TACTICAL))
	
	# Cada cambio hecho con la ventana abierta se guarda: lo equipado sobrevive a cerrar el juego
	if visible:
		_schedule_autosave()


## Guarda la partida poco después del último cambio (agrupa varios movimientos seguidos).
func _schedule_autosave() -> void:
	if _autosave_pending:
		return
	_autosave_pending = true
	get_tree().create_timer(AUTOSAVE_DELAY).timeout.connect(_flush_autosave)


func _flush_autosave() -> void:
	_autosave_pending = false
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method(&"is_sandbox") and bool(gm.call(&"is_sandbox")):
		return
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null and player != null and is_instance_valid(player):
		sm.save_to_disk()


# ==============================================================================
# Interacción por Clic Derecho (Transferencia Inmediata)
# ==============================================================================

## Con el baúl abierto, el clic derecho guarda el ítem del casillero en el baúl.
## Retorna false si el baúl está cerrado o el ítem no se puede guardar (cae al comportamiento normal).
func _try_store_in_stash(slot: ItemSlot) -> bool:
	var stash_win: StashWindow = get_tree().get_first_node_in_group(&"stash_window") as StashWindow
	if stash_win == null or not stash_win.visible:
		return false
	return stash_win.store_item(slot.context_tag, slot.slot_index, slot.slot_type, slot.get_item())


func _on_backpack_slot_right_clicked(slot: ItemSlot) -> void:
	var item: Resource = slot.get_item()
	if item == null or player == null:
		return

	if _try_store_in_stash(slot):
		return

	# Si es WeaponData -> intentar equipar en el arsenal de armas (máx 3)
	if item is WeaponData:
		var wpn: WeaponData = item as WeaponData
		if player.weapon_manager != null and player.weapon_manager.weapons.size() < ARSENAL_LIMIT:
			player.inventory_manager.remove_item_at(slot.slot_index)
			player.weapon_manager.add_weapon(wpn, true)
			refresh_all()
			return
		elif player.weapon_manager != null and player.weapon_manager.weapons.size() >= ARSENAL_LIMIT:
			# Reemplazar arma activa
			var active_idx: int = player.weapon_manager.current_weapon_index
			var old_wpn: WeaponData = player.weapon_manager.weapons[active_idx]
			player.weapon_manager.weapons[active_idx] = wpn
			player.inventory_manager.set_item_at(slot.slot_index, old_wpn)
			player.weapon_manager.select_weapon(active_idx)
			refresh_all()
			return
	
	# Si la ventana de forja está abierta y el yunque está libre, transferir arma al yunque
	if item is WeaponData:
		var bs_win: Control = get_tree().get_first_node_in_group(&"blacksmith_window") as Control
		if bs_win != null and bs_win.visible and bs_win.has_method("get_anvil_weapon") and bs_win.has_method("set_anvil_weapon"):
			if bs_win.call("get_anvil_weapon") == null:
				var wpn_to_anvil: WeaponData = item as WeaponData
				player.inventory_manager.remove_item_at(slot.slot_index)
				bs_win.call("set_anvil_weapon", wpn_to_anvil)
				refresh_all()
				return
	
	# Si es ItemData -> intentar equipar en su slot correspondiente
	if item is ItemData:
		var itm: ItemData = item as ItemData
		var target_slot: String = player.equipment_manager.get_target_slot_for_item(itm) if player.equipment_manager != null else ""
		if not target_slot.is_empty():
			var prev: ItemData = player.equipment_manager.get_equipped_item(target_slot)
			player.inventory_manager.remove_item_at(slot.slot_index)
			player.equipment_manager.equip_item(target_slot, itm)
			if prev != null:
				player.inventory_manager.set_item_at(slot.slot_index, prev)
			refresh_all()
			return


func _on_equipment_slot_right_clicked(slot: ItemSlot) -> void:
	var item: Resource = slot.get_item()
	if item == null or player == null or player.inventory_manager == null:
		return

	# Con el baúl abierto se guarda ahí (no requiere espacio en la mochila)
	if _try_store_in_stash(slot):
		return

	# Si no hay espacio en la mochila, no se puede desequipar
	if not player.inventory_manager.has_free_space():
		print("[InventoryWindow] Mochila llena. No se puede desequipar.")
		return
	
	# Ranuras de equipamiento fijo
	if slot.context_tag == "equipment":
		var slot_key: String = slot.slot_type
		var unequipped: ItemData = player.equipment_manager.unequip_item(slot_key)
		if unequipped != null:
			player.inventory_manager.add_item(unequipped)
			refresh_all()
		return
	
	# Ranuras de armas
	if slot.context_tag == "weapon":
		if player.weapon_manager != null:
			var w_idx: int = slot.slot_index
			if w_idx >= 0 and w_idx < player.weapon_manager.weapons.size():
				var removed_weapon: WeaponData = player.weapon_manager.weapons[w_idx]
				player.weapon_manager.weapons.remove_at(w_idx)
				player.inventory_manager.add_item(removed_weapon)
				player.weapon_manager.select_weapon(0)
				refresh_all()
		return


# ==============================================================================
# Interacción Drag and Drop
# ==============================================================================

func _on_item_dropped_on_slot(source_data: Dictionary, target_slot: ItemSlot) -> void:
	if player == null:
		return
	
	var src_slot: ItemSlot = source_data.get("source_slot") as ItemSlot
	var src_res: Resource = source_data.get("resource") as Resource
	var src_context: String = str(source_data.get("context_tag", ""))
	var src_index: int = int(source_data.get("slot_index", -1))
	
	if src_slot == target_slot or src_res == null:
		return
	
	# 0. Barra rápida / Mano 2 -> Mochila: el arma sale del arsenal y vuelve a la mochila
	if (src_context == "hotbar" or src_context == "offhand") and target_slot.context_tag == "backpack":
		var weapons_manager: WeaponManager = player.weapon_manager
		if src_res is WeaponData and target_slot.get_item() == null and weapons_manager != null:
			if weapons_manager.offhand_weapon == src_res:
				weapons_manager.set_offhand_weapon(null)
			var arsenal_index: int = weapons_manager.weapons.find(src_res as WeaponData)
			if arsenal_index >= 0:
				var holding: WeaponData = weapons_manager.current_weapon
				weapons_manager.weapons.remove_at(arsenal_index)
				weapons_manager.weapon_magazines.erase(src_res as WeaponData)
				if weapons_manager.weapons.is_empty():
					weapons_manager.select_weapon(0)
				elif holding != null and holding != src_res and weapons_manager.weapons.has(holding):
					weapons_manager.select_weapon(weapons_manager.weapons.find(holding))
				else:
					weapons_manager.select_weapon(0)
				player.inventory_manager.set_item_at(target_slot.slot_index, src_res)
				refresh_all()
		return

	# 1. Mochila -> Mochila (Reordenar)
	if src_context == "backpack" and target_slot.context_tag == "backpack":
		player.inventory_manager.swap_slots(src_index, target_slot.slot_index)
		refresh_all()
		return
	
	# 2. Mochila -> Equipamiento Fijo
	if src_context == "backpack" and target_slot.context_tag == "equipment":
		if src_res is ItemData:
			var itm: ItemData = src_res as ItemData
			if player.equipment_manager.slot_accepts_item(target_slot.slot_type, itm):
				var prev: ItemData = player.equipment_manager.get_equipped_item(target_slot.slot_type)
				player.inventory_manager.remove_item_at(src_index)
				player.equipment_manager.equip_item(target_slot.slot_type, itm)
				if prev != null:
					player.inventory_manager.set_item_at(src_index, prev)
				refresh_all()
		return
	
	# 3. Equipamiento Fijo -> Mochila
	if src_context == "equipment" and target_slot.context_tag == "backpack":
		var target_item: Resource = target_slot.get_item()
		if target_item == null:
			var unequipped: ItemData = player.equipment_manager.unequip_item(src_slot.slot_type)
			player.inventory_manager.set_item_at(target_slot.slot_index, unequipped)
			refresh_all()
		elif target_item is ItemData:
			var target_itm: ItemData = target_item as ItemData
			if player.equipment_manager.slot_accepts_item(src_slot.slot_type, target_itm):
				var unequipped: ItemData = player.equipment_manager.unequip_item(src_slot.slot_type)
				player.equipment_manager.equip_item(src_slot.slot_type, target_itm)
				player.inventory_manager.set_item_at(target_slot.slot_index, unequipped)
				refresh_all()
		return
	
	# 4. Mochila -> Ranura de Arma
	if src_context == "backpack" and target_slot.context_tag == "weapon":
		if src_res is WeaponData and player.weapon_manager != null:
			var new_wpn: WeaponData = src_res as WeaponData
			var w_idx: int = target_slot.slot_index
			if w_idx < player.weapon_manager.weapons.size():
				var old_wpn: WeaponData = player.weapon_manager.weapons[w_idx]
				player.weapon_manager.weapons[w_idx] = new_wpn
				player.inventory_manager.set_item_at(src_index, old_wpn)
				player.weapon_manager.select_weapon(w_idx)
			else:
				player.inventory_manager.remove_item_at(src_index)
				player.weapon_manager.add_weapon(new_wpn, true)
			refresh_all()
		return
	
	# 7. Baúl -> Mochila (casillero libre)
	if src_context == "stash" and target_slot.context_tag == "backpack":
		var sm: SaveManager = SaveManager.get_instance()
		if sm != null and target_slot.get_item() == null and src_index >= 0 and src_index < sm.stash_items.size():
			var carried: Resource = SaveManager.stash_entry_to_resource(sm.stash_items[src_index])
			if carried == null:
				return
			sm.stash_items.remove_at(src_index)
			player.inventory_manager.set_item_at(target_slot.slot_index, carried)
			var stash_win: StashWindow = get_tree().get_first_node_in_group(&"stash_window") as StashWindow
			if stash_win != null:
				stash_win.refresh_stash()
			refresh_all()
		return
	
	# 8. Ranura de arma -> Mochila (libre: desequipa; con arma: intercambia)
	if src_context == "weapon" and target_slot.context_tag == "backpack":
		if player.weapon_manager != null and src_index >= 0 and src_index < player.weapon_manager.weapons.size():
			var target_item: Resource = target_slot.get_item()
			if target_item == null:
				var removed_weapon: WeaponData = player.weapon_manager.weapons[src_index]
				player.weapon_manager.weapons.remove_at(src_index)
				player.inventory_manager.set_item_at(target_slot.slot_index, removed_weapon)
				player.weapon_manager.select_weapon(0)
				refresh_all()
			elif target_item is WeaponData:
				var old_weapon: WeaponData = player.weapon_manager.weapons[src_index]
				player.weapon_manager.weapons[src_index] = target_item as WeaponData
				player.inventory_manager.set_item_at(target_slot.slot_index, old_weapon)
				player.weapon_manager.select_weapon(src_index)
				refresh_all()
		return
	
	# 5. Yunque de Herrero -> Mochila
	if src_context == "anvil" and target_slot.context_tag == "backpack":
		var target_item: Resource = target_slot.get_item()
		if target_item == null and src_res is WeaponData:
			var wpn: WeaponData = src_res as WeaponData
			player.inventory_manager.set_item_at(target_slot.slot_index, wpn)
			var bs_win: Control = get_tree().get_first_node_in_group(&"blacksmith_window") as Control
			if bs_win != null and bs_win.has_method("on_weapon_retrieved"):
				bs_win.call("on_weapon_retrieved")
			refresh_all()
		return
	
	# 6. Yunque de Herrero -> Ranura de Arma
	if src_context == "anvil" and target_slot.context_tag == "weapon":
		if src_res is WeaponData and player.weapon_manager != null:
			var wpn: WeaponData = src_res as WeaponData
			var w_idx: int = target_slot.slot_index
			var bs_win: Control = get_tree().get_first_node_in_group(&"blacksmith_window") as Control
			if w_idx < player.weapon_manager.weapons.size():
				var old_wpn: WeaponData = player.weapon_manager.weapons[w_idx]
				player.weapon_manager.weapons[w_idx] = wpn
				player.weapon_manager.select_weapon(w_idx)
				if bs_win != null and bs_win.has_method("set_anvil_weapon"):
					bs_win.call("set_anvil_weapon", old_wpn)
			else:
				player.weapon_manager.add_weapon(wpn, true)
				if bs_win != null and bs_win.has_method("on_weapon_retrieved"):
					bs_win.call("on_weapon_retrieved")
			refresh_all()
		return
