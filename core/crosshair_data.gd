extends RefCounted
## Datos de la mira de cada arma (la dibuja ui/aim_reticle.gd).
## - `style`: forma (cross, ring, brackets, tee, scope, diamond, chevrons, dot).
## - `min_r` / `max_r`: radio de la mira en píxeles con el arma lo más precisa y lo más imprecisa posible. El radio
##   nunca sale de ese rango, sea cual sea la dispersión del arma.
## - `ref_deg`: dispersión total (grados) con la que la mira llega a `max_r`. Más dispersión, mira más grande.
## - `arm`: largo de las marcas.
## Cada arma usa su entrada de `OVERRIDES` (por id de archivo, ver WeaponMotion.id_of) o, si no tiene, la de su familia.

const WeaponMotion = preload("res://core/art/weapon_motion.gd")

const STYLE_BY_FAMILY: Dictionary = {
	WeaponData.WeaponFamily.GENERIC: {"style": "diamond", "min_r": 6.0, "max_r": 26.0, "ref_deg": 20.0, "arm": 7.0},
	WeaponData.WeaponFamily.PISTOL: {"style": "cross", "min_r": 5.0, "max_r": 24.0, "ref_deg": 16.0, "arm": 8.0},
	WeaponData.WeaponFamily.REVOLVER: {"style": "cross", "min_r": 5.0, "max_r": 22.0, "ref_deg": 14.0, "arm": 9.0},
	WeaponData.WeaponFamily.CARBINE: {"style": "brackets", "min_r": 7.0, "max_r": 28.0, "ref_deg": 16.0, "arm": 7.0},
	WeaponData.WeaponFamily.SMG: {"style": "tee", "min_r": 8.0, "max_r": 32.0, "ref_deg": 16.0, "arm": 8.0},
	WeaponData.WeaponFamily.SHOTGUN: {"style": "ring", "min_r": 12.0, "max_r": 44.0, "ref_deg": 40.0, "arm": 6.0},
	WeaponData.WeaponFamily.RIFLE: {"style": "brackets", "min_r": 7.0, "max_r": 30.0, "ref_deg": 16.0, "arm": 8.0},
	WeaponData.WeaponFamily.SNIPER: {"style": "scope", "min_r": 4.0, "max_r": 20.0, "ref_deg": 12.0, "arm": 12.0},
	WeaponData.WeaponFamily.ENERGY: {"style": "diamond", "min_r": 7.0, "max_r": 28.0, "ref_deg": 18.0, "arm": 7.0},
	WeaponData.WeaponFamily.FLAMETHROWER: {"style": "ring", "min_r": 14.0, "max_r": 40.0, "ref_deg": 30.0, "arm": 6.0},
	WeaponData.WeaponFamily.SHORT_MELEE: {"style": "dot", "min_r": 6.0, "max_r": 6.0, "ref_deg": 1.0, "arm": 4.0},
	WeaponData.WeaponFamily.SWORD: {"style": "dot", "min_r": 7.0, "max_r": 7.0, "ref_deg": 1.0, "arm": 4.0},
	WeaponData.WeaponFamily.HEAVY_MELEE: {"style": "dot", "min_r": 9.0, "max_r": 9.0, "ref_deg": 1.0, "arm": 4.0},
}

## Armas con mira propia (id de archivo del .tres). Las que no figuran usan la de su familia.
const OVERRIDES: Dictionary = {
	"desert_eagle": {"style": "cross", "min_r": 6.0, "max_r": 26.0, "ref_deg": 14.0, "arm": 11.0},
	"colt_44": {"style": "cross", "min_r": 5.0, "max_r": 22.0, "ref_deg": 14.0, "arm": 9.0},
	"longbow": {"style": "chevrons", "min_r": 6.0, "max_r": 24.0, "ref_deg": 14.0, "arm": 8.0},
	"hell_crossbow": {"style": "chevrons", "min_r": 7.0, "max_r": 26.0, "ref_deg": 14.0, "arm": 9.0},
	"javelin": {"style": "chevrons", "min_r": 7.0, "max_r": 24.0, "ref_deg": 14.0, "arm": 9.0},
	"ak47": {"style": "brackets", "min_r": 9.0, "max_r": 34.0, "ref_deg": 16.0, "arm": 9.0},
	"mp5": {"style": "tee", "min_r": 8.0, "max_r": 30.0, "ref_deg": 14.0, "arm": 8.0},
}

## Mira cuando no hay arma en la mano.
const NO_WEAPON: Dictionary = {"style": "dot", "min_r": 6.0, "max_r": 6.0, "ref_deg": 1.0, "arm": 4.0}


static func for_weapon(weapon: WeaponData) -> Dictionary:
	if weapon == null:
		return NO_WEAPON
	var id: String = WeaponMotion.id_of(weapon)
	if OVERRIDES.has(id):
		return OVERRIDES[id] as Dictionary
	if weapon.grip == WeaponData.Grip.SHIELD:
		return NO_WEAPON
	return STYLE_BY_FAMILY.get(weapon.family, STYLE_BY_FAMILY[WeaponData.WeaponFamily.GENERIC]) as Dictionary


## Radio objetivo de la mira para el arma: crece con su dispersión (más la que sume la ráfaga) y queda entre `min_r` y `max_r`.
static func radius_for(data: Dictionary, spread_deg: float) -> float:
	var t: float = clampf(spread_deg / maxf(0.01, float(data["ref_deg"])), 0.0, 1.0)
	return lerpf(float(data["min_r"]), float(data["max_r"]), t)
