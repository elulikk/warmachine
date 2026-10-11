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

var player: Player = null
var _refresh_timer: float = 0.0


func _ready() -> void:
	super._ready()
	window_title = "ESTADÍSTICAS Y TELEMETRÍA [C]"
	visible = false
	add_to_group(&"stats_window")
	call_deferred("_initial_position")


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
	
	# 1. Supervivencia
	var cur_hp: float = 0.0
	var max_hp: float = 100.0
	var cur_shield: float = 0.0
	var max_shield: float = 0.0
	var shield_rate: float = 0.0
	var shield_delay: float = 0.0
	var armor_val: float = 0.0
	var mitigation_pct: float = 0.0

	if player.health_component != null:
		cur_hp = player.health_component.current_health
		max_hp = player.health_component.max_health
		cur_shield = player.health_component.current_shield
		max_shield = player.health_component.max_shield
		shield_rate = player.health_component.shield_recharge_rate
		shield_delay = player.health_component.shield_recharge_delay
		armor_val = player.health_component.armor
		mitigation_pct = player.health_component.get_mitigation_percentage()
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
		mitigation_val_label.text = "%.1f%% Reducción de Daño" % mitigation_pct

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
