extends DraggableWindow
## Ventana de compra del Mercader del Campamento Base.
## Sección CONSUMIBLES: catálogo de `ConsumableManager` con precio y cantidad (máximo 5).
## Sección EQUIPO: armaduras y armas por tier (rareza); el precio es el `gold_value` del recurso.
## Guarda la partida tras cada compra.
## Sin class_name a propósito: se referencia por la ruta de su escena.

const ConsumableManagerScript = preload("res://core/consumables/consumable_manager.gd")
const ConsumableDataScript = preload("res://core/consumables/consumable_data.gd")
const ItemIconsScript = preload("res://ui/components/item_icons.gd")

## Equipo a la venta, ordenado por tier. Cuchillo, revólver oxidado y carabina los da la campaña.
const GEAR_PATHS: Array[String] = [
	"res://data/weapons/pistol_9mm.tres",
	"res://data/weapons/iron_sword.tres",
	"res://data/weapons/colt_44.tres",
	"res://data/weapons/mp5.tres",
	"res://data/weapons/smg.tres",
	"res://data/weapons/ak47.tres",
	"res://data/weapons/m4.tres",
	"res://data/weapons/katana.tres",
	"res://data/weapons/desert_eagle.tres",
	"res://data/weapons/heavy_sniper.tres",
	"res://data/weapons/heavy_hammer.tres"
]

@onready var coins_label: Label = %CoinsLabel
@onready var items_box: VBoxContainer = %ItemsBox
@onready var message_label: Label = %MessageLabel

var player: Player = null


func _ready() -> void:
	super._ready()
	window_title = "MERCADER"
	visible = false
	window_closed.connect(_on_window_closed)


func open_window() -> void:
	GameFeel.music_push(self, &"shop")
	_bind_player()
	message_label.text = ""
	refresh()
	super.open_window()
	_center_on_screen.call_deferred()


func _center_on_screen() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	global_position = Vector2(
		maxf(10.0, (vp_size.x - size.x) * 0.5),
		maxf(10.0, (vp_size.y - size.y) * 0.5)
	)


func _bind_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Player


## Reconstruye la lista de ofertas según las monedas y cantidades actuales.
func refresh() -> void:
	_bind_player()
	if player == null or player.stats_manager == null or player.consumable_manager == null:
		return

	coins_label.text = "Monedas: %d" % player.stats_manager.coins

	for child in items_box.get_children():
		child.queue_free()

	items_box.add_child(_build_section_title("CONSUMIBLES"))
	for data in ConsumableManagerScript.get_catalog():
		items_box.add_child(_build_row(data))

	items_box.add_child(_build_section_title("EQUIPO"))
	for path in GEAR_PATHS:
		var gear: Resource = load(path) as Resource
		if gear != null:
			items_box.add_child(_build_gear_row(gear, path))


func _build_section_title(text: String) -> Label:
	var title: Label = Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))
	return title


func _build_row(data: ConsumableDataScript) -> Control:
	var coins: int = player.stats_manager.coins
	var owned: int = player.consumable_manager.get_count(data.consumable_id)
	var is_full: bool = player.consumable_manager.is_full(data.consumable_id)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var swatch: ColorRect = ColorRect.new()
	swatch.custom_minimum_size = Vector2(8.0, 44.0)
	swatch.color = data.color
	row.add_child(swatch)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)

	var name_label: Label = Label.new()
	name_label.text = "%s   (tenés %d/%d)" % [data.display_name, owned, ConsumableManagerScript.MAX_STACK]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", data.color)
	info.add_child(name_label)

	var desc_label: Label = Label.new()
	desc_label.text = data.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(230.0, 0.0)
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92, 1.0))
	info.add_child(desc_label)

	var buy_button: Button = Button.new()
	buy_button.custom_minimum_size = Vector2(104.0, 44.0)
	buy_button.add_theme_font_size_override("font_size", 11)
	if is_full:
		buy_button.text = "Máximo"
		buy_button.disabled = true
	else:
		buy_button.text = "Comprar\n%d monedas" % data.price
		buy_button.disabled = coins < data.price
	buy_button.pressed.connect(_on_buy_pressed.bind(data))
	row.add_child(buy_button)

	return row


## Ícono del equipo dentro de un marco con el color de rareza (igual que en el inventario).
func _build_icon_frame(gear: Resource, rarity_color: Color) -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.custom_minimum_size = Vector2(44.0, 44.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4.0)
	frame.add_theme_stylebox_override("panel", style)

	var icon: TextureRect = TextureRect.new()
	icon.texture = ItemIconsScript.get_icon_for(gear)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(36.0, 36.0)
	frame.add_child(icon)
	return frame


func _build_gear_row(gear: Resource, path: String) -> Control:
	var coins: int = player.stats_manager.coins
	var rarity_idx: int = 0
	var display_name: String = "Equipo"
	var price: int = 0
	var summary: String = ""

	if gear is ItemData:
		var item: ItemData = gear as ItemData
		rarity_idx = clampi(int(item.rarity), 0, 4)
		display_name = item.item_name
		price = item.gold_value
		summary = item.description
		var stat_parts: Array[String] = []
		for mod: Dictionary in item.modifiers:
			var stat_name: String = str(mod.get("stat", ""))
			var stat_value: float = float(mod.get("value", 0.0))
			if stat_name == "armor":
				stat_parts.append("Armadura +%.0f (-%.0f%% de daño)" % [stat_value, stat_value / (100.0 + stat_value) * 100.0])
			elif stat_name == "crit_chance":
				stat_parts.append("Crítico +%.0f%%" % (stat_value * 100.0))
			elif stat_name == "crit_multiplier":
				stat_parts.append("Daño crítico +%.0f%%" % (stat_value * 100.0))
			elif stat_name == "damage_multiplier":
				stat_parts.append("Daño +%.0f%%" % (stat_value * 100.0))
			elif stat_name == "max_health":
				stat_parts.append("Vida +%.0f" % stat_value)
			elif stat_name == "move_speed":
				stat_parts.append("Velocidad +%.0f" % stat_value)
		if not stat_parts.is_empty():
			summary = "%s. %s" % [", ".join(stat_parts), item.description]
	elif gear is WeaponData:
		var weapon: WeaponData = gear as WeaponData
		rarity_idx = clampi(int(weapon.rarity), 0, 4)
		display_name = weapon.weapon_name
		price = weapon.gold_value
		summary = "%.0f DPS  |  daño %s  |  %.1f/s" % [weapon.get_sustained_dps(), weapon.get_damage_per_shot_text(), weapon.fire_rate]
		if weapon.weapon_type == WeaponData.WeaponType.RANGED and weapon.magazine_size > 0:
			summary += "  |  cargador %d" % weapon.magazine_size

	var rarity_color: Color = ItemTooltip.RARITY_COLORS[rarity_idx]
	var is_owned: bool = _player_owns(path)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	row.add_child(_build_icon_frame(gear, rarity_color))

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)

	var name_label: Label = Label.new()
	name_label.text = "%s   (%s)" % [display_name, ItemTooltip.RARITY_NAMES[rarity_idx]]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", rarity_color)
	info.add_child(name_label)

	var desc_label: Label = Label.new()
	desc_label.text = summary
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(230.0, 0.0)
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92, 1.0))
	info.add_child(desc_label)

	var buy_button: Button = Button.new()
	buy_button.custom_minimum_size = Vector2(104.0, 44.0)
	buy_button.add_theme_font_size_override("font_size", 11)
	if is_owned:
		buy_button.text = "Ya lo tenés"
		buy_button.disabled = true
	else:
		buy_button.text = "Comprar\n%d monedas" % price
		buy_button.disabled = coins < price
	buy_button.pressed.connect(_on_buy_gear_pressed.bind(path))
	row.add_child(buy_button)

	return row


## Indica si el jugador ya posee este equipo (equipado, en arsenal, en mochila o en el baúl).
func _player_owns(path: String) -> bool:
	if player == null:
		return false

	if player.equipment_manager != null:
		for equipped: Variant in player.equipment_manager.equipped_items.values():
			var equipped_item: ItemData = equipped as ItemData
			if equipped_item != null and equipped_item.resource_path == path:
				return true

	if player.weapon_manager != null:
		for weapon: WeaponData in player.weapon_manager.weapons:
			if weapon != null and weapon.source_resource_path == path:
				return true

	if player.inventory_manager != null:
		for stored: Resource in player.inventory_manager.backpack:
			if stored == null:
				continue
			var stored_path: String = stored.resource_path
			var stored_weapon: WeaponData = stored as WeaponData
			if stored_weapon != null and stored_path.is_empty():
				stored_path = stored_weapon.source_resource_path
			if stored_path == path:
				return true

	var sm: SaveManager = SaveManager.get_instance()
	if sm != null and sm.stash_has_path(path):
		return true

	return false


func _on_buy_pressed(data: ConsumableDataScript) -> void:
	_bind_player()
	if player == null or player.stats_manager == null or player.consumable_manager == null:
		return

	if player.consumable_manager.is_full(data.consumable_id):
		_say("Ya tenés el máximo de %s (%d)." % [data.display_name, ConsumableManagerScript.MAX_STACK])
		return

	if not player.stats_manager.spend_coins(data.price):
		_say("No te alcanzan las monedas.")
		GameFeel.sfx(self, &"deny", Vector2.INF, -4.0)
		return

	player.consumable_manager.add(data.consumable_id, 1)
	GameFeel.sfx(self, &"buy", Vector2.INF, -3.0)
	_say("Compraste: %s." % data.display_name)

	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()

	refresh()


func _on_buy_gear_pressed(path: String) -> void:
	_bind_player()
	if player == null or player.stats_manager == null:
		return

	var gear: Resource = load(path) as Resource
	if gear == null:
		return
	if _player_owns(path):
		_say("Ya tenés ese equipo.")
		return

	var item: ItemData = gear as ItemData
	var weapon: WeaponData = gear as WeaponData
	var price: int = item.gold_value if item != null else weapon.gold_value
	var display_name: String = item.item_name if item != null else weapon.weapon_name

	# Verificar lugar antes de cobrar
	var goes_to_slot: bool = false
	var goes_to_arsenal: bool = false
	var target_slot: String = ""
	if item != null and player.equipment_manager != null:
		target_slot = player.equipment_manager.get_target_slot_for_item(item)
		goes_to_slot = not target_slot.is_empty() and player.equipment_manager.get_equipped_item(target_slot) == null
	elif weapon != null:
		goes_to_arsenal = player.weapon_manager != null and player.weapon_manager.weapons.size() < 3
	if not goes_to_slot and not goes_to_arsenal:
		if player.inventory_manager == null or not player.inventory_manager.has_free_space():
			_say("Mochila llena. Liberá un casillero.")
			return

	if not player.stats_manager.spend_coins(price):
		_say("No te alcanzan las monedas.")
		GameFeel.sfx(self, &"deny", Vector2.INF, -4.0)
		return

	GameFeel.sfx(self, &"buy", Vector2.INF, -3.0)
	if goes_to_slot:
		player.equipment_manager.equip_item(target_slot, item)
		_say("Compraste y equipaste: %s." % display_name)
	elif goes_to_arsenal:
		player.weapon_manager.add_weapon(weapon, player.weapon_manager.weapons.is_empty())
		_say("Compraste: %s (en tu arsenal)." % display_name)
	elif weapon != null:
		var instance: WeaponData = weapon.duplicate() as WeaponData
		instance.source_resource_path = path
		player.inventory_manager.add_item(instance)
		_say("Compraste: %s (en la mochila)." % display_name)
	else:
		player.inventory_manager.add_item(item)
		_say("Compraste: %s (en la mochila)." % display_name)

	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()

	refresh()


func _say(text: String) -> void:
	if message_label != null:
		message_label.text = text


func _on_window_closed() -> void:
	GameFeel.music_pop(self, &"shop")
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()
