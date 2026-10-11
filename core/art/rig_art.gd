extends RefCounted
## Piezas sueltas del esqueleto (mochilas, alas y granadas al cinturón). Tamaño en px de juego.
## Los PNG están exportados al doble de su tamaño (ver CharacterRig.TEX_SCALE para el esqueleto: los sueltos usan el mismo factor).
## Las armaduras, cuerpos base y manos están en `armor_art.gd` (generado desde las hojas de sets).

const PARTS: Dictionary = {
	"back_jetpack": {"file": "res://assets/art/rig/back_jetpack.png", "size": Vector2(26.0, 31.0)},
	"back_pack_boiler": {"file": "res://assets/art/rig/back_pack_boiler.png", "size": Vector2(28.0, 35.0)},
	"back_pack_copper": {"file": "res://assets/art/rig/back_pack_copper.png", "size": Vector2(26.0, 33.5)},
	"back_pack_leather": {"file": "res://assets/art/rig/back_pack_leather.png", "size": Vector2(30.0, 26.5)},
	"back_pack_satchel": {"file": "res://assets/art/rig/back_pack_satchel.png", "size": Vector2(28.0, 27.5)},
	"back_wing_l": {"file": "res://assets/art/rig/back_wing_l.png", "size": Vector2(30.0, 36.0)},
	"back_wing_r": {"file": "res://assets/art/rig/back_wing_r.png", "size": Vector2(30.0, 36.5)},
	"belt_grenade_frag": {"file": "res://assets/art/rig/belt_grenade_frag.png", "size": Vector2(8.5, 11.0)},
	"belt_grenade_cryo": {"file": "res://assets/art/rig/belt_grenade_cryo.png", "size": Vector2(8.0, 11.0)},
	"belt_grenade_acid": {"file": "res://assets/art/rig/belt_grenade_acid.png", "size": Vector2(8.5, 11.0)},
	"belt_gas_bomb": {"file": "res://assets/art/rig/belt_gas_bomb.png", "size": Vector2(8.5, 11.0)}
}
