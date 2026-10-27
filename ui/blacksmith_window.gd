class_name BlacksmithWindow
extends DraggableWindow
## Ventana Modular de Forja y Modificación de Armamento (Herrero).
## Hereda de DraggableWindow para permitir posicionamiento libre en pantalla.
## Permite engarzar y desengarzar Runas en armas colocadas sobre el yunque.
## Al retirar el arma del yunque o cerrar la ventana, persiste el estado a disco vía SaveManager.

@onready var anvil_slot: ItemSlot = %AnvilSlot
@onready var weapon_name_label: Label = %WeaponNameLabel
@onready var weapon_stats_label: Label = %WeaponStatsLabel
@onready var sockets_panel: PanelContainer = %SocketsPanel
@onready var sockets_hbox: HBoxContainer = %SocketsHBox
@onready var socket_1_slot: ItemSlot = %Socket1Slot
@onready var socket_2_slot: ItemSlot = %Socket2Slot
@onready var socket_3_slot: ItemSlot = %Socket3Slot
@onready var sockets_hint_label: Label = %SocketsHintLabel

var player: Player = null
var current_weapon: WeaponData = null
var _socket_slots: Array[ItemSlot] = []


func _ready() -> void:
	super._ready()
	window_title = "Forja y Modificación de Armamento"
	visible = false
	
	_socket_slots = [socket_1_slot, socket_2_slot, socket_3_slot]
	
	# Configuración de slots
	if anvil_slot != null:
		anvil_slot.slot_type = "WEAPON"
		anvil_slot.context_tag = "anvil"
		anvil_slot.accept_filter = _anvil_accepts
		anvil_slot.slot_index = 0
		anvil_slot.slot_right_clicked.connect(_on_anvil_slot_right_clicked)
		anvil_slot.item_dropped_on_slot.connect(_on_anvil_item_dropped)
	
	for i in range(_socket_slots.size()):
		var slot: ItemSlot = _socket_slots[i]
		if slot != null:
			slot.slot_type = "RUNE"
			slot.context_tag = "anvil_socket"
			slot.accept_filter = _socket_accepts
			slot.slot_index = i
			slot.slot_right_clicked.connect(_on_socket_slot_right_clicked)
			slot.item_dropped_on_slot.connect(_on_socket_item_dropped)
	
	call_deferred("_initial_position")
	_update_display()


func _initial_position() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	# Ubicar hacia la izquierda para dejar espacio al inventario a la derecha
	global_position = Vector2(maxf(20.0, vp_size.x * 0.1), maxf(20.0, vp_size.y * 0.5 - size.y * 0.5))


func _bind_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Player


func open_window() -> void:
	_bind_player()
	_update_display()
	super.open_window()


func close_window() -> void:
	if current_weapon != null:
		_return_weapon_to_player(current_weapon)
		current_weapon = null
		if anvil_slot != null:
			anvil_slot.clear_slot()
		_update_display()
	
	# Persistir cambios al cerrar la ventana
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()
	
	var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
	if inv_win != null and inv_win.visible:
		inv_win.refresh_all()
	
	super.close_window()


func set_anvil_weapon(weapon: WeaponData) -> void:
	if current_weapon != null and current_weapon != weapon:
		_return_weapon_to_player(current_weapon)
	
	if current_weapon != null and current_weapon.runes_changed.is_connected(_on_weapon_runes_changed):
		current_weapon.runes_changed.disconnect(_on_weapon_runes_changed)
	
	current_weapon = weapon
	
	if current_weapon != null:
		if not current_weapon.runes_changed.is_connected(_on_weapon_runes_changed):
			current_weapon.runes_changed.connect(_on_weapon_runes_changed)
		if anvil_slot != null:
			anvil_slot.set_item(current_weapon)
	else:
		if anvil_slot != null:
			anvil_slot.clear_slot()
	
	_update_display()


func get_anvil_weapon() -> WeaponData:
	return current_weapon


func on_weapon_retrieved() -> void:
	if current_weapon != null and current_weapon.runes_changed.is_connected(_on_weapon_runes_changed):
		current_weapon.runes_changed.disconnect(_on_weapon_runes_changed)
	current_weapon = null
	if anvil_slot != null:
		anvil_slot.clear_slot()
	_update_display()
	
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()


func _return_weapon_to_player(weapon: WeaponData) -> void:
	_bind_player()
	if player == null or weapon == null:
		return
	
	if player.inventory_manager != null and player.inventory_manager.has_free_space():
		player.inventory_manager.add_item(weapon)
	elif player.weapon_manager != null and player.weapon_manager.weapons.size() < InventoryWindow.ARSENAL_LIMIT:
		player.weapon_manager.add_weapon(weapon, false)
	elif player.inventory_manager != null:
		player.inventory_manager.add_item(weapon)


func _on_weapon_runes_changed() -> void:
	_update_display()


## El yunque recibe armas desde la mochila, el arsenal, la barra rápida o la mano 2.
func _anvil_accepts(res: Resource, payload: Dictionary, _slot: ItemSlot) -> bool:
	var src_context: String = str(payload.get("context_tag", ""))
	if src_context == "hotbar" or src_context == "offhand":
		return res is WeaponData
	return src_context == "backpack" or src_context == "weapon"


## Un socket recibe una runa de la mochila si el arma del yunque la admite y el socket está libre.
func _socket_accepts(res: Resource, payload: Dictionary, slot: ItemSlot) -> bool:
	if current_weapon == null or str(payload.get("context_tag", "")) != "backpack":
		return false
	var rune: RuneData = res as RuneData
	if rune == null:
		return false
	return slot.slot_index < current_weapon.max_sockets and slot.get_item() == null and current_weapon.can_socket_rune(rune)


func _on_anvil_slot_right_clicked(_slot: ItemSlot) -> void:
	if current_weapon == null:
		return
	
	_bind_player()
	if player == null or player.inventory_manager == null:
		return
	
	if not player.inventory_manager.has_free_space():
		print("[BlacksmithWindow] Mochila llena. No se puede retirar el arma del yunque.")
		return
	
	var wpn: WeaponData = current_weapon
	if current_weapon.runes_changed.is_connected(_on_weapon_runes_changed):
		current_weapon.runes_changed.disconnect(_on_weapon_runes_changed)
	current_weapon = null
	if anvil_slot != null:
		anvil_slot.clear_slot()
	
	player.inventory_manager.add_item(wpn)
	_update_display()
	
	var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
	if inv_win != null and inv_win.visible:
		inv_win.refresh_all()
	
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()


func _on_anvil_item_dropped(source_data: Dictionary, _target_slot: ItemSlot) -> void:
	_bind_player()
	if player == null:
		return
	
	var src_res: Resource = source_data.get("resource") as Resource
	var src_context: String = str(source_data.get("context_tag", ""))
	var src_index: int = int(source_data.get("slot_index", -1))
	
	if src_res == null:
		return
	
	# Si soltamos un arma en el yunque
	if src_res is WeaponData:
		var wpn: WeaponData = src_res as WeaponData
		if src_context == "backpack" and player.inventory_manager != null:
			player.inventory_manager.remove_item_at(src_index)
			set_anvil_weapon(wpn)
		elif src_context == "weapon" and player.weapon_manager != null:
			if src_index >= 0 and src_index < player.weapon_manager.weapons.size():
				player.weapon_manager.weapons.remove_at(src_index)
				player.weapon_manager.select_weapon(0)
				set_anvil_weapon(wpn)
		elif (src_context == "hotbar" or src_context == "offhand") and player.weapon_manager != null:
			# Desde la barra rápida o la mano 2: el arma sale del arsenal (y de la mano 2) hacia el yunque
			var wm: WeaponManager = player.weapon_manager
			var arsenal_index: int = wm.weapons.find(wpn)
			if arsenal_index >= 0:
				var holding: WeaponData = wm.current_weapon
				if wm.offhand_weapon == wpn:
					wm.set_offhand_weapon(null)
				wm.weapons.remove_at(arsenal_index)
				wm.weapon_magazines.erase(wpn)
				if holding != null and holding != wpn and wm.weapons.has(holding):
					wm.select_weapon(wm.weapons.find(holding))
				else:
					wm.select_weapon(0)
				set_anvil_weapon(wpn)
		
		var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
		if inv_win != null and inv_win.visible:
			inv_win.refresh_all()
		return
	
	# Si soltamos una runa sobre el yunque mientras hay un arma puesta
	if src_res is RuneData and current_weapon != null:
		var rune: RuneData = src_res as RuneData
		if current_weapon.can_socket_rune(rune):
			if src_context == "backpack" and player.inventory_manager != null:
				player.inventory_manager.remove_item_at(src_index)
				current_weapon.socket_rune(rune)
				_update_display()
				
				var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
				if inv_win != null and inv_win.visible:
					inv_win.refresh_all()
				
				var sm: SaveManager = SaveManager.get_instance()
				if sm != null:
					sm.save_to_disk()


func _on_socket_item_dropped(source_data: Dictionary, target_slot: ItemSlot) -> void:
	if current_weapon == null:
		return
	
	var src_res: Resource = source_data.get("resource") as Resource
	var src_context: String = str(source_data.get("context_tag", ""))
	var src_index: int = int(source_data.get("slot_index", -1))
	
	if not (src_res is RuneData):
		return
	
	var rune: RuneData = src_res as RuneData
	if not current_weapon.can_socket_rune(rune):
		print("[BlacksmithWindow] El arma no puede engarzar esta runa (cupo lleno o tipo incompatible).")
		return
	
	# Validar que el socket objetivo esté libre
	if target_slot.slot_index >= current_weapon.max_sockets:
		return
	if target_slot.get_item() != null:
		return
	
	_bind_player()
	if src_context == "backpack" and player != null and player.inventory_manager != null:
		player.inventory_manager.remove_item_at(src_index)
		current_weapon.socket_rune(rune)
		_update_display()
		
		var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
		if inv_win != null and inv_win.visible:
			inv_win.refresh_all()
		
		var sm: SaveManager = SaveManager.get_instance()
		if sm != null:
			sm.save_to_disk()


func _on_socket_slot_right_clicked(slot: ItemSlot) -> void:
	if current_weapon == null:
		return
	
	var s_idx: int = slot.slot_index
	if s_idx < 0 or s_idx >= current_weapon.socketed_runes.size():
		return
	
	_bind_player()
	if player == null or player.inventory_manager == null:
		return
	
	if not player.inventory_manager.has_free_space():
		print("[BlacksmithWindow] Mochila llena. No se puede desengarzadar la runa.")
		return
	
	var rune: RuneData = current_weapon.socketed_runes[s_idx]
	current_weapon.socketed_runes.remove_at(s_idx)
	current_weapon.runes_changed.emit()
	
	player.inventory_manager.add_item(rune)
	_update_display()
	
	var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
	if inv_win != null and inv_win.visible:
		inv_win.refresh_all()
	
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()


func _update_display() -> void:
	if not is_inside_tree():
		return
	
	if current_weapon == null:
		if anvil_slot != null:
			anvil_slot.clear_slot()
		if weapon_name_label != null:
			weapon_name_label.text = "YUNQUE VACÍO"
			weapon_name_label.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if weapon_stats_label != null:
			weapon_stats_label.text = "Arrastra un arma desde la mochila para comenzar."
		if sockets_panel != null:
			sockets_panel.modulate.a = 0.4
		if sockets_hint_label != null:
			sockets_hint_label.text = "Ranuras inactivas (Coloca un arma en el yunque)"
		
		for slot in _socket_slots:
			if slot != null:
				slot.clear_slot()
				slot.is_read_only = true
				slot.modulate.a = 0.4
	else:
		if anvil_slot != null:
			anvil_slot.set_item(current_weapon)
		if weapon_name_label != null:
			var icon_str: String = "⚔️ " if current_weapon.weapon_type == WeaponData.WeaponType.MELEE else "🔫 "
			weapon_name_label.text = icon_str + current_weapon.weapon_name
			weapon_name_label.modulate = Color(1.0, 0.85, 0.3, 1.0) if current_weapon.weapon_type == WeaponData.WeaponType.MELEE else Color(0.4, 0.85, 1.0, 1.0)
		if weapon_stats_label != null:
			weapon_stats_label.text = "Daño: %.1f (Efectivo: %.1f) • Cadencia: %.1f disp/s" % [
				current_weapon.damage,
				current_weapon.get_effective_damage(),
				current_weapon.fire_rate
			]
		if sockets_panel != null:
			sockets_panel.modulate.a = 1.0
		
		var runes: Array[RuneData] = current_weapon.socketed_runes
		var max_s: int = clampi(current_weapon.max_sockets, 0, 3)
		
		for i in range(_socket_slots.size()):
			var slot: ItemSlot = _socket_slots[i]
			if slot == null:
				continue
			if i >= max_s:
				slot.clear_slot()
				slot.modulate.a = 0.25
				slot.is_read_only = true
			elif i < runes.size() and runes[i] != null:
				slot.modulate.a = 1.0
				slot.set_item(runes[i])
				slot.is_read_only = false
			else:
				slot.modulate.a = 0.8
				slot.clear_slot()
				slot.is_read_only = false
		
		if sockets_hint_label != null:
			sockets_hint_label.text = "Engarzar: Arrastrar runa • Desengarzadar: Clic derecho (%d/%d)" % [runes.size(), max_s]
