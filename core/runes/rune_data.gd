class_name RuneData
extends Resource
## Recurso modular de Runa acumulable para engarzar en sockets de armas.
## Provee modificadores balísticos (rebotes, perforación, bifurcación, daño y estados elementales).

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export_group("Economía y Rareza")
@export var rarity: Rarity = Rarity.COMMON
@export var gold_value: int = 35

@export_group("Identificación")
@export var rune_id: String = "rune_base"
@export var rune_name: String = "Runa"
@export var description: String = ""
@export var rune_color: Color = Color(0.85, 0.25, 1.0, 1.0) # Púrpura místico por defecto

@export_group("Compatibilidad")
@export var allowed_weapon_types: Array[WeaponData.WeaponType] = [
	WeaponData.WeaponType.RANGED,
	WeaponData.WeaponType.MELEE
]

@export_group("Modificadores Acumulables")
## Daño plano adicional transferido al arma.
@export var bonus_damage: float = 0.0

## Cantidad de rebotes contra paredes y terreno sólido.
@export var extra_bounces: int = 0

## Cantidad de enemigos que el proyectil puede atravesar antes de detenerse.
@export var extra_pierce: int = 0

## Cantidad de bifurcaciones: se divide en 2 proyectiles a +/-30° al impactar.
@export var extra_forks: int = 0

## Infusión elemental innata transferida al HitPayload (ej: "FIRE", "ICE").
@export var elemental_infusion: String = ""
