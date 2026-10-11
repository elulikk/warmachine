class_name ItemTooltip
extends PanelContainer
## Tooltip modular avanzado de alta densidad para WARMACHINE.
## Renderiza fichas técnicas detalladas con color de rareza, desglose de estadísticas,
## afijos, munición, sockets, descripciones y valor económico en monedas.

const SteamSkin = preload("res://ui/components/steam_skin.gd")

const RARITY_COLORS: Dictionary[int, Color] = {
	0: Color(0.82, 0.84, 0.86), # COMMON (Gris perla)
	1: Color(0.29, 0.87, 0.50), # UNCOMMON (Verde)
	2: Color(0.38, 0.65, 0.98), # RARE (Azul)
	3: Color(0.75, 0.52, 0.99), # EPIC (Púrpura)
	4: Color(0.96, 0.62, 0.04)  # LEGENDARY (Dorado/Ámbar)
}

const RARITY_NAMES: Dictionary[int, String] = {
	0: "NORMAL",
	1: "BUENO",
	2: "RARO",
	3: "ÉPICO",
	4: "LEGENDARIO"
}

const SLOT_NAMES: Dictionary[String, String] = {
	"HEAD": "CABEZA",
	"CHEST": "PECHO",
	"GLOVES": "GUANTES",
	"BOOTS": "BOTAS",
	"BACK": "ESPALDA",
	"ACCESSORY": "ACCESORIO",
	"TACTICAL": "TÁCTICO"
}

const STAT_NAMES: Dictionary[String, String] = {
	"move_speed": "Velocidad de movimiento",
	"max_health": "Vida máxima",
	"max_jumps": "Saltos",
	"damage_multiplier": "Daño",
	"crit_chance": "Probabilidad de crítico",
	"crit_multiplier": "Daño crítico",
	"armor": "Armadura"
}

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var header_separator: HSeparator = %HeaderSeparator
@onready var combat_stats_box: VBoxContainer = %CombatStatsBox
@onready var dps_value_label: Label = %DPSValueLabel
@onready var damage_value: Label = %DamageValue
@onready var fire_rate_value: Label = %FireRateValue
@onready var armor_pen_value: Label = %ArmorPenValue
@onready var ammo_value: Label = %AmmoValue
@onready var sockets_indicator_label: Label = %SocketsIndicatorLabel
@onready var item_stats_box: VBoxContainer = %ItemStatsBox
@onready var modifiers_label: Label = %ModifiersLabel
@onready var desc_separator: HSeparator = %DescSeparator
@onready var description_label: Label = %DescriptionLabel
@onready var gold_value_label: Label = %GoldValueLabel

var _current_resource: Resource = null
var _stylebox: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 300
	visible = false
	
	# Asegurar copia única del StyleBoxFlat para modificar bordes dinámicamente
	var existing_style: StyleBox = get_theme_stylebox("panel")
	if existing_style is StyleBoxFlat:
		_stylebox = (existing_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		_stylebox = StyleBoxFlat.new()
		_stylebox.bg_color = Color(0.067, 0.078, 0.094, 0.933)
		_stylebox.set_border_width_all(2)
		_stylebox.set_corner_radius_all(4)
		_stylebox.content_margin_left = 10.0
		_stylebox.content_margin_top = 8.0
		_stylebox.content_margin_right = 10.0
		_stylebox.content_margin_bottom = 8.0
	# Madera oscura con marco del color de la rareza (steampunk)
	_stylebox.bg_color = Color(0.13, 0.09, 0.07, 0.97)
	_stylebox.set_border_width_all(3)
	_stylebox.set_corner_radius_all(7)
	_stylebox.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	_stylebox.shadow_size = 8
	_stylebox.content_margin_left = 12.0
	_stylebox.content_margin_right = 12.0
	_stylebox.content_margin_top = 10.0
	_stylebox.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", _stylebox)
	SteamSkin.skin_tree(self)
	title_label.add_theme_font_override("font", SteamSkin.title_font())
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_outline_color", SteamSkin.COLOR_OUTLINE)
	title_label.add_theme_constant_override("outline_size", 3)


## Muestra y configura el tooltip para el recurso especificado en las coordenadas del cursor.
func display_resource(res: Resource, mouse_pos: Vector2) -> void:
	if res == null:
		hide_tooltip()
		return
	
	_current_resource = res
	_populate_data(res)
	visible = true
	
	call_deferred("_update_position_clamped", mouse_pos)


## Reemplaza la línea de valor en monedas (el comercio muestra el precio de compra o de venta).
func set_price_text(text: String) -> void:
	if gold_value_label != null:
		gold_value_label.text = text


## Oculta el tooltip y limpia referencias.
func hide_tooltip() -> void:
	visible = false
	_current_resource = null


func _update_position_clamped(mouse_pos: Vector2) -> void:
	reset_size()
	
	var vp_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = size
	
	var offset: Vector2 = Vector2(16.0, 16.0)
	var target_x: float = mouse_pos.x + offset.x
	var target_y: float = mouse_pos.y + offset.y
	
	# Invertir hacia la izquierda si excede el borde derecho
	if target_x + tooltip_size.x > vp_size.x - 8.0:
		target_x = mouse_pos.x - tooltip_size.x - offset.x
	
	# Invertir hacia arriba si excede el borde inferior
	if target_y + tooltip_size.y > vp_size.y - 8.0:
		target_y = mouse_pos.y - tooltip_size.y - offset.y
	
	# Clamp de seguridad final dentro de la ventana
	target_x = clampf(target_x, 8.0, maxf(8.0, vp_size.x - tooltip_size.x - 8.0))
	target_y = clampf(target_y, 8.0, maxf(8.0, vp_size.y - tooltip_size.y - 8.0))
	
	global_position = Vector2(target_x, target_y)


func _populate_data(res: Resource) -> void:
	var rarity_idx: int = int(res.get("rarity")) if res.get("rarity") != null else 0
	rarity_idx = clampi(rarity_idx, 0, 4)
	
	var rarity_color: Color = RARITY_COLORS.get(rarity_idx, RARITY_COLORS[0])
	var rarity_name: String = RARITY_NAMES.get(rarity_idx, "COMÚN")
	
	if _stylebox != null:
		_stylebox.border_color = rarity_color
	
	# 1. Configuración de Armas (WeaponData)
	if res is WeaponData:
		var wp: WeaponData = res as WeaponData
		title_label.text = wp.weapon_name
		title_label.modulate = rarity_color
		
		var w_type_str: String = "CUERPO A CUERPO" if wp.weapon_type == WeaponData.WeaponType.MELEE else "BALÍSTICA"
		subtitle_label.text = "%s • %s • %s • %s" % [wp.get_family_label().to_upper(), wp.get_grip_label().to_upper(), w_type_str, rarity_name]
		
		combat_stats_box.visible = true
		item_stats_box.visible = false
		
		dps_value_label.text = "%.1f DPS" % wp.get_sustained_dps()
		damage_value.text = wp.get_damage_per_shot_text()
		fire_rate_value.text = "%.1f/s" % wp.fire_rate
		armor_pen_value.text = "%.0f%%" % (wp.get_armor_penetration() * 100.0)
		
		if wp.weapon_type == WeaponData.WeaponType.RANGED and wp.magazine_size > 0:
			ammo_value.text = "%d (%0.1fs)" % [wp.magazine_size, wp.reload_time]
		else:
			ammo_value.text = "Infinito (Melee)"
		
		# Sockets
		var runes_list: Array[String] = []
		for r in wp.socketed_runes:
			if r != null:
				runes_list.append(r.rune_name)
		var runes_detail: String = " [%s]" % ", ".join(runes_list) if not runes_list.is_empty() else ""
		sockets_indicator_label.text = "• Sockets: %d / %d%s" % [wp.socketed_runes.size(), wp.max_sockets, runes_detail]
		
		# Descripción
		var desc: String = wp.description
		if desc.is_empty():
			if wp.weapon_type == WeaponData.WeaponType.MELEE:
				desc = "Arma blanca de alta precisión. Ejecuta tajos y parry balístico contra proyectiles hostiles."
			else:
				desc = "Armamento balístico estándar de combate táctico."
		description_label.text = desc
		
		# Oro
		gold_value_label.text = "%d Monedas" % wp.gold_value

	# 2. Configuración de Ítems Equipables y Pasivos (ItemData)
	elif res is ItemData:
		var itm: ItemData = res as ItemData
		title_label.text = itm.item_name
		title_label.modulate = rarity_color
		
		var slot_str: String = "CONSUMIBLE"
		if not itm.equip_slot.is_empty() and itm.equip_slot != "NONE":
			slot_str = SLOT_NAMES.get(itm.equip_slot, itm.equip_slot)
		subtitle_label.text = "EQUIPAMIENTO [%s] • %s" % [slot_str, rarity_name]
		
		combat_stats_box.visible = false
		item_stats_box.visible = true
		
		var lines: Array[String] = []
		if not itm.elemental_infusion.is_empty():
			lines.append("• Infusión Elemental: %s" % itm.elemental_infusion)
		for mod in itm.modifiers:
			var s_name: String = str(mod.get("stat", ""))
			var s_val: float = float(mod.get("value", 0.0))
			var is_pct: bool = bool(mod.get("is_percent", false))
			var sign_char: String = "+" if s_val >= 0 else ""
			var stat_label: String = STAT_NAMES.get(s_name, s_name)
			if is_pct:
				lines.append("• %s: %s%.0f%%" % [stat_label, sign_char, s_val * 100.0])
			elif s_name == "crit_chance":
				lines.append("• %s: %s%.0f%%" % [stat_label, sign_char, s_val * 100.0])
			elif s_name == "armor":
				var reduction: float = s_val / (100.0 + s_val) * 100.0
				lines.append("• %s: %s%.0f (-%.0f%% de daño recibido)" % [stat_label, sign_char, s_val, reduction])
			else:
				lines.append("• %s: %s%.0f" % [stat_label, sign_char, s_val])
		if itm.grants_extra_jump > 0:
			lines.append("• Saltos adicionales: +%d" % itm.grants_extra_jump)
		for tag in itm.tags:
			if tag == "WALL_JUMP":
				lines.append("• Habilidad: Rebote y deslizamiento en paredes")
			elif tag == "JETPACK":
				lines.append("• Habilidad: Propulsión continua por jetpack")
			elif tag == "WINGS":
				lines.append("• Habilidad: Aleteo aéreo múltiple")
			elif tag == "MAGIC_FLIGHT":
				lines.append("• Habilidad: Vuelo mágico omnidireccional")
		
		if lines.is_empty():
			modifiers_label.text = "• Sin modificadores pasivos directos."
		else:
			modifiers_label.text = "\n".join(lines)
		
		description_label.text = itm.description if not itm.description.is_empty() else "Equipo táctico modular."
		gold_value_label.text = "%d Monedas" % itm.gold_value

	# 3. Configuración de Runas (RuneData)
	elif res is RuneData:
		var rn: RuneData = res as RuneData
		title_label.text = rn.rune_name
		title_label.modulate = rarity_color
		
		subtitle_label.text = "RUNA DE ARMAMENTO • %s" % rarity_name
		
		combat_stats_box.visible = false
		item_stats_box.visible = true
		
		var lines: Array[String] = []
		if rn.bonus_damage > 0.0:
			lines.append("• Daño plano: +%.1f" % rn.bonus_damage)
		if rn.extra_bounces > 0:
			lines.append("• Rebotes contra muros: +%d" % rn.extra_bounces)
		if rn.extra_pierce > 0:
			lines.append("• Perforaciones de hostiles: +%d" % rn.extra_pierce)
		if rn.extra_forks > 0:
			lines.append("• Bifurcaciones al impacto: +%d" % rn.extra_forks)
		if not rn.elemental_infusion.is_empty():
			lines.append("• Infusión Elemental: %s" % rn.elemental_infusion)
		
		if lines.is_empty():
			modifiers_label.text = "• Modificador balístico pasivo."
		else:
			modifiers_label.text = "\n".join(lines)
		
		description_label.text = rn.description if not rn.description.is_empty() else "Runa de modificación para armas."
		gold_value_label.text = "%d Monedas" % rn.gold_value

	else:
		# Fallback genérico
		title_label.text = "Objeto"
		title_label.modulate = Color.WHITE
		subtitle_label.text = "RECURSO"
		combat_stats_box.visible = false
		item_stats_box.visible = false
		description_label.text = ""
		gold_value_label.text = "0 Monedas"
