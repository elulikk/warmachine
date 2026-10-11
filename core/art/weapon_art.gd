extends RefCounted
## GENERADO a partir de las hojas de arte (assets/art). Datos de las armas en mano.
## Sin class_name: se carga por preload desde ItemIcons / CharacterRig.
##
## Todas las coordenadas estan en pixeles de la textura. `scale` ya incluye la division por
## WeaponManager.WEAPON_SCALE (1.5), que el WeaponManager vuelve a multiplicar.
## grip = punto del arma que queda sobre el eje del pivote (eje del canon), tip_x = boca del canon,
## hand = donde cierra la mano de agarre, support = donde apoya la mano de apoyo (si es de dos manos).

const WEAPONS: Dictionary = {
	"combat_knife": {"file": "res://assets/art/weapons/combat_knife.png", "size": Vector2(256, 83), "grip": Vector2(28.2, 45.7), "tip_x": 255.0, "hand": Vector2(28.2, 45.7), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.13021, "rot_deg": 0.0, "melee": true},
	"iron_sword": {"file": "res://assets/art/weapons/iron_sword.png", "size": Vector2(256, 84), "grip": Vector2(25.6, 48.7), "tip_x": 255.0, "hand": Vector2(25.6, 48.7), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.16146, "rot_deg": 0.0, "melee": true},
	"katana": {"file": "res://assets/art/weapons/katana.png", "size": Vector2(256, 58), "grip": Vector2(30.7, 26.1), "tip_x": 255.0, "hand": Vector2(30.7, 26.1), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.18229, "rot_deg": 0.0, "melee": true},
	"heavy_hammer": {"file": "res://assets/art/weapons/heavy_hammer.png", "size": Vector2(256, 121), "grip": Vector2(38.4, 60.5), "tip_x": 255.0, "hand": Vector2(38.4, 60.5), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.16146, "rot_deg": 0.0, "melee": true},
	"rust_revolver": {"file": "res://assets/art/weapons/rust_revolver.png", "size": Vector2(256, 132), "grip": Vector2(38.4, 16.0), "tip_x": 255.0, "hand": Vector2(38.4, 72.6), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.08854, "rot_deg": 0.0, "melee": false},
	"pistol_9mm": {"file": "res://assets/art/weapons/pistol_9mm.png", "size": Vector2(256, 201), "grip": Vector2(43.5, 58.5), "tip_x": 255.0, "hand": Vector2(43.5, 124.6), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.08333, "rot_deg": 0.0, "melee": false},
	"scrap_carbine": {"file": "res://assets/art/weapons/scrap_carbine.png", "size": Vector2(256, 75), "grip": Vector2(74.2, 26.5), "tip_x": 255.0, "hand": Vector2(74.2, 42.0), "support": Vector2(158.7, 28.5), "two_hand": true, "scale": 0.18750, "rot_deg": 0.0, "melee": false},
	"colt_44": {"file": "res://assets/art/weapons/colt_44.png", "size": Vector2(256, 122), "grip": Vector2(30.7, 17.5), "tip_x": 255.0, "hand": Vector2(30.7, 75.6), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.10417, "rot_deg": 0.0, "melee": false},
	"mp5": {"file": "res://assets/art/weapons/mp5.png", "size": Vector2(256, 140), "grip": Vector2(97.3, 52.5), "tip_x": 255.0, "hand": Vector2(97.3, 86.8), "support": Vector2(176.6, 56.0), "two_hand": true, "scale": 0.14583, "rot_deg": 0.0, "melee": false},
	"revolver": {"file": "res://assets/art/weapons/revolver.png", "size": Vector2(256, 136), "grip": Vector2(35.8, 15.5), "tip_x": 255.0, "hand": Vector2(35.8, 87.0), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.09896, "rot_deg": 0.0, "melee": false},
	"shotgun": {"file": "res://assets/art/weapons/shotgun.png", "size": Vector2(256, 92), "grip": Vector2(61.4, 33.0), "tip_x": 255.0, "hand": Vector2(61.4, 54.3), "support": Vector2(161.3, 50.6), "two_hand": true, "scale": 0.18229, "rot_deg": 0.0, "melee": false},
	"pistol": {"file": "res://assets/art/weapons/pistol.png", "size": Vector2(256, 136), "grip": Vector2(41.0, 45.5), "tip_x": 255.0, "hand": Vector2(41.0, 97.9), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.09896, "rot_deg": 0.0, "melee": false},
	"corrosive_blaster": {"file": "res://assets/art/weapons/corrosive_blaster.png", "size": Vector2(256, 164), "grip": Vector2(38.4, 47.5), "tip_x": 255.0, "hand": Vector2(38.4, 108.2), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.09896, "rot_deg": 0.0, "melee": false},
	"smg": {"file": "res://assets/art/weapons/smg.png", "size": Vector2(256, 161), "grip": Vector2(46.1, 33.0), "tip_x": 255.0, "hand": Vector2(46.1, 96.6), "support": Vector2(133.1, 125.6), "two_hand": true, "scale": 0.11458, "rot_deg": 0.0, "melee": false},
	"ak47": {"file": "res://assets/art/weapons/ak47.png", "size": Vector2(256, 89), "grip": Vector2(97.3, 16.5), "tip_x": 255.0, "hand": Vector2(97.3, 62.3), "support": Vector2(148.5, 35.6), "two_hand": true, "scale": 0.17188, "rot_deg": 0.0, "melee": false},
	"m4": {"file": "res://assets/art/weapons/m4.png", "size": Vector2(256, 94), "grip": Vector2(76.8, 29.0), "tip_x": 255.0, "hand": Vector2(76.8, 59.2), "support": Vector2(163.8, 47.0), "two_hand": true, "scale": 0.17708, "rot_deg": 0.0, "melee": false},
	"desert_eagle": {"file": "res://assets/art/weapons/desert_eagle.png", "size": Vector2(256, 151), "grip": Vector2(51.2, 31.5), "tip_x": 255.0, "hand": Vector2(51.2, 108.7), "support": Vector2(-1.0, -1.0), "two_hand": false, "scale": 0.10417, "rot_deg": 0.0, "melee": false},
	"heavy_sniper": {"file": "res://assets/art/weapons/heavy_sniper.png", "size": Vector2(256, 64), "grip": Vector2(105.0, 20.5), "tip_x": 255.0, "hand": Vector2(105.0, 43.5), "support": Vector2(158.7, 35.2), "two_hand": true, "scale": 0.22917, "rot_deg": 0.0, "melee": false},
	"plasma_flamethrower": {"file": "res://assets/art/weapons/plasma_flamethrower.png", "size": Vector2(256, 108), "grip": Vector2(41.0, 65.0), "tip_x": 255.0, "hand": Vector2(41.0, 79.9), "support": Vector2(133.1, 86.4), "two_hand": true, "scale": 0.17188, "rot_deg": 0.0, "melee": false}
}
