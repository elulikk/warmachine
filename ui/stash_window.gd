class_name StashWindow
extends DraggableWindow
## Ventana de Baúl de Almacenamiento Ilimitado del Campamento Base.
## Hereda de DraggableWindow para permitir arrastre libre sobre la pantalla.
## Aloja casilleros ilimitados dentro de un ScrollContainer vertical con GridContainer.
## Soporta drag & drop y clic derecho para transferir ítems entre el baúl y la mochila.
## Al cerrarse, invoca automáticamente SaveManager.save_to_disk().

@onready var stash_grid: GridContainer = %StashGrid
@onready var stash_scroll: ScrollContainer = %StashScroll

var player: Player = null
var _slot_nodes: Array[ItemSlot] = []


func _ready() -> void:
	super._ready()
	window_title = "BAÚL DE SUMINISTROS (ILIMITADO)"
	visible = false
	window_closed.connect(_on_window_closed)
	call_deferred("_initial_position")


func _initial_position() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	# Posicionarlo en el tercio izquierdo para que la mochila quede a la derecha
	global_position = Vector2(maxf(20.0, vp_size.x * 0.1), maxf(20.0, vp_size.y * 0.5 - size.y * 0.5))


func open_window() -> void:
	_bind_player()
	refresh_stash()
	super.open_window()


func _on_window_closed() -> void:
	# Al cerrarse el baúl, persistir de inmediato los cambios en disco
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()
		print("[StashWindow] Baúl cerrado. Autoguardado a disco completado.")


func _bind_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Player


func refresh_stash() -> void:
	_bind_player()
	var sm: SaveManager = SaveManager.get_instance()
	if sm == null:
		return
	
	var item_slot_scene: PackedScene = preload("res://ui/components/item_slot.tscn")
	_slot_nodes.clear()
	
	for child in stash_grid.get_children():
		child.queue_free()
	
	# Instanciar casilleros para cada ítem almacenado
	for i in range(sm.stash_items.size()):
		var res: Resource = SaveManager.stash_entry_to_resource(sm.stash_items[i])
		
		var slot_inst: ItemSlot = item_slot_scene.instantiate() as ItemSlot
		slot_inst.slot_type = "ANY"
		slot_inst.slot_index = i
		slot_inst.context_tag = "stash"
		slot_inst.accept_filter = _stash_accepts
		slot_inst.set_item(res)
		slot_inst.slot_right_clicked.connect(_on_stash_slot_right_clicked)
		slot_inst.item_dropped_on_slot.connect(_on_stash_item_dropped)
		stash_grid.add_child(slot_inst)
		_slot_nodes.append(slot_inst)
	
	# Agregar al menos 6 casilleros vacíos de destino al final para recibir drops
	for j in range(6):
		var empty_slot: ItemSlot = item_slot_scene.instantiate() as ItemSlot
		empty_slot.slot_type = "ANY"
		empty_slot.slot_index = sm.stash_items.size() + j
		empty_slot.context_tag = "stash"
		empty_slot.accept_filter = _stash_accepts
		empty_slot.slot_right_clicked.connect(_on_stash_slot_right_clicked)
		empty_slot.item_dropped_on_slot.connect(_on_stash_item_dropped)
		stash_grid.add_child(empty_slot)
		_slot_nodes.append(empty_slot)


## El baúl recibe ítems de la mochila, armas del arsenal y equipo puesto, siempre que se puedan
## guardar por ruta de recurso.
func _stash_accepts(res: Resource, payload: Dictionary, _slot: ItemSlot) -> bool:
	var src_context: String = str(payload.get("context_tag", ""))
	if src_context != "backpack" and src_context != "weapon" and src_context != "equipment":
		return false
	return SaveManager.stash_resource_to_entry(res) != null


func _on_stash_slot_right_clicked(slot: ItemSlot) -> void:
	var item: Resource = slot.get_item()
	if item == null or player == null or player.inventory_manager == null:
		return
	
	if not player.inventory_manager.has_free_space():
		print("[StashWindow] Mochila llena. No se puede transferir ítem.")
		return
	
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null and slot.slot_index < sm.stash_items.size():
		sm.stash_items.remove_at(slot.slot_index)
		player.inventory_manager.add_item(item)
		refresh_stash()
		
		# Actualizar ventana de inventario si está abierta
		var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
		if inv_win != null and inv_win.visible:
			inv_win.refresh_all()


func _on_stash_item_dropped(source_data: Dictionary, _target_slot: ItemSlot) -> void:
	store_item(
		str(source_data.get("context_tag", "")),
		int(source_data.get("slot_index", -1)),
		str(source_data.get("slot_type", "")),
		source_data.get("resource") as Resource
	)


## Guarda en el baúl un ítem de la mochila ("backpack"), del arsenal ("weapon") o del equipo
## puesto ("equipment"). Lo retira del origen, refresca ambas ventanas y persiste a disco.
## Retorna false (sin tocar nada) si el recurso no se puede guardar o ya no está en el origen.
func store_item(src_context: String, src_index: int, src_slot_type: String, src_res: Resource) -> bool:
	var sm: SaveManager = SaveManager.get_instance()
	_bind_player()
	if sm == null or player == null or src_res == null:
		return false

	var entry: Variant = SaveManager.stash_resource_to_entry(src_res)
	if entry == null:
		return false

	# Retirar el ítem de su origen real; solo si se pudo retirar pasa al baúl
	var removed: bool = false
	if src_context == "backpack" and player.inventory_manager != null:
		removed = player.inventory_manager.get_item_at(src_index) == src_res
		if removed:
			player.inventory_manager.remove_item_at(src_index)
	elif src_context == "weapon" and player.weapon_manager != null:
		removed = src_index >= 0 and src_index < player.weapon_manager.weapons.size() and player.weapon_manager.weapons[src_index] == src_res
		if removed:
			player.weapon_manager.weapons.remove_at(src_index)
			# Con select_weapon(0) un arsenal vacío deja al personaje sin arma activa
			player.weapon_manager.select_weapon(0)
	elif src_context == "equipment" and player.equipment_manager != null:
		removed = player.equipment_manager.get_equipped_item(src_slot_type) == src_res
		if removed:
			player.equipment_manager.unequip_item(src_slot_type)
	
	if not removed:
		return false

	sm.stash_items.append(entry)
	refresh_stash()

	var inv_win: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
	if inv_win != null and inv_win.visible:
		inv_win.refresh_all()
	sm.save_to_disk()
	return true
