class_name ZoneContract
extends Resource
## Recurso de datos que define un Contrato de Riesgo de Zona (Zone Contract).
## Modifica parámetros del jugador (ej: gravedad, velocidad) y del mundo
## (ej: multiplicador de drops de monedas, velocidad de enemigos).

@export var contract_id: String = ""
@export var contract_title: String = ""
@export_multiline var description: String = ""
@export var player_modifiers: Dictionary = {}
@export var world_modifiers: Dictionary = {}


func get_player_modifier(key: String, default_value: float = 1.0) -> float:
	return float(player_modifiers.get(key, default_value))


func get_world_modifier(key: String, default_value: float = 1.0) -> float:
	return float(world_modifiers.get(key, default_value))
