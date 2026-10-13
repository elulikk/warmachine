class_name LootEntry
extends Resource
## Entrada individual dentro de una LootTable.
## Define el tipo de recurso que puede soltar, la probabilidad de éxito y la cantidad.

@export_enum("COIN", "AMMO", "HEALTH", "CRYSTAL") var item_type: String = "COIN"
@export_range(0.0, 1.0) var drop_chance: float = 1.0
@export var min_amount: int = 1
@export var max_amount: int = 1
