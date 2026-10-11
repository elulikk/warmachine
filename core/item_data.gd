class_name ItemData
extends Resource
## Recurso de datos que define un ítem recolectable o equipable y sus modificaciones de estadísticas.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export_group("Economía y Rareza")
@export var rarity: Rarity = Rarity.COMMON
@export var gold_value: int = 10
@export_multiline var description: String = ""

@export_group("Identificación")
@export var item_id: String = ""
@export var item_name: String = "Item"
@export var item_color: Color = Color(0.2, 0.9, 0.5, 1.0)

## Ranura de equipamiento a la que pertenece este ítem (o "NONE" si es consumible directo).
## "ACCESSORY" es una categoría: el ítem se equipa en ACCESSORY_1 o ACCESSORY_2, la primera libre.
@export_enum("NONE", "HEAD", "CHEST", "GLOVES", "BOOTS", "BACK", "ACCESSORY", "TACTICAL") var equip_slot: String = "NONE"

## Escena física arrojadiza instanciada por el ThrowableManager (solo ítems de ranura TACTICAL).
@export var throwable_scene: PackedScene = null

## Infusión elemental otorgada al equiparse (ej: "FIRE", "ICE").
@export var elemental_infusion: String = ""

## Etiquetas adicionales de comportamiento (ej: ["FIRE_INFUSION"]).
@export var tags: Array[String] = []

## Lista de diccionarios de modificación.
## Estructura esperada de cada entrada:
## {"stat": "move_speed", "is_percent": false, "value": 60.0}
@export var modifiers: Array[Dictionary] = []

## Saltos adicionales otorgados (ej: 1 habilita doble salto si base_max_jumps era 1).
@export var grants_extra_jump: int = 0



## Aplica todos los modificadores de este ítem sobre un StatsManager.
func apply_to_stats(stats: StatsManager) -> void:
	if stats == null:
		return
	
	for mod in modifiers:
		var stat_name: String = mod.get("stat", "")
		var is_pct: bool = mod.get("is_percent", false)
		var val: float = mod.get("value", 0.0)
		if not stat_name.is_empty() and val != 0.0:
			stats.add_modifier(stat_name, val, is_pct)
	
	if grants_extra_jump > 0:
		stats.add_modifier("max_jumps", float(grants_extra_jump), false)


## Retira todos los modificadores de este ítem de un StatsManager.
func remove_from_stats(stats: StatsManager) -> void:
	if stats == null:
		return
	
	for mod in modifiers:
		var stat_name: String = mod.get("stat", "")
		var is_pct: bool = mod.get("is_percent", false)
		var val: float = mod.get("value", 0.0)
		if not stat_name.is_empty() and val != 0.0:
			stats.remove_modifier(stat_name, val, is_pct)
	
	if grants_extra_jump > 0:
		stats.remove_modifier("max_jumps", float(grants_extra_jump), false)
