class_name ZoneModifierManager
extends Node
## Gestor de Mutadores de Zona (ZoneModifierManager).
## Almacena y administra el ZoneContract actualmente activo.
## Aplica mutadores al jugador a través de StatsManager y provee
## consultas rápidas de multiplicadores de mundo para drops y enemigos.

signal contract_applied(contract: ZoneContract)
signal contract_cleared

static var instance: ZoneModifierManager = null

var active_contract: ZoneContract = null

# Registro de modificadores aplicados a StatsManager para permitir restauración limpia
var _applied_stats_modifiers: Dictionary = {}


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	instance = self
	add_to_group(&"zone_modifier_manager")


static func get_instance() -> ZoneModifierManager:
	return instance


static func get_world_mult(key: String, default_value: float = 1.0) -> float:
	if instance != null:
		return instance.get_world_multiplier(key, default_value)
	return default_value


## Aplica un contrato de zona, notifica el cambio y actualiza modificadores en StatsManager.
func apply_contract(contract: ZoneContract) -> void:
	if active_contract != null:
		clear_contract()
	
	active_contract = contract
	
	if active_contract != null:
		_apply_player_modifiers_to_stats(active_contract)
		contract_applied.emit(active_contract)
		print("[ZoneModifierManager] Contrato aplicado: '%s'" % active_contract.contract_title)


## Restaura los valores base por defecto eliminando los mutadores del contrato.
func clear_contract() -> void:
	if active_contract == null and _applied_stats_modifiers.is_empty():
		return
	
	_revert_player_modifiers_from_stats()
	active_contract = null
	contract_cleared.emit()
	print("[ZoneModifierManager] Contrato finalizado. Valores restaurados a la normalidad.")


## Consulta rápida para drops de botín, velocidad de enemigos u otros mutadores de mundo.
func get_world_multiplier(key: String, default_value: float = 1.0) -> float:
	if active_contract != null:
		return active_contract.get_world_modifier(key, default_value)
	return default_value


## Consulta rápida para mutadores del jugador (ej: gravity_mult).
func get_player_multiplier(key: String, default_value: float = 1.0) -> float:
	if active_contract != null:
		return active_contract.get_player_modifier(key, default_value)
	return default_value


func _apply_player_modifiers_to_stats(contract: ZoneContract) -> void:
	var player: Player = _get_player()
	if player == null or player.stats_manager == null:
		return
	
	var stats: StatsManager = player.stats_manager
	for stat_key in contract.player_modifiers:
		var val: float = float(contract.player_modifiers[stat_key])
		match stat_key:
			"move_speed_mult":
				var delta_pct: float = val - 1.0
				stats.add_modifier("move_speed", delta_pct, true)
				_applied_stats_modifiers["move_speed"] = delta_pct
			"damage_mult", "damage_multiplier":
				var delta_pct: float = val - 1.0
				stats.add_modifier("damage_multiplier", delta_pct, true)
				_applied_stats_modifiers["damage_multiplier"] = delta_pct
			"max_health_mult":
				var delta_pct: float = val - 1.0
				stats.add_modifier("max_health", delta_pct, true)
				_applied_stats_modifiers["max_health"] = delta_pct


func _revert_player_modifiers_from_stats() -> void:
	var player: Player = _get_player()
	if player == null or player.stats_manager == null:
		_applied_stats_modifiers.clear()
		return
	
	var stats: StatsManager = player.stats_manager
	for stat_key in _applied_stats_modifiers:
		var delta_pct: float = float(_applied_stats_modifiers[stat_key])
		stats.remove_modifier(stat_key, delta_pct, true)
	
	_applied_stats_modifiers.clear()


func _get_player() -> Player:
	if is_inside_tree() and get_tree() != null:
		return get_tree().get_first_node_in_group(&"player") as Player
	return null
