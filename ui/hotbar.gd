extends Control
## Barra de acceso rápido de 9 casilleros libres, centrada abajo (estilo Minecraft / Terraria).
## Cada casillero guarda una referencia: un arma del arsenal o un consumible del catálogo.
## - Se llena arrastrando desde el inventario (armas de la ranura rápida, consumibles de su paleta).
## - Arrastrar entre casilleros mueve o intercambia; clic derecho quita el ítem.
## - Teclas 1-9 eligen casillero; rueda y L1/R1 recorren los ocupados; Q vuelve al anterior.
## - El casillero en mano manda: un arma lo deja disparar; un consumible hace que el clic izquierdo lo use.
## - A la derecha hay un casillero extra, "Mano 2": el arma que va en la mano secundaria (clic derecho).
##   Acepta armas de una mano o escudos del arsenal; arrastrar mueve el arma (no queda también en la barra).
##   Con un arma a dos manos en la mano principal queda bloqueado y la elección se conserva.
## La disposición vive en Player.hotbar_layout y la guarda SaveManager.
## Sin class_name a propósito: lo instancia ui/hud.gd por preload.

const ConsumableManagerScript = preload("res://core/consumables/consumable_manager.gd")
const ConsumableDataScript = preload("res://core/consumables/consumable_data.gd")
const ItemIconsScript = preload("res://ui/components/item_icons.gd")
const HotbarSlotScript = preload("res://ui/hotbar_slot.gd")

const SLOT_COUNT: int = 9
const SLOT_SIZE: Vector2 = Vector2(56.0, 60.0)
const SEPARATION: int = 6
## Hueco entre los 9 casilleros y el de la mano secundaria.
const OFFHAND_GAP: float = 14.0
const MESSAGE_SECONDS: float = 1.6

const COLOR_BORDER: Color = Color(0.3, 0.4, 0.55, 0.8)
const COLOR_BORDER_EMPTY: Color = Color(0.2, 0.24, 0.3, 0.6)
const COLOR_SELECTED: Color = Color(1.0, 0.82, 0.3, 1.0)

var _player: Player = null
var _bound: bool = false
var _slots: Array = []
## Casillero de la mano secundaria (no forma parte de `_slots`: no se elige con 1-9 ni con la rueda).
var _offhand_slot: PanelContainer = null
var _selected: int = 0
var _previous: int = 0
## Último arma que emitió WeaponManager: distingue un cambio real de un refresco (recarga, poción sin recarga)
var _last_weapon: WeaponData = null
## Layout guardado que todavía no se pudo resolver (el arsenal aún no cargó)
var _layout_pending: bool = false
## Armas en el arsenal la última vez que se miró: si crece, las nuevas entran a la barra (ver `_place_loose_weapons`).
var _known_weapon_count: int = -1
var _message_left: float = 0.0
var _message_label: Label = null
var _name_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	var total_width: float = (SLOT_COUNT + 1) * SLOT_SIZE.x + (SLOT_COUNT - 1) * SEPARATION + OFFHAND_GAP + SEPARATION
	offset_left = -total_width * 0.5
	offset_right = total_width * 0.5
	offset_top = -(SLOT_SIZE.y + 64.0)
	offset_bottom = -16.0

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 2)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	_message_label = _make_text_label(12, Color(1.0, 0.9, 0.5, 1.0), true)
	column.add_child(_message_label)
	_name_label = _make_text_label(12, Color.WHITE, true)
	column.add_child(_name_label)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", SEPARATION)
	column.add_child(row)
	for i in range(SLOT_COUNT):
		var slot = HotbarSlotScript.new()
		slot.index = i
		slot.custom_minimum_size = SLOT_SIZE
		slot.accept_filter = _accepts
		slot.dropped.connect(_on_slot_dropped)
		slot.right_clicked.connect(_on_slot_right_clicked)
		row.add_child(slot)
		_slots.append(slot)

	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(OFFHAND_GAP - SEPARATION, 0.0)
	row.add_child(gap)
	var off_slot: PanelContainer = HotbarSlotScript.new() as PanelContainer
	off_slot.set("index", SLOT_COUNT)
	off_slot.set("key_text", "M2")
	off_slot.set("context_tag", "offhand")
	off_slot.custom_minimum_size = SLOT_SIZE
	off_slot.set("accept_filter", _accepts_offhand)
	off_slot.connect("dropped", _on_offhand_dropped)
	off_slot.connect("right_clicked", _on_offhand_right_clicked)
	row.add_child(off_slot)
	_offhand_slot = off_slot

	_refresh()


func _process(delta: float) -> void:
	if not _bound:
		_try_bind()
	elif not is_instance_valid(_player):
		_bound = false
		_player = null
		_layout_pending = false
	elif _layout_pending and _player.weapon_manager.weapons.size() > 0:
		_apply_layout(_player.hotbar_layout)
		_layout_pending = false
		_place_loose_weapons()
	elif _player.weapon_manager.weapons.size() != _known_weapon_count:
		_place_loose_weapons()

	if _message_left > 0.0:
		_message_left = maxf(0.0, _message_left - delta)
		if _message_left <= 0.0:
			_message_label.text = ""

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not _bound:
		return

	for i in range(SLOT_COUNT):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			get_viewport().set_input_as_handled()
			_select(i)
			return

	if event.is_action_pressed("weapon_next"):
		get_viewport().set_input_as_handled()
		_step(1)
	elif event.is_action_pressed("weapon_prev"):
		get_viewport().set_input_as_handled()
		_step(-1)
	elif event.is_action_pressed("weapon_toggle"):
		get_viewport().set_input_as_handled()
		if _entry(_previous) != null:
			_select(_previous)
	elif event.is_action_pressed("attack") and _holding_consumable():
		get_viewport().set_input_as_handled()
		var data: ConsumableDataScript = _entry(_selected) as ConsumableDataScript
		_player.consumable_manager.use_consumable(data.consumable_id)


# ==============================================================================
# Enlace con el jugador y persistencia
# ==============================================================================

func _try_bind() -> void:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.weapon_manager == null or player.consumable_manager == null:
		return
	_player = player
	_bound = true
	player.weapon_manager.weapon_changed.connect(_on_weapon_changed)
	player.weapon_manager.offhand_changed.connect(func(_w: WeaponData) -> void: _refresh())
	player.consumable_manager.message_posted.connect(_show_message)
	player.consumable_manager.counts_changed.connect(_place_loose_consumables)
	_last_weapon = player.weapon_manager.current_weapon

	if player.hotbar_layout.is_empty():
		_fill_default()
	else:
		_apply_layout(player.hotbar_layout)
		_layout_pending = _needs_weapons(player.hotbar_layout) and player.weapon_manager.weapons.is_empty()

	if not _layout_pending:
		_place_loose_weapons()
		_place_loose_consumables()
	_selected = _initial_selection()
	_previous = _selected


## Disposición de inicio para partidas sin barra guardada: solo las armas 1-3. Lo demás lo arma el jugador.
func _fill_default() -> void:
	var wm: WeaponManager = _player.weapon_manager
	for i in range(mini(3, wm.weapons.size())):
		_slots[i].set_item(wm.weapons[i])


func _apply_layout(raw: Array) -> void:
	var wm: WeaponManager = _player.weapon_manager
	for i in range(SLOT_COUNT):
		var res: Resource = null
		var entry: Variant = raw[i] if i < raw.size() else null
		if typeof(entry) == TYPE_DICTIONARY:
			var d: Dictionary = entry as Dictionary
			if d.has("w"):
				var weapon_index: int = int(d["w"])
				if weapon_index >= 0 and weapon_index < wm.weapons.size():
					res = wm.weapons[weapon_index]
			elif d.has("c"):
				res = _catalog_item(str(d["c"]))
		_slots[i].set_item(res)

	# Entrada SLOT_COUNT: arma de la mano secundaria (los guardados anteriores no la traen: queda libre)
	var off_weapon: WeaponData = null
	var off_entry: Variant = raw[SLOT_COUNT] if raw.size() > SLOT_COUNT else null
	if typeof(off_entry) == TYPE_DICTIONARY and (off_entry as Dictionary).has("w"):
		var off_index: int = int((off_entry as Dictionary)["w"])
		if off_index >= 0 and off_index < wm.weapons.size():
			off_weapon = wm.weapons[off_index]
	wm.set_offhand_weapon(off_weapon)


func _serialize_layout() -> Array:
	var wm: WeaponManager = _player.weapon_manager
	var out: Array = []
	for slot in _slots:
		var res: Resource = slot.get_item()
		if res is WeaponData:
			var weapon_index: int = wm.weapons.find(res)
			out.append({"w": weapon_index} if weapon_index >= 0 else null)
		elif res is ConsumableDataScript:
			out.append({"c": (res as ConsumableDataScript).consumable_id})
		else:
			out.append(null)
	# Última entrada: arma de la mano secundaria
	var off_index: int = wm.weapons.find(wm.offhand_weapon) if wm.offhand_weapon != null else -1
	out.append({"w": off_index} if off_index >= 0 else null)
	return out


func _needs_weapons(raw: Array) -> bool:
	for entry in raw:
		if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).has("w"):
			return true
	return false


func _initial_selection() -> int:
	var current: WeaponData = _player.weapon_manager.current_weapon
	for i in range(SLOT_COUNT):
		if current != null and _entry(i) == current:
			return i
	for i in range(SLOT_COUNT):
		if _entry(i) != null:
			return i
	return 0


# ==============================================================================
# Cambios de arma hechos desde fuera de la barra
# ==============================================================================

## Arma equipada desde otro lado (recogida, tienda, herrero, ranura rápida del inventario):
## si no estaba en la barra entra en el primer casillero libre, y queda en mano.
## Las recargas y pociones emiten la misma señal con el mismo arma: se ignoran.
func _on_weapon_changed(weapon: WeaponData, _index: int) -> void:
	if not _bound:
		return
	var changed: bool = weapon != _last_weapon
	_last_weapon = weapon
	if weapon == null or not changed:
		return

	var target: int = -1
	if _entry(_selected) == weapon:
		target = _selected
	else:
		target = _slot_holding(weapon)
	if target < 0:
		target = _first_empty()
	if target < 0:
		target = _selected
		_slots[target].set_item(weapon)
	elif _entry(target) != weapon:
		_slots[target].set_item(weapon)
	_selected = target


## Armas del arsenal que no están en ningún casillero (garantizadas por el nivel, compradas o recogidas sin
## equipar): entran en los casilleros de armas libres (1-3) y, si no hay, en el primero libre de la barra.
func _place_loose_weapons() -> void:
	var wm: WeaponManager = _player.weapon_manager
	_known_weapon_count = wm.weapons.size()
	for weapon: WeaponData in wm.weapons:
		# El arma de la mano secundaria ya tiene su casillero
		if _slot_holding(weapon) >= 0 or weapon == wm.offhand_weapon:
			continue
		var target: int = -1
		for i in range(mini(3, SLOT_COUNT)):
			if _entry(i) == null:
				target = i
				break
		if target < 0:
			target = _first_empty()
		if target < 0:
			return
		_slots[target].set_item(weapon)


## Consumibles que se tienen pero no están en ningún casillero (comprados, recogidos): entran en el primer
## casillero libre a partir del 4. Ya no hay paleta en el inventario desde la que asignarlos a mano.
func _place_loose_consumables() -> void:
	if not _bound or _layout_pending:
		return
	var manager: ConsumableManagerScript = _player.consumable_manager
	for data: ConsumableDataScript in ConsumableManagerScript.get_catalog():
		if manager.get_count(data.consumable_id) <= 0 or _slot_holding(data) >= 0:
			continue
		var target: int = -1
		for i in range(3, SLOT_COUNT):
			if _entry(i) == null:
				target = i
				break
		if target < 0:
			target = _first_empty()
		if target < 0:
			return
		_slots[target].set_item(data)


## Quita del casillero (y de la mano) lo que ya no está en el arsenal.
func _clean_stale() -> void:
	var wm: WeaponManager = _player.weapon_manager
	for slot in _slots:
		var res: Resource = slot.get_item()
		if res is WeaponData and not wm.weapons.has(res):
			slot.set_item(null)


# ==============================================================================
# Selección
# ==============================================================================

func _select(index: int) -> void:
	if not _bound or index == _selected:
		return
	_previous = _selected
	_selected = index
	_refresh()


## Pasa al siguiente casillero ocupado (direction 1) o al anterior (-1).
func _step(direction: int) -> void:
	for step in range(1, SLOT_COUNT + 1):
		var candidate: int = posmod(_selected + direction * step, SLOT_COUNT)
		if _entry(candidate) != null:
			_select(candidate)
			return


func _holding_consumable() -> bool:
	return _entry(_selected) is ConsumableDataScript


# ==============================================================================
# Arrastre hacia la barra
# ==============================================================================

## Armas: las del arsenal, o una de la mochila si el arsenal tiene lugar (al soltarla pasa al arsenal).
## Consumibles: cualquiera del catálogo.
func _accepts(res: Resource, payload: Dictionary, _slot: Control) -> bool:
	if not _bound:
		return false
	if res is ConsumableDataScript:
		return true
	if res is WeaponData:
		var weapons: Array[WeaponData] = _player.weapon_manager.weapons
		if weapons.has(res):
			return true
		return str(payload.get("context_tag", "")) == "backpack" and weapons.size() < SLOT_COUNT
	return false


func _on_slot_dropped(payload: Dictionary, target) -> void:
	var res: Resource = payload.get("resource") as Resource
	var from_barra: bool = str(payload.get("context_tag", "")) == "hotbar"
	var from_index: int = int(payload.get("slot_index", -1))
	var came_from_backpack: bool = false
	if str(payload.get("context_tag", "")) == "offhand":
		# Desde la mano secundaria: el arma pasa al casillero y lo que había ahí (si es un arma de una mano) va a la mano 2
		var displaced: Resource = target.get_item()
		target.set_item(res)
		var wm_off: WeaponManager = _player.weapon_manager
		wm_off.set_offhand_weapon(null)
		if displaced is WeaponData and wm_off.can_equip_offhand(displaced as WeaponData):
			wm_off.set_offhand_weapon(displaced as WeaponData)
		_refresh()
		return
	if str(payload.get("context_tag", "")) == "backpack" and res is WeaponData:
		came_from_backpack = _take_weapon_from_backpack(res as WeaponData, from_index)
		if not came_from_backpack:
			return
	if from_barra and from_index >= 0 and from_index < SLOT_COUNT and _slots[from_index] != target:
		# Entre casilleros de la barra: intercambia (el destino pasa a ser el origen)
		_slots[from_index].set_item(target.get_item())
	target.set_item(res)
	if came_from_backpack:
		# Si el casillero tenía otra arma, sigue en el arsenal: se le busca otro casillero
		_place_loose_weapons()
	_refresh()


## Pasa un arma de la mochila al arsenal (sin duplicarla: la barra guarda la misma instancia).
## Devuelve false, sin tocar nada, si ya no está en esa posición o el arsenal está lleno.
func _take_weapon_from_backpack(weapon: WeaponData, backpack_index: int) -> bool:
	var inventory: InventoryManager = _player.inventory_manager
	var wm: WeaponManager = _player.weapon_manager
	if inventory == null or inventory.get_item_at(backpack_index) != weapon or wm.weapons.size() >= SLOT_COUNT:
		return false
	inventory.remove_item_at(backpack_index)
	wm.weapons.append(weapon)
	if wm.current_weapon == null:
		wm.select_weapon(wm.weapons.size() - 1)
	var inventory_window: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
	if inventory_window != null and inventory_window.visible:
		inventory_window.refresh_all()
	return true


func _on_slot_right_clicked(slot) -> void:
	slot.set_item(null)
	_refresh()


## Mano secundaria: acepta armas del arsenal de una mano o escudos (no la que sostiene la mano principal).
func _accepts_offhand(res: Resource, _payload: Dictionary, _slot: Control) -> bool:
	if not _bound:
		return false
	var weapon: WeaponData = res as WeaponData
	return weapon != null and _player.weapon_manager.can_equip_offhand(weapon)


## Arrastrar al casillero de la mano 2: el arma se mueve ahí. Si ya había otra, vuelve al casillero de origen.
func _on_offhand_dropped(payload: Dictionary, _target) -> void:
	var weapon: WeaponData = payload.get("resource") as WeaponData
	if weapon == null or str(payload.get("context_tag", "")) == "offhand":
		return
	var wm: WeaponManager = _player.weapon_manager
	var previous: WeaponData = wm.offhand_weapon
	if not wm.set_offhand_weapon(weapon):
		return
	var from_index: int = int(payload.get("slot_index", -1))
	if str(payload.get("context_tag", "")) == "hotbar" and from_index >= 0 and from_index < SLOT_COUNT:
		_slots[from_index].set_item(previous)
	elif previous != null:
		_place_loose_weapons()
	_refresh()


## Clic derecho en la mano 2: la deja libre (el arma vuelve a un casillero libre de la barra).
func _on_offhand_right_clicked(_slot) -> void:
	if not _bound:
		return
	_player.weapon_manager.set_offhand_weapon(null)
	_place_loose_weapons()
	_refresh()


# ==============================================================================
# Pintado
# ==============================================================================

func _refresh() -> void:
	if _bound:
		_clean_stale()
		_sync_hand()
		if not _layout_pending:
			_player.hotbar_layout = _serialize_layout()

	var cm: ConsumableManagerScript = _consumable_manager()
	for i in range(SLOT_COUNT):
		var slot = _slots[i]
		var res: Resource = slot.get_item()
		var name_text: String = ""
		var count_text: String = ""
		var icon_tex: Texture2D = null
		var accent: Color = Color(0.5, 0.55, 0.65, 0.7)
		var border: Color = COLOR_BORDER_EMPTY
		var width: int = 1

		if res is WeaponData:
			var weapon: WeaponData = res as WeaponData
			name_text = _clip(weapon.weapon_name, 8)
			count_text = _ammo_text(weapon)
			icon_tex = ItemIconsScript.get_icon_for(weapon)
			accent = Color.WHITE
			border = COLOR_BORDER
		elif res is ConsumableDataScript:
			var data: ConsumableDataScript = res as ConsumableDataScript
			var count: int = cm.get_count(data.consumable_id) if cm != null else 0
			var active: bool = cm != null and cm.is_active(data.consumable_id)
			name_text = data.short_name
			count_text = "%ds" % ceili(cm.get_remaining(data.consumable_id)) if active else "x%d" % count
			accent = data.color if count > 0 or active else Color(0.45, 0.45, 0.5, 1.0)
			border = data.color if active else COLOR_BORDER
			if active:
				width = 2

		if i == _selected:
			border = COLOR_SELECTED
			width = 2
		slot.show_entry(name_text, count_text, accent, icon_tex, border, width)

	_refresh_offhand_slot()
	_name_label.text = _selected_description()


## Pinta el casillero de la mano secundaria: arma elegida y, si no se puede usar ahora, por qué.
func _refresh_offhand_slot() -> void:
	if _offhand_slot == null:
		return
	var weapon: WeaponData = null
	var state: WeaponManager.OffhandState = WeaponManager.OffhandState.EMPTY
	if _bound:
		weapon = _player.weapon_manager.offhand_weapon
		state = _player.weapon_manager.get_offhand_state()
	_offhand_slot.call("set_item", weapon)
	var name_text: String = "Mano 2"
	var count_text: String = ""
	var icon_tex: Texture2D = null
	var accent: Color = Color(0.5, 0.55, 0.65, 0.7)
	var border: Color = COLOR_BORDER_EMPTY
	if weapon != null:
		name_text = _clip(weapon.weapon_name, 8)
		count_text = _ammo_text(weapon)
		icon_tex = ItemIconsScript.get_icon_for(weapon)
		accent = Color.WHITE
		border = COLOR_BORDER
		match state:
			WeaponManager.OffhandState.BLOCKED_TWO_HANDS:
				count_text = "2 MANOS"
				accent = Color(0.75, 0.6, 0.55, 1.0)
				border = Color(0.75, 0.3, 0.25, 0.9)
			WeaponManager.OffhandState.BLOCKED_SAME_WEAPON:
				count_text = "EN USO"
				accent = Color(0.75, 0.6, 0.55, 1.0)
				border = Color(0.75, 0.3, 0.25, 0.9)
	_offhand_slot.call("show_entry", name_text, count_text, accent, icon_tex, border, 1)


## El casillero en mano manda sobre el arma: con un arma se equipa esa arma;
## con un casillero vacío o un consumible el personaje queda con la mano vacía.
func _sync_hand() -> void:
	var wm: WeaponManager = _player.weapon_manager
	var hand: Resource = _entry(_selected)
	var hand_weapon: WeaponData = hand as WeaponData
	var has_weapon: bool = hand_weapon != null and wm.weapons.has(hand_weapon)
	if has_weapon:
		wm.hand_locked = false
		if wm.current_weapon != hand_weapon:
			wm.select_weapon(wm.weapons.find(hand_weapon))
	else:
		wm.hand_locked = true
		if wm.current_weapon != null:
			wm.unequip_hand()


func _selected_description() -> String:
	if not _bound:
		return ""
	var res: Resource = _entry(_selected)
	if res is WeaponData:
		var weapon: WeaponData = res as WeaponData
		return "%s  (%s)" % [weapon.weapon_name, _ammo_text(weapon)]
	if res is ConsumableDataScript:
		var data: ConsumableDataScript = res as ConsumableDataScript
		var cm: ConsumableManagerScript = _consumable_manager()
		var count: int = cm.get_count(data.consumable_id) if cm != null else 0
		return "%s  x%d" % [data.display_name, count]
	return "Mano libre"


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_left = MESSAGE_SECONDS


# ==============================================================================
# Auxiliares
# ==============================================================================

func _entry(index: int) -> Resource:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index].get_item()


func _slot_holding(res: Resource) -> int:
	for i in range(SLOT_COUNT):
		if _entry(i) == res:
			return i
	return -1


func _first_empty() -> int:
	for i in range(SLOT_COUNT):
		if _entry(i) == null:
			return i
	return -1


func _catalog_item(consumable_id: String) -> ConsumableDataScript:
	for data in ConsumableManagerScript.get_catalog():
		if data.consumable_id == consumable_id:
			return data
	return null


func _consumable_manager() -> ConsumableManagerScript:
	return _player.consumable_manager if _player != null else null


func _ammo_text(weapon: WeaponData) -> String:
	if weapon.weapon_type == WeaponData.WeaponType.MELEE or weapon.magazine_size <= 0:
		return "∞"
	return "%d/%d" % [_player.weapon_manager.get_weapon_ammo(weapon), weapon.magazine_size]


func _clip(text: String, max_chars: int) -> String:
	if text.length() > max_chars:
		return text.left(max_chars - 1) + "."
	return text


func _make_text_label(font_size: int, color: Color, outlined: bool) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outlined:
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
	return label
