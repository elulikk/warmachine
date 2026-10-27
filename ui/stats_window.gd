class_name StatsWindow
extends DraggableWindow
## Ventana Modular de Estadísticas y Rendimiento (Tecla C).
## Hereda de DraggableWindow para permitir reposicionamiento libre con el ratón sobre el Viewport.
## Estructura interna de 2 solapas (TabContainer):
## 1. "Ficha de Personaje": Rendimiento en vivo (Supervivencia, Movilidad, Arma activa con DPS sostenido).
## 2. "Registro Histórico": Métricas del perfil acumuladas por MetricsManager.

@onready var tab_container: TabContainer = %StatsTabContainer

# Solapa 1 - Supervivencia
@onready var health_val_label: Label = %HealthValLabel
@onready var shield_val_label: Label = %ShieldValLabel
@onready var armor_val_label: Label = %ArmorValLabel
@onready var mitigation_val_label: Label = %MitigationValLabel

# Solapa 1 - Movilidad
@onready var speed_val_label: Label = %SpeedValLabel
@onready var jumps_val_label: Label = %JumpsValLabel
@onready var mobility_states_label: Label = %MobilityStatesLabel

# Solapa 1 - Arma Activa
@onready var weapon_name_label: Label = %WeaponNameLabel
@onready var impact_dmg_label: Label = %ImpactDmgLabel
@onready var fire_rate_label: Label = %FireRateLabel
@onready var mag_reload_label: Label = %MagReloadLabel
@onready var armor_pen_label: Label = %ArmorPenLabel
@onready var infusions_label: Label = %InfusionsLabel
@onready var sustained_dps_label: Label = %SustainedDpsLabel
@onready var damage_breakdown_label: Label = get_node_or_null("%DamageBreakdownLabel") as Label
@onready var crit_val_label: Label = get_node_or_null("%CritValLabel") as Label

# Solapa 2 - Registro Histórico
@onready var time_played_label: Label = %TimePlayedLabel
@onready var total_kills_label: Label = %TotalKillsLabel
@onready var kills_runners_label: Label = %KillsRunnersLabel
@onready var kills_brutes_label: Label = %KillsBrutesLabel
@onready var kills_sentinels_label: Label = %KillsSentinelsLabel
@onready var kills_turrets_label: Label = %KillsTurretsLabel
@onready var coins_economy_label: Label = %CoinsEconomyLabel
@onready var player_deaths_label: Label = %PlayerDeathsLabel
@onready var contracts_completed_label: Label = %ContractsCompletedLabel

const COLOR_TITLE: Color = Color(0.65, 0.72, 0.8, 1.0)
const COLOR_VALUE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_EXP: Color = Color(0.7, 0.56, 0.3, 1.0)
const FONT_SIZE: int = 10
## Crecimiento de la meta de experiencia por nivel (el mismo número que StatsManager.add_experience).
const EXP_GROWTH: float = 1.7

var player: Player = null
var _refresh_timer: float = 0.0
## Filas armadas por código: id -> Label del valor (ficha de personaje y registro histórico).
var _char_rows: Dictionary = {}
var _hist_rows: Dictionary = {}
var _exp_bar: ProgressBar = null
var _kills_grid: GridContainer = null
var _kills_rows: Dictionary = {}


func _ready() -> void:
	super._ready()
	window_title = "ESTADÍSTICAS Y TELEMETRÍA [C]"
	visible = false
	add_to_group(&"stats_window")
	_build_character_panel()
	_build_history_panels()
	call_deferred("_initial_position")


## Panel "PERSONAJE" al principio de la ficha: nivel, experiencia (actual, faltante, total) y bonos de nivel.
func _build_character_panel() -> void:
	var sheet: VBoxContainer = tab_container.get_node_or_null("Ficha de Personaje/VBox") as VBoxContainer
	if sheet == null:
		return
	var panel_template: PanelContainer = sheet.get_node_or_null("SurvivalPanel") as PanelContainer
	var panel: PanelContainer = _make_panel(panel_template)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	column.add_child(_make_header("● PERSONAJE Y PROGRESIÓN", Color(1.0, 0.82, 0.4, 1.0)))
	var grid: GridContainer = _make_grid()
	column.add_child(grid)
	_char_rows["name"] = _add_row(grid, "Personaje:")
	_char_rows["level"] = _add_row(grid, "Nivel:")
	_char_rows["exp"] = _add_row(grid, "Experiencia:")
	# Barra lisa de progreso al siguiente nivel, bajo la fila de experiencia
	_exp_bar = ProgressBar.new()
	_exp_bar.show_percentage = false
	_exp_bar.custom_minimum_size = Vector2(0.0, 5.0)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = COLOR_EXP
	_exp_bar.add_theme_stylebox_override("background", bg)
	_exp_bar.add_theme_stylebox_override("fill", fg)
	column.add_child(_exp_bar)
	var grid2: GridContainer = _make_grid()
	column.add_child(grid2)
	_char_rows["missing"] = _add_row(grid2, "Falta para subir:")
	_char_rows["total_exp"] = _add_row(grid2, "Experiencia total:")
	_char_rows["next_bonus"] = _add_row(grid2, "Al subir de nivel:")
	_char_rows["level_bonus"] = _add_row(grid2, "Bono por nivel actual:")
	_char_rows["max_health"] = _add_row(grid2, "Vida máxima:")
	_char_rows["damage_mult"] = _add_row(grid2, "Multiplicador de daño:")
	_char_rows["crit"] = _add_row(grid2, "Crítico (prob. / daño):")
	_char_rows["coins"] = _add_row(grid2, "Monedas:")
	_char_rows["crystals"] = _add_row(grid2, "Cristales de tiempo:")
	sheet.add_child(panel)
	sheet.move_child(panel, 0)


## Registro histórico: promedios de carrera y las bajas de cada tipo de enemigo (dentro del panel de bajas).
func _build_history_panels() -> void:
	var sheet: VBoxContainer = tab_container.get_node_or_null("Registro Histórico/VBox") as VBoxContainer
	if sheet == null:
		return
	var template: PanelContainer = sheet.get_node_or_null("GlobalPanel") as PanelContainer
	var panel: PanelContainer = _make_panel(template)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	column.add_child(_make_header("● RENDIMIENTO DE CARRERA", Color(0.35, 0.75, 1.0, 1.0)))
	var grid: GridContainer = _make_grid()
	column.add_child(grid)
	_hist_rows["kills_hour"] = _add_row(grid, "Bajas por hora:")
	_hist_rows["kd"] = _add_row(grid, "Bajas por muerte:")
	_hist_rows["coins_kill"] = _add_row(grid, "Monedas por baja:")
	_hist_rows["net_coins"] = _add_row(grid, "Monedas netas:")
	sheet.add_child(panel)
	sheet.move_child(panel, 1)

	# Las bajas de cada tipo reemplazan la lista fija de cuatro enemigos del panel de bajas
	var kills_col: VBoxContainer = sheet.get_node_or_null("KillsPanel/VBox") as VBoxContainer
	var old_grid: Control = sheet.get_node_or_null("KillsPanel/VBox/Grid") as Control
	if kills_col == null:
		return
	if old_grid != null:
		old_grid.visible = false
	_kills_grid = _make_grid()
	kills_col.add_child(_kills_grid)


func _make_panel(template: PanelContainer) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	if template != null:
		var box: StyleBox = template.get_theme_stylebox("panel")
		if box != null:
			panel.add_theme_stylebox_override("panel", box)
	return panel


func _make_header(text: String, color: Color) -> Label:
	var header: Label = Label.new()
	header.text = text
	header.add_theme_color_override("font_color", color)
	header.add_theme_font_size_override("font_size", 11)
	return header


func _make_grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	return grid


func _add_row(grid: GridContainer, title: String) -> Label:
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", COLOR_TITLE)
	title_label.add_theme_font_size_override("font_size", FONT_SIZE)
	grid.add_child(title_label)
	var value: Label = Label.new()
	value.add_theme_color_override("font_color", COLOR_VALUE)
	value.add_theme_font_size_override("font_size", FONT_SIZE)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value)
	return value


## Experiencia acumulada desde el nivel 1: lo gastado en los niveles ya superados (se reconstruye hacia atrás desde
## la meta actual con el mismo crecimiento de StatsManager) más la del nivel en curso.
static func total_experience(level: int, current_exp: float, need: float) -> float:
	var total: float = current_exp
	var step: float = need
	for i in range(maxi(0, level - 1)):
		step = roundf(step / EXP_GROWTH)
		total += step
	return total


func _initial_position() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	# Posicionar centrada hacia la derecha para convivir con HUD o inventario
	global_position = Vector2(
		clampf(vp_size.x * 0.5 - size.x * 0.5, 10.0, maxf(10.0, vp_size.x - size.x)),
		clampf(vp_size.y * 0.5 - size.y * 0.5, 10.0, maxf(10.0, vp_size.y - size.y))
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stats_window"):
		get_viewport().set_input_as_handled()
		toggle_window()


func open_window() -> void:
	_bind_player()
	refresh_all()
	super.open_window()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.25: # Refresco reactivo periódico de métricas en vivo
		_refresh_timer = 0.0
		refresh_all()


func _bind_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Player
		if player != null:
			if player.stats_manager != null and not player.stats_manager.stats_recalculated.is_connected(refresh_all):
				player.stats_manager.stats_recalculated.connect(refresh_all)
			if player.weapon_manager != null and not player.weapon_manager.weapon_changed.is_connected(_on_weapon_changed):
				player.weapon_manager.weapon_changed.connect(_on_weapon_changed)


func _on_weapon_changed(_w: WeaponData, _idx: int) -> void:
	if visible:
		refresh_all()


func refresh_all() -> void:
	_bind_player()
	_refresh_character_sheet()
	_refresh_metrics_sheet()


func _refresh_character_sheet() -> void:
	if player == null or not is_instance_valid(player):
		return
	_refresh_progression()
	
	# 1. Supervivencia
	var cur_hp: float = 0.0
	var max_hp: float = 100.0
	var cur_shield: float = 0.0
	var max_shield: float = 0.0
	var shield_rate: float = 0.0
	var shield_delay: float = 0.0
	var armor_val: float = 0.0

	if player.health_component != null:
		cur_hp = player.health_component.current_health
		max_hp = player.health_component.max_health
		cur_shield = player.health_component.current_shield
		max_shield = player.health_component.max_shield
		shield_rate = player.health_component.shield_recharge_rate
		shield_delay = player.health_component.shield_recharge_delay
		armor_val = player.health_component.armor
	elif player.stats_manager != null:
		cur_hp = player.stats_manager.current_health
		max_hp = player.stats_manager.get_max_health()

	if health_val_label != null:
		health_val_label.text = "%.0f / %.0f HP" % [cur_hp, max_hp]
	if shield_val_label != null:
		if max_shield > 0.0:
			shield_val_label.text = "%.0f / %.0f (Regen: +%.0f/s | Retardo: %.1fs)" % [cur_shield, max_shield, shield_rate, shield_delay]
		else:
			shield_val_label.text = "0 / 0 (Sin Escudo)"
	if armor_val_label != null:
		armor_val_label.text = "%.0f Armadura" % armor_val
	if mitigation_val_label != null:
		mitigation_val_label.text = "-%d de daño por golpe (mínimo 1)" % roundi(armor_val)

	# 2. Movilidad
	var move_spd: float = player.get_current_move_speed() if player.has_method("get_current_move_speed") else 240.0
	var max_jumps: int = player.stats_manager.get_max_jumps() if player.stats_manager != null else 1

	var states: Array[String] = []
	if player.can_wall_jump:
		states.append("Wall-Jump")
	if player.has_jetpack:
		states.append("Jetpack")
	if player.has_wings:
		states.append("Alas (x%d)" % player.max_flaps)
	if player.has_magic_flight:
		states.append("Vuelo Mágico")
	if states.is_empty():
		states.append("Estándar (A pie)")

	if speed_val_label != null:
		speed_val_label.text = "%.0f px/s" % move_spd
	if jumps_val_label != null:
		jumps_val_label.text = "%d %s" % [max_jumps, "Salto" if max_jumps == 1 else "Saltos"]
	if mobility_states_label != null:
		mobility_states_label.text = ", ".join(states)

	# 3. Arma Activa
	var wm: WeaponManager = player.weapon_manager
	if wm != null and wm.current_weapon != null:
		var w: WeaponData = wm.current_weapon
		var eff_dmg: float = wm.get_current_effective_impact_damage()
		var fire_rate_val: float = wm.get_current_fire_rate()
		var sus_dps: float = wm.get_current_sustained_dps()
		var armor_pen_val: float = wm.get_current_armor_penetration_percentage()
		var infusions: Array[String] = w.get_elemental_infusions()

		var base_dmg: float = w.damage
		var rune_dmg: float = w.get_total_bonus_damage()
		var dmg_mult: float = 1.0
		var crit_prob: float = 0.15
		var crit_multiplier_val: float = w.crit_multiplier if w.crit_multiplier > 1.0 else 1.5

		if player.stats_manager != null:
			dmg_mult = player.stats_manager.get_damage_multiplier()
			crit_prob = player.stats_manager.get_crit_chance()
			crit_multiplier_val = player.stats_manager.get_crit_multiplier() * (crit_multiplier_val / 1.5)

		var total_shot_dmg: float = eff_dmg * float(maxi(1, w.pellets_per_shot))
		var crit_damage_val: float = total_shot_dmg * crit_multiplier_val

		if weapon_name_label != null:
			weapon_name_label.text = "%s (%s)" % [w.weapon_name, "MELEE" if w.weapon_type == WeaponData.WeaponType.MELEE else "A DISTANCIA"]
		if impact_dmg_label != null:
			if w.pellets_per_shot > 1:
				impact_dmg_label.text = "%.1f x %d perdigones (Total: %.1f)" % [eff_dmg, w.pellets_per_shot, total_shot_dmg]
			else:
				impact_dmg_label.text = "%.1f Daño Total" % eff_dmg
		if damage_breakdown_label != null:
			var bonus_parts: Array[String] = []
			if rune_dmg > 0.0:
				bonus_parts.append("+%.1f Runas" % rune_dmg)
			if not is_equal_approx(dmg_mult, 1.0):
				bonus_parts.append("x%.2f Mult" % dmg_mult)
			var bonus_str: String = " (%s)" % ", ".join(bonus_parts) if not bonus_parts.is_empty() else " (Puro base)"
			damage_breakdown_label.text = "Base: %.1f%s" % [base_dmg, bonus_str]
		if crit_val_label != null:
			crit_val_label.text = "%.0f%% Prob | x%.1f (Impacto Crítico: %d!)" % [
				crit_prob * 100.0,
				crit_multiplier_val,
				roundi(crit_damage_val)
			]
		if fire_rate_label != null:
			fire_rate_label.text = "%.1f disparos/s" % fire_rate_val
		if mag_reload_label != null:
			if w.magazine_size > 0 and w.weapon_type == WeaponData.WeaponType.RANGED:
				mag_reload_label.text = "%d balas (Recarga: %.1fs)" % [w.magazine_size, w.reload_time]
			else:
				mag_reload_label.text = "Continuo / Melee (Sin recarga)"
		if armor_pen_label != null:
			armor_pen_label.text = "%.0f%%" % armor_pen_val
		if infusions_label != null:
			infusions_label.text = ", ".join(infusions) if not infusions.is_empty() else "Ninguna (Físico Puro)"
		if sustained_dps_label != null:
			sustained_dps_label.text = "%.1f DPS" % sus_dps
	else:
		if weapon_name_label != null:
			weapon_name_label.text = "Desarmado"
		if impact_dmg_label != null:
			impact_dmg_label.text = "0.0"
		if damage_breakdown_label != null:
			damage_breakdown_label.text = "0.0"
		if crit_val_label != null:
			crit_val_label.text = "0%"
		if fire_rate_label != null:
			fire_rate_label.text = "0.0"
		if mag_reload_label != null:
			mag_reload_label.text = "N/A"
		if armor_pen_label != null:
			armor_pen_label.text = "0%"
		if infusions_label != null:
			infusions_label.text = "Ninguna"
		if sustained_dps_label != null:
			sustained_dps_label.text = "0.0 DPS"


## Nivel, experiencia y bonos: sale de StatsManager (los mismos números que usa el juego).
func _refresh_progression() -> void:
	var stats: StatsManager = player.stats_manager
	if stats == null or _char_rows.is_empty():
		return
	var sm: SaveManager = SaveManager.get_instance()
	var char_name: String = sm.character_name if sm != null and not sm.character_name.is_empty() else "Operador"
	var maxed: bool = stats.level >= StatsManager.MAX_LEVEL
	var cur: float = stats.current_exp
	var need: float = maxf(1.0, stats.exp_to_next_level)
	(_char_rows["name"] as Label).text = char_name
	(_char_rows["level"] as Label).text = "%d / %d%s" % [stats.level, StatsManager.MAX_LEVEL, "  (MÁXIMO)" if maxed else ""]
	if maxed:
		(_char_rows["exp"] as Label).text = "Nivel máximo alcanzado"
		(_char_rows["missing"] as Label).text = "—"
		_exp_bar.max_value = 1.0
		_exp_bar.value = 1.0
	else:
		(_char_rows["exp"] as Label).text = "%d / %d  (%d%%)" % [floori(cur), roundi(need), floori(cur / need * 100.0)]
		(_char_rows["missing"] as Label).text = "%d XP para el nivel %d" % [ceili(need - cur), stats.level + 1]
		_exp_bar.max_value = need
		_exp_bar.value = cur
	(_char_rows["total_exp"] as Label).text = "%d XP" % roundi(total_experience(stats.level, 0.0 if maxed else cur, need))
	var hp_step: float = StatsManager.HEALTH_PER_LEVEL
	var dmg_step: float = StatsManager.DAMAGE_PER_LEVEL * 100.0
	(_char_rows["next_bonus"] as Label).text = "—" if maxed else "+%d vida máx, +%d%% daño" % [roundi(hp_step), roundi(dmg_step)]
	var steps: int = maxi(0, stats.level - 1)
	(_char_rows["level_bonus"] as Label).text = "+%d vida máx, +%d%% daño" % [roundi(hp_step * float(steps)), roundi(dmg_step * float(steps))]
	(_char_rows["max_health"] as Label).text = "%d" % roundi(stats.get_max_health())
	(_char_rows["damage_mult"] as Label).text = "x%.2f" % stats.get_damage_multiplier()
	(_char_rows["crit"] as Label).text = "%d%% / x%.2f" % [roundi(stats.get_crit_chance() * 100.0), stats.get_crit_multiplier()]
	(_char_rows["coins"] as Label).text = "%d" % stats.coins
	(_char_rows["crystals"] as Label).text = "%d" % stats.time_crystals


func _refresh_metrics_sheet() -> void:
	var mm: MetricsManager = MetricsManager.get_instance()
	if mm == null:
		return
	
	if time_played_label != null:
		time_played_label.text = mm.get_formatted_time_played()
	if total_kills_label != null:
		total_kills_label.text = "%d bajas" % mm.total_enemies_killed
	
	var k_runners: int = mm.kills_by_type.get("BasicRunner", 0)
	var k_brutes: int = mm.kills_by_type.get("ArmoredBrute", 0)
	var k_sentinels: int = mm.kills_by_type.get("ShieldedSentinel", 0)
	var k_turrets: int = mm.kills_by_type.get("SniperTurret", 0)
	
	if kills_runners_label != null:
		kills_runners_label.text = "%d" % k_runners
	if kills_brutes_label != null:
		kills_brutes_label.text = "%d" % k_brutes
	if kills_sentinels_label != null:
		kills_sentinels_label.text = "%d" % k_sentinels
	if kills_turrets_label != null:
		kills_turrets_label.text = "%d" % k_turrets
	
	if coins_economy_label != null:
		coins_economy_label.text = "Obtenido: %d  |  Gastado: %d" % [mm.total_coins_collected, mm.total_coins_spent]
	if player_deaths_label != null:
		player_deaths_label.text = "%d" % mm.total_player_deaths
	if contracts_completed_label != null:
		contracts_completed_label.text = "%d" % mm.contracts_completed
	_refresh_history_extras(mm)


## Promedios de carrera y bajas de cada tipo de enemigo (de más a menos).
func _refresh_history_extras(mm: MetricsManager) -> void:
	if _hist_rows.is_empty():
		return
	var hours: float = mm.time_played_seconds / 3600.0
	(_hist_rows["kills_hour"] as Label).text = "%d" % roundi(float(mm.total_enemies_killed) / hours) if hours > 0.01 else "—"
	(_hist_rows["kd"] as Label).text = "%.1f" % (float(mm.total_enemies_killed) / float(maxi(1, mm.total_player_deaths)))
	(_hist_rows["coins_kill"] as Label).text = "%.1f" % (float(mm.total_coins_collected) / float(maxi(1, mm.total_enemies_killed)))
	(_hist_rows["net_coins"] as Label).text = "%d" % (mm.total_coins_collected - mm.total_coins_spent)

	var types: Array = []
	for key: String in mm.kills_by_type.keys():
		if int(mm.kills_by_type[key]) > 0:
			types.append(key)
	types.sort_custom(func(a: String, b: String) -> bool: return int(mm.kills_by_type[a]) > int(mm.kills_by_type[b]))
	for key: String in types:
		if not _kills_rows.has(key):
			_kills_rows[key] = _add_row(_kills_grid, "%s:" % key)
	for key: String in _kills_rows.keys():
		(_kills_rows[key] as Label).text = "%d" % int(mm.kills_by_type.get(key, 0))
