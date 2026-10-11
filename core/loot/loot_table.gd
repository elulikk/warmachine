class_name LootTable
extends Resource
## Tabla de recompensas y distribución probabilística de botín (Loot Drops).
## Evalúa las probabilidades de sus LootEntries y retorna la lista de recompensas generadas.
## Opcionalmente puede soltar una pieza de equipo (arma o armadura) con `gear_chance` y `gear_pool`.

## Pesos de elección por rareza (índice = rareza: COMMON, UNCOMMON, RARE, EPIC, LEGENDARY)
## según el tier de botín del nivel (`LevelBase.gear_loot_tier`). El último tier aplica a los siguientes.
const RARITY_WEIGHTS_BY_TIER: Array = [
	[70.0, 30.0, 0.0, 0.0, 0.0],
	[50.0, 35.0, 0.0, 15.0, 0.0],
	[30.0, 35.0, 0.0, 25.0, 10.0],
	[15.0, 30.0, 0.0, 35.0, 20.0]
]

## Probabilidad máxima de soltar equipo, sin importar el tier.
const MAX_GEAR_CHANCE: float = 0.5

@export var entries: Array[LootEntry] = []

@export_group("Equipo")
## Probabilidad base (0 a 1) de soltar una pieza de equipo en un nivel de tier 1.
## Crece 50% por cada tier de nivel adicional. 0 = esta tabla no suelta equipo.
@export_range(0.0, 1.0) var gear_chance: float = 0.0

## Piezas candidatas: recursos `ItemData` o `WeaponData`. La rareza de cada una decide su peso.
@export var gear_pool: Array[Resource] = []


## Evalúa el porcentaje de cada entrada y devuelve una lista de diccionarios con el tipo y la cantidad resultante.
func roll_drops() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for entry in entries:
		if entry == null:
			continue
		if randf() <= entry.drop_chance:
			var amount: int = randi_range(entry.min_amount, entry.max_amount)
			if amount > 0:
				results.append({
					"type": entry.item_type,
					"amount": amount
				})
	return results


## Tira el dado de equipo. Devuelve la pieza elegida o null si no cae nada.
## `level_tier` <= 0 apaga el botín de equipo. `is_excluded(res) -> bool` descarta candidatos
## (por ejemplo, lo que el jugador ya posee).
func roll_gear(level_tier: int, is_excluded: Callable = Callable()) -> Resource:
	if level_tier <= 0 or gear_chance <= 0.0 or gear_pool.is_empty():
		return null

	var chance: float = minf(gear_chance * (1.0 + 0.5 * float(level_tier - 1)), MAX_GEAR_CHANCE)
	if randf() > chance:
		return null

	var weights_row: Array = RARITY_WEIGHTS_BY_TIER[mini(level_tier, RARITY_WEIGHTS_BY_TIER.size()) - 1] as Array
	var candidates: Array[Resource] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for res in gear_pool:
		if res == null:
			continue
		if is_excluded.is_valid() and bool(is_excluded.call(res)):
			continue
		var weight: float = float(weights_row[clampi(_rarity_of(res), 0, weights_row.size() - 1)])
		if weight <= 0.0:
			continue
		candidates.append(res)
		weights.append(weight)
		total += weight

	if candidates.is_empty() or total <= 0.0:
		return null

	var pick: float = randf() * total
	for i in range(candidates.size()):
		pick -= weights[i]
		if pick <= 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]


## Índice de rareza (0 = Normal ... 4 = Legendario) de un ItemData o WeaponData.
static func _rarity_of(res: Resource) -> int:
	var item: ItemData = res as ItemData
	if item != null:
		return int(item.rarity)
	var weapon: WeaponData = res as WeaponData
	if weapon != null:
		return int(weapon.rarity)
	return 0
