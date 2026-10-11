class_name HUD
extends CanvasLayer
## Interfaz de combate y estado (HUD) unificada para WARMACHINE.
## Conecta en tiempo real con las señales de HealthComponent, StatsManager y WeaponManager:
## - Superior izquierda: barra de salud y valor numérico legible (HP).
## - Superior derecha: contador de monedas de StatsManager.coins.
## - Inferior derecha: arma equipada y visualización gráfica de los 3 sockets de runas.
## - Centro inferior: barra de acceso rápido de 9 casilleros (ui/hotbar.gd), que reemplaza los botones de arma.

const SteamSkin = preload("res://ui/components/steam_skin.gd")
const ItemIconsScript = preload("res://ui/components/item_icons.gd")
const HotbarScript = preload("res://ui/hotbar.gd")

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var level_label: Label = %LevelLabel
@onready var character_name_label: Label = get_node_or_null("%CharacterNameLabel") as Label
@onready var exp_bar: ProgressBar = %ExpBar
@onready var coins_label: Label = %CoinsLabel
@onready var stats_label: Label = get_node_or_null("%StatsLabel") as Label

@onready var weapon_name_label: Label = %WeaponNameLabel
@onready var ammo_label: Label = get_node_or_null("%AmmoLabel") as Label
@onready var weapon_slots_bar: HBoxContainer = get_node_or_null("%WeaponSlotsBar") as HBoxContainer
@onready var weapon_slot_1_btn: Button = get_node_or_null("%WeaponSlot1Btn") as Button
@onready var weapon_slot_2_btn: Button = get_node_or_null("%WeaponSlot2Btn") as Button
@onready var weapon_slot_3_btn: Button = get_node_or_null("%WeaponSlot3Btn") as Button
@onready var sockets_container: HBoxContainer = %SocketsContainer
@onready var socket_1: PanelContainer = %Socket1
@onready var socket_2: PanelContainer = %Socket2
@onready var socket_3: PanelContainer = %Socket3
@onready var socket_1_rect: ColorRect = %Socket1Rect
@onready var socket_2_rect: ColorRect = %Socket2Rect
@onready var socket_3_rect: ColorRect = %Socket3Rect
@onready var socket_1_label: Label = %Socket1Label
@onready var socket_2_label: Label = %Socket2Label
@onready var socket_3_label: Label = %Socket3Label

var _current_bound_weapon: WeaponData = null
var _is_reloading: bool = false
var _level_banner: Label = null
var _level_banner_tween: Tween = null


func _ready() -> void:
	# Capa 2: la 1 es el posprocesado del mundo (core/post_fx.gd), que no debe teñir el HUD
	layer = maxi(layer, 2)
	_apply_steam_skin()
	# La barra de acceso rápido reemplaza la fila de botones de arma de la esquina
	if weapon_slots_bar != null:
		weapon_slots_bar.visible = false
	# Panel viejo de arma activa (nombre, munición, sockets): la barra ya muestra armas y munición
	var bottom_right: Control = get_node_or_null("BottomRightContainer") as Control
	if bottom_right != null:
		bottom_right.visible = false
	add_child(HotbarScript.new())
	# Enlazar diferido con el jugador de la escena activa
	_find_and_bind_player.call_deferred()
	_update_character_name()
	_setup_hud_tooltips()
	
	if weapon_slot_1_btn != null:
		weapon_slot_1_btn.pressed.connect(func() -> void: _on_slot_button_pressed(0))
	if weapon_slot_2_btn != null:
		weapon_slot_2_btn.pressed.connect(func() -> void: _on_slot_button_pressed(1))
	if weapon_slot_3_btn != null:
		weapon_slot_3_btn.pressed.connect(func() -> void: _on_slot_button_pressed(2))


## Aspecto steampunk: placas, tubo de salud, cartel de monedas y sockets con ícono de runa.
func _apply_steam_skin() -> void:
	for path: String in ["TopLeftContainer/Panel", "BottomRightContainer/Panel"]:
		var plate: PanelContainer = get_node_or_null(path) as PanelContainer
		if plate != null:
			plate.add_theme_stylebox_override("panel", SteamSkin.hud_plate_style())
	var coins_panel: PanelContainer = get_node_or_null("TopRightContainer/Panel") as PanelContainer
	if coins_panel != null:
		coins_panel.add_theme_stylebox_override("panel", SteamSkin.coin_style())
		coins_panel.custom_minimum_size = Vector2(190, 56)
		var top_right: Control = get_node_or_null("TopRightContainer") as Control
		if top_right != null:
			top_right.offset_left = -214.0
			top_right.offset_top = 10.0
			top_right.offset_right = -16.0
			top_right.offset_bottom = 70.0
	if coins_label != null:
		coins_label.add_theme_font_override("font", SteamSkin.title_font())
		coins_label.add_theme_color_override("font_color", SteamSkin.COLOR_TITLE)
		coins_label.add_theme_color_override("font_outline_color", SteamSkin.COLOR_OUTLINE)
		coins_label.add_theme_constant_override("outline_size", 3)
		coins_label.add_theme_font_size_override("font_size", 14)

	if health_bar != null:
		health_bar.custom_minimum_size = Vector2(236, 28)
		health_bar.add_theme_stylebox_override("background", SteamSkin.bar_style("bg"))
		health_bar.add_theme_stylebox_override("fill", SteamSkin.bar_style("fill", Color(0.35, 0.95, 0.42, 1.0)))
	if exp_bar != null:
		exp_bar.custom_minimum_size = Vector2(236, 8)
		var exp_bg: StyleBoxFlat = StyleBoxFlat.new()
		exp_bg.bg_color = Color(0.1, 0.07, 0.06, 1.0)
		exp_bg.border_color = Color(0.55, 0.33, 0.2, 1.0)
		exp_bg.set_border_width_all(1)
		exp_bg.set_corner_radius_all(3)
		var exp_fill: StyleBoxFlat = StyleBoxFlat.new()
		exp_fill.bg_color = Color(1.0, 0.72, 0.2, 1.0)
		exp_fill.set_corner_radius_all(3)
		exp_bg.set_content_margin_all(1.0)
		exp_bar.add_theme_stylebox_override("background", exp_bg)
		exp_bar.add_theme_stylebox_override("fill", exp_fill)

	# Sockets de runas: marco de cobre y el ícono real de la runa
	for panel: PanelContainer in [socket_1, socket_2, socket_3]:
		if panel == null:
			continue
		panel.add_theme_stylebox_override("panel", SteamSkin.socket_style())
		panel.custom_minimum_size = Vector2(30, 30)
		var icon: TextureRect = TextureRect.new()
		icon.name = "RuneIcon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		panel.add_child(icon)

	SteamSkin.skin_tree(self)


func _on_slot_button_pressed(index: int) -> void:
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player_node != null and player_node.weapon_manager != null:
		player_node.weapon_manager.select_weapon(index)


func _update_character_name() -> void:
	if character_name_label != null:
		var sm: SaveManager = SaveManager.get_instance()
		if sm != null and not sm.character_name.is_empty():
			character_name_label.text = sm.character_name.to_upper()
		else:
			character_name_label.text = "OPERADOR"


func _find_and_bind_player() -> void:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		setup_with_player(player)


## Conecta las señales de salud, progreso y armamento del jugador al HUD.
func setup_with_player(player: Player) -> void:
	if player == null:
		return
	
	# 1. Conexión de Salud y Escudo (HealthComponent prioritario, StatsManager de soporte)
	if player.health_component != null:
		var hc: HealthComponent = player.health_component
		if not hc.health_changed.is_connected(_on_health_changed):
			hc.health_changed.connect(_on_health_changed)
		if not hc.shield_changed.is_connected(_on_shield_changed):
			hc.shield_changed.connect(_on_shield_changed)
		_on_health_changed(hc.current_health, hc.max_health)
	elif player.stats_manager != null:
		var stats: StatsManager = player.stats_manager
		if not stats.health_changed.is_connected(_on_health_changed):
			stats.health_changed.connect(_on_health_changed)
		_on_health_changed(stats.current_health, stats.get_max_health())
	
	# 2. Conexión de Monedas y Progresión (StatsManager)
	if player.stats_manager != null:
		var stats: StatsManager = player.stats_manager
		if not stats.coins_changed.is_connected(_on_coins_changed):
			stats.coins_changed.connect(_on_coins_changed)
		if not stats.exp_changed.is_connected(_on_exp_changed):
			stats.exp_changed.connect(_on_exp_changed)
		if not stats.leveled_up.is_connected(_on_leveled_up):
			stats.leveled_up.connect(_on_leveled_up)
		if not stats.level_gained.is_connected(_show_level_up_banner):
			stats.level_gained.connect(_show_level_up_banner)
		if not stats.stats_recalculated.is_connected(_refresh_stats_label):
			stats.stats_recalculated.connect(_refresh_stats_label)
		
		# Sincronización inicial
		_on_coins_changed(stats.coins)
		_on_exp_changed(stats.current_exp, stats.exp_to_next_level)
		_on_leveled_up(stats.level)
	
	# 3. Conexión de Arsenal y Sockets (WeaponManager)
	if player.weapon_manager != null:
		var wm: WeaponManager = player.weapon_manager
		if not wm.weapon_changed.is_connected(_on_weapon_changed):
			wm.weapon_changed.connect(_on_weapon_changed)
		if not wm.ammo_changed.is_connected(_on_ammo_changed):
			wm.ammo_changed.connect(_on_ammo_changed)
		if not wm.reload_started.is_connected(_on_reload_started):
			wm.reload_started.connect(_on_reload_started)
		if not wm.reload_completed.is_connected(_on_reload_completed):
			wm.reload_completed.connect(_on_reload_completed)
		
		if wm.current_weapon != null:
			_on_weapon_changed(wm.current_weapon, wm.current_weapon_index)
		elif not wm.weapons.is_empty():
			wm.select_weapon(clampi(wm.current_weapon_index, 0, wm.weapons.size() - 1))
			_on_weapon_changed(wm.current_weapon, wm.current_weapon_index)
		else:
			_on_weapon_changed(null, -1)
	
	# 4. Actualización ante cambios de equipamiento
	if player.equipment_manager != null:
		var em: EquipmentManager = player.equipment_manager
		if not em.item_equipped.is_connected(_on_equipment_changed):
			em.item_equipped.connect(_on_equipment_changed)
		if not em.item_unequipped.is_connected(_on_equipment_changed):
			em.item_unequipped.connect(_on_equipment_changed)


func _on_equipment_changed(_slot: String, _item: ItemData) -> void:
	if _current_bound_weapon != null:
		_update_weapon_display(_current_bound_weapon)


func _on_health_changed(current: float, max_hp: float) -> void:
	if health_bar != null:
		health_bar.max_value = max_hp
		health_bar.value = current
	if health_label != null:
		var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
		var shield_str: String = ""
		if player_node != null and player_node.health_component != null and player_node.health_component.max_shield > 0.0:
			shield_str = " | ESCUDO: %d" % roundi(player_node.health_component.current_shield)
		health_label.text = "HP: %d / %d%s" % [roundi(current), roundi(max_hp), shield_str]


func _on_shield_changed(_cur_shield: float, _max_shld: float) -> void:
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player_node != null and player_node.health_component != null:
		_on_health_changed(player_node.health_component.current_health, player_node.health_component.max_health)


func _on_coins_changed(new_coins: int) -> void:
	if coins_label != null:
		coins_label.text = "🪙 Monedas: %d" % new_coins


func _on_exp_changed(current: float, max_exp: float) -> void:
	if exp_bar != null:
		exp_bar.max_value = max_exp
		exp_bar.value = current


func _on_leveled_up(new_level: int) -> void:
	if level_label != null:
		level_label.text = "LVL %d" % new_level
	_refresh_stats_label()


## Línea de estado bajo la barra de EXP: armadura (con su mitigación) y daño por disparo del arma activa.
func _refresh_stats_label() -> void:
	if stats_label == null:
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.stats_manager == null:
		return
	var stats: StatsManager = player.stats_manager
	var line: String = "ARM %d (-%d%%)" % [roundi(stats.get_armor()), roundi(stats.get_armor_mitigation_percent())]
	if _current_bound_weapon != null:
		var shot_damage: float = _current_bound_weapon.get_effective_damage() * stats.get_damage_multiplier()
		line += "  |  DMG %d" % roundi(shot_damage)
	stats_label.text = line


## Aviso central al ganar un nivel jugando (no al cargar la partida).
func _show_level_up_banner(new_level: int) -> void:
	if _level_banner == null:
		_level_banner = Label.new()
		_level_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_level_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_level_banner.anchor_left = 0.5
		_level_banner.anchor_right = 0.5
		_level_banner.offset_left = -220.0
		_level_banner.offset_right = 220.0
		_level_banner.offset_top = 110.0
		_level_banner.offset_bottom = 180.0
		_level_banner.add_theme_font_size_override("font_size", 20)
		_level_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		_level_banner.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		_level_banner.add_theme_constant_override("outline_size", 4)
		add_child(_level_banner)

	_level_banner.text = "¡NIVEL %d!\n+%d vida máx  |  +%d%% daño" % [
		new_level,
		roundi(StatsManager.HEALTH_PER_LEVEL),
		roundi(StatsManager.DAMAGE_PER_LEVEL * 100.0)
	]
	_level_banner.modulate.a = 1.0
	_level_banner.visible = true
	if _level_banner_tween != null and _level_banner_tween.is_valid():
		_level_banner_tween.kill()
	_level_banner_tween = create_tween()
	_level_banner_tween.tween_interval(1.6)
	_level_banner_tween.tween_property(_level_banner, "modulate:a", 0.0, 0.6)
	_level_banner_tween.tween_callback(func() -> void: _level_banner.visible = false)


func _on_ammo_changed(current: int, max_mag: int) -> void:
	if ammo_label != null:
		if _current_bound_weapon == null or _current_bound_weapon.weapon_type == WeaponData.WeaponType.MELEE or max_mag <= 0:
			ammo_label.text = "∞"
			ammo_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
		elif _is_reloading:
			ammo_label.text = "RECARGANDO..."
			ammo_label.modulate = Color(1.0, 0.4, 0.3, 1.0)
		else:
			ammo_label.text = "%d / %d" % [current, max_mag]
			ammo_label.modulate = Color(1.0, 0.85, 0.3, 1.0)


func _on_reload_started(_duration: float) -> void:
	_is_reloading = true
	if ammo_label != null:
		ammo_label.text = "RECARGANDO..."
		ammo_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	if _current_bound_weapon != null:
		_update_weapon_display(_current_bound_weapon)


func _on_reload_completed() -> void:
	_is_reloading = false
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player_node != null and player_node.weapon_manager != null and _current_bound_weapon != null:
		var cur: int = player_node.weapon_manager.get_weapon_ammo(_current_bound_weapon)
		_on_ammo_changed(cur, _current_bound_weapon.magazine_size)
	if _current_bound_weapon != null:
		_update_weapon_display(_current_bound_weapon)


func _on_weapon_changed(weapon: WeaponData, _index: int = 0) -> void:
	_is_reloading = false
	# Desconectar arma previa si corresponde
	if _current_bound_weapon != null and is_instance_valid(_current_bound_weapon):
		if _current_bound_weapon.has_signal(&"runes_changed") and _current_bound_weapon.runes_changed.is_connected(_on_runes_changed):
			_current_bound_weapon.runes_changed.disconnect(_on_runes_changed)
	
	_current_bound_weapon = weapon
	
	if _current_bound_weapon != null:
		if _current_bound_weapon.has_signal(&"runes_changed") and not _current_bound_weapon.runes_changed.is_connected(_on_runes_changed):
			_current_bound_weapon.runes_changed.connect(_on_runes_changed)
	
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player_node != null and player_node.weapon_manager != null and weapon != null:
		var cur: int = player_node.weapon_manager.get_weapon_ammo(weapon)
		_on_ammo_changed(cur, weapon.magazine_size)
	elif weapon == null:
		_on_ammo_changed(0, 0)
	
	_update_weapon_display(weapon)


func _on_runes_changed() -> void:
	if _current_bound_weapon != null:
		_update_weapon_display(_current_bound_weapon)


func _update_weapon_display(weapon: WeaponData) -> void:
	_update_weapon_slot_buttons()
	_refresh_stats_label()
	if weapon == null:
		if weapon_name_label != null:
			weapon_name_label.text = "Sin arma"
		if ammo_label != null:
			ammo_label.text = ""
		_clear_socket_visuals()
		return
	
	# 1. Nombre e infusiones activas con número de Slot claro
	if weapon_name_label != null:
		var infusions: Array[String] = weapon.get_elemental_infusions()
		var player: Player = get_tree().get_first_node_in_group(&"player") as Player
		if player != null and player.equipment_manager != null:
			for inf in player.equipment_manager.get_attack_status_effects():
				if not infusions.has(inf):
					infusions.append(inf)
		
		var inf_str: String = ""
		if not infusions.is_empty():
			inf_str = " [%s]" % "/".join(infusions)
		
		var type_icon: String = "⚔️" if weapon.weapon_type == WeaponData.WeaponType.MELEE else "🔫"
		var cur_slot_num: int = 1
		if player != null and player.weapon_manager != null:
			cur_slot_num = player.weapon_manager.current_weapon_index + 1
		var rarity_idx: int = clampi(int(weapon.rarity), 0, 4)
		weapon_name_label.text = "[SLOT %d] %s %s%s (%s)" % [cur_slot_num, type_icon, weapon.weapon_name, inf_str, ItemTooltip.RARITY_NAMES[rarity_idx]]
		weapon_name_label.add_theme_color_override("font_color", ItemTooltip.RARITY_COLORS[rarity_idx])
	
	# 2. Renderizado de los 3 sockets con sus runas
	_update_sockets(weapon)


func _update_weapon_slot_buttons() -> void:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.weapon_manager == null:
		return
	
	var wm: WeaponManager = player.weapon_manager
	var buttons: Array[Button] = [weapon_slot_1_btn, weapon_slot_2_btn, weapon_slot_3_btn]
	var active_idx: int = wm.current_weapon_index
	
	var active_sb: StyleBox = SteamSkin.weapon_button_style(true)
	var inactive_sb: StyleBox = SteamSkin.weapon_button_style(false)

	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		if btn == null:
			continue
		if i < wm.weapons.size():
			var w: WeaponData = wm.weapons[i]
			var w_name: String = w.weapon_name if w != null else "Arma"
			if w_name.length() > 9:
				w_name = w_name.left(8) + "."
			
			if i == active_idx:
				btn.add_theme_stylebox_override("normal", active_sb)
				btn.add_theme_stylebox_override("hover", active_sb)
				btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35, 1.0))
				btn.text = "[★%d] %s" % [i + 1, w_name.to_upper()]
				btn.modulate.a = 1.0
			else:
				btn.add_theme_stylebox_override("normal", inactive_sb)
				btn.add_theme_stylebox_override("hover", inactive_sb)
				btn.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.8))
				btn.text = "[%d] %s" % [i + 1, w_name.to_upper()]
				btn.modulate.a = 0.65
			btn.visible = true
		else:
			btn.add_theme_stylebox_override("normal", inactive_sb)
			btn.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5, 0.5))
			btn.text = "[%d] VACÍO" % (i + 1)
			btn.modulate.a = 0.3
			btn.visible = true


func _update_sockets(weapon: WeaponData) -> void:
	var socket_rects: Array[ColorRect] = [socket_1_rect, socket_2_rect, socket_3_rect]
	var socket_labels: Array[Label] = [socket_1_label, socket_2_label, socket_3_label]
	var socket_panels: Array[PanelContainer] = [socket_1, socket_2, socket_3]
	
	var runes: Array[RuneData] = weapon.socketed_runes
	var max_sockets: int = clampi(weapon.max_sockets, 0, 3)
	
	for i in range(3):
		var rect: ColorRect = socket_rects[i]
		var lbl: Label = socket_labels[i]
		var pnl: PanelContainer = socket_panels[i]
		
		if pnl == null or rect == null or lbl == null:
			continue
		
		var shown_icon: TextureRect = pnl.get_node_or_null("RuneIcon") as TextureRect
		if shown_icon != null:
			shown_icon.visible = false
		if i >= max_sockets:
			# Ranura bloqueada / no disponible en este arma
			pnl.modulate.a = 0.25
			rect.visible = false
			lbl.text = "X"
			pnl.tooltip_text = ""
		elif i < runes.size() and runes[i] != null:
			# Ranura ocupada por una runa
			var rune: RuneData = runes[i]
			pnl.modulate.a = 1.0
			var rune_icon: Texture2D = ItemIconsScript.get_art_icon(rune)
			var icon_node: TextureRect = pnl.get_node_or_null("RuneIcon") as TextureRect
			if rune_icon != null and icon_node != null:
				icon_node.texture = rune_icon
				icon_node.visible = true
				rect.visible = false
				lbl.text = ""
			else:
				rect.visible = true
				rect.color = rune.rune_color
				lbl.text = rune.rune_name.left(1).to_upper()
			pnl.tooltip_text = ""
		else:
			# Ranura disponible y vacía
			pnl.modulate.a = 0.7
			rect.visible = false
			lbl.text = "•"
			pnl.tooltip_text = ""


func _clear_socket_visuals() -> void:
	var socket_rects: Array[ColorRect] = [socket_1_rect, socket_2_rect, socket_3_rect]
	var socket_labels: Array[Label] = [socket_1_label, socket_2_label, socket_3_label]
	for i in range(3):
		if socket_rects[i] != null:
			socket_rects[i].visible = false
		if socket_labels[i] != null:
			socket_labels[i].text = "•"


func _setup_hud_tooltips() -> void:
	var weapon_panel: PanelContainer = get_node_or_null("BottomRightContainer/Panel") as PanelContainer
	if weapon_panel != null:
		weapon_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		weapon_panel.mouse_entered.connect(_on_hud_weapon_mouse_entered)
		weapon_panel.mouse_exited.connect(_on_hud_mouse_exited)
	
	var socket_panels: Array[PanelContainer] = [socket_1, socket_2, socket_3]
	for i in range(socket_panels.size()):
		var pnl: PanelContainer = socket_panels[i]
		if pnl != null:
			pnl.mouse_filter = Control.MOUSE_FILTER_PASS
			var idx: int = i
			pnl.mouse_entered.connect(func() -> void: _on_hud_socket_mouse_entered(idx))
			pnl.mouse_exited.connect(_on_hud_mouse_exited)


func _on_hud_weapon_mouse_entered() -> void:
	if _current_bound_weapon != null:
		var tt: ItemTooltip = ItemSlot.get_shared_tooltip(get_tree())
		if tt != null:
			tt.display_resource(_current_bound_weapon, get_viewport().get_mouse_position())


func _on_hud_socket_mouse_entered(index: int) -> void:
	if _current_bound_weapon != null and index < _current_bound_weapon.socketed_runes.size():
		var rune: RuneData = _current_bound_weapon.socketed_runes[index]
		if rune != null:
			var tt: ItemTooltip = ItemSlot.get_shared_tooltip(get_tree())
			if tt != null:
				tt.display_resource(rune, get_viewport().get_mouse_position())


func _on_hud_mouse_exited() -> void:
	if ItemSlot._shared_tooltip != null and is_instance_valid(ItemSlot._shared_tooltip):
		ItemSlot._shared_tooltip.hide_tooltip()

