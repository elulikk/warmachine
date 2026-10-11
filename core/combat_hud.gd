class_name CombatHUD
extends CanvasLayer
## Interfaz de combate (HUD) anclada a la esquina superior izquierda.
## Muestra barra de vida, barra de experiencia delgada, indicador de nivel
## y el arma actualmente equipada en tiempo real.

@onready var level_label: Label = %LevelLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var exp_bar: ProgressBar = %ExpBar
@onready var exp_label: Label = %ExpLabel
@onready var coins_label: Label = %CoinsLabel


func _ready() -> void:
	# Intentar enlazar de inmediato con el Jugador de la escena
	_find_and_bind_player.call_deferred()


func _find_and_bind_player() -> void:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		setup_with_player(player)


## Enlaza las señales de StatsManager y WeaponManager del Jugador.
func setup_with_player(player: Player) -> void:
	if player == null:
		return
	
	if player.stats_manager != null:
		var stats: StatsManager = player.stats_manager
		if not stats.health_changed.is_connected(_on_health_changed):
			stats.health_changed.connect(_on_health_changed)
		if not stats.exp_changed.is_connected(_on_exp_changed):
			stats.exp_changed.connect(_on_exp_changed)
		if not stats.leveled_up.is_connected(_on_leveled_up):
			stats.leveled_up.connect(_on_leveled_up)
		if not stats.coins_changed.is_connected(_on_coins_changed):
			stats.coins_changed.connect(_on_coins_changed)
		
		# Sincronización inicial
		_on_health_changed(stats.current_health, stats.get_max_health())
		_on_exp_changed(stats.current_exp, stats.exp_to_next_level)
		_on_leveled_up(stats.level)
		_on_coins_changed(stats.coins)

	
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
	
	if player.health_component != null:
		var hc: HealthComponent = player.health_component
		if not hc.shield_changed.is_connected(_on_shield_changed):
			hc.shield_changed.connect(_on_shield_changed)
	
	if player.equipment_manager != null:
		var em: EquipmentManager = player.equipment_manager
		if not em.item_equipped.is_connected(_on_equipment_changed):
			em.item_equipped.connect(_on_equipment_changed)
		if not em.item_unequipped.is_connected(_on_equipment_changed):
			em.item_unequipped.connect(_on_equipment_changed)


func _on_equipment_changed(_slot: String, _item: ItemData) -> void:
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player_node != null and player_node.weapon_manager != null and player_node.weapon_manager.current_weapon != null:
		_on_weapon_changed(player_node.weapon_manager.current_weapon, player_node.weapon_manager.current_weapon_index)


func _on_health_changed(current: float, max_hp: float) -> void:
	if health_bar != null:
		health_bar.max_value = max_hp
		health_bar.value = current
	if health_label != null:
		var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
		var shield_str: String = ""
		if player_node != null and player_node.health_component != null and player_node.health_component.max_shield > 0.0:
			shield_str = " | Escudo: %d" % roundi(player_node.health_component.current_shield)
		health_label.text = "HP: %d / %d%s" % [roundi(current), roundi(max_hp), shield_str]


func _on_shield_changed(_cur_s: float, _max_s: float) -> void:
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player_node != null and player_node.stats_manager != null:
		_on_health_changed(player_node.stats_manager.current_health, player_node.stats_manager.get_max_health())


func _on_exp_changed(current: float, max_exp: float) -> void:
	if exp_bar != null:
		exp_bar.max_value = max_exp
		exp_bar.value = current
	if exp_label != null:
		exp_label.text = "EXP: %d / %d" % [roundi(current), roundi(max_exp)]


func _on_leveled_up(new_level: int) -> void:
	if level_label != null:
		level_label.text = "LVL %d" % new_level


var _hud_is_reloading: bool = false

func _on_ammo_changed(_cur: int, _max_mag: int) -> void:
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player_node != null and player_node.weapon_manager != null and player_node.weapon_manager.current_weapon != null:
		_on_weapon_changed(player_node.weapon_manager.current_weapon, player_node.weapon_manager.current_weapon_index)


func _on_reload_started(_dur: float) -> void:
	_hud_is_reloading = true
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player_node != null and player_node.weapon_manager != null and player_node.weapon_manager.current_weapon != null:
		_on_weapon_changed(player_node.weapon_manager.current_weapon, player_node.weapon_manager.current_weapon_index)


func _on_reload_completed() -> void:
	_hud_is_reloading = false
	var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player_node != null and player_node.weapon_manager != null and player_node.weapon_manager.current_weapon != null:
		_on_weapon_changed(player_node.weapon_manager.current_weapon, player_node.weapon_manager.current_weapon_index)


func _on_weapon_changed(weapon: WeaponData, _index: int = 0) -> void:
	if weapon_label != null and weapon != null:
		var infusion_text: String = ""
		var player_node: Player = get_tree().get_first_node_in_group(&"player") as Player
		if player_node != null and player_node.equipment_manager != null:
			var infusions: Array[String] = player_node.equipment_manager.get_attack_status_effects()
			if not infusions.is_empty():
				infusion_text = " [%s]" % "/".join(infusions)
		
		var ammo_text: String = ""
		if player_node != null and player_node.weapon_manager != null:
			if weapon.weapon_type == WeaponData.WeaponType.MELEE or weapon.magazine_size <= 0:
				ammo_text = " (∞)"
			elif _hud_is_reloading:
				ammo_text = " (Recargando...)"
			else:
				var cur_ammo: int = player_node.weapon_manager.get_weapon_ammo(weapon)
				ammo_text = " (%d / %d)" % [cur_ammo, weapon.magazine_size]
		
		weapon_label.text = "Arma: %s%s%s" % [weapon.weapon_name, ammo_text, infusion_text]


func _on_coins_changed(new_coins: int) -> void:
	if coins_label != null:
		coins_label.text = "Monedas: %d" % new_coins


