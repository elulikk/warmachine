extends RefCounted
## Agarre y animación propios de cada arma en mano. Se edita a mano (a diferencia de `weapon_art.gd`, que es generado).
## Sin class_name: se carga por preload desde WeaponManager y CharacterRig.
##
## Las claves de PROFILES son el nombre del recurso del arma (`data/weapons/<id>.tres`, igual que `weapon_art.gd`).
## Un arma sin perfil conserva la animación genérica (tajo en arco / retroceso por `recoil_force`).
##
## Perfil:
##   pose    pisa datos de agarre de `weapon_art.gd` (`hand`, `support`) en px de la textura. Cuántas manos ocupa
##           el arma no va acá: sale de `WeaponData.grip` (ver `ItemIcons.get_weapon_pose`).
##   hold    pose de reposo del arma en mano. `pos` en px de juego (espacio del pivote), `rot_deg` en grados.
##           En armas de fuego solo cuenta `pos.x`: adelanta el arma y estira el brazo (pistolas a una mano).
##   swings  solo melee: lista de tajos que se alternan en orden (combo). Cada uno:
##             length     duración total de la animación = swing_duration * length (incluye la vuelta al reposo)
##             hit_delay  s hasta que el golpe es efectivo (hitbox, dash, onda); la animación arranca de inmediato
##             keys       fotogramas {t: 0..1 de la animación, pos: px desde el reposo, rot: grados desde el reposo,
##                        ease: "out" | "in" | "inout"}; el último debería volver a pos (0,0) y rot 0
##             body       fotogramas del cuerpo {t, lean (grados, + = hacia adelante), x (px, + = adelante)}
##   scale   multiplica el tamaño del arma en mano (1.0 = el de `weapon_art.gd`)
##   kick    solo armas de fuego: {back (px), climb_deg, time (s), body (factor de retroceso del torso)}
##
## Convenciones: el arma apunta a +x en el espacio del pivote; rotación positiva = la punta baja (sentido horario);
## el pivote ya espeja el eje Y al apuntar a la izquierda, así que los datos valen para los dos lados.

const PROFILES: Dictionary = {
	"combat_knife": {
		"scale": 0.72,
		"hold": {"pos": Vector2(1.0, 3.0), "rot_deg": -14.0},
		"swings": [
			{ # Tajo diagonal rápido
				"length": 2.6, "hit_delay": 0.0,
				"keys": [
					{"t": 0.0, "pos": Vector2(-5.0, -4.0), "rot": -45.0},
					{"t": 0.32, "pos": Vector2(9.0, 3.0), "rot": 38.0, "ease": "out"},
					{"t": 0.55, "pos": Vector2(10.0, 4.0), "rot": 42.0},
					{"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0, "ease": "inout"}
				],
				"body": [{"t": 0.0, "lean": -2.0, "x": -1.0}, {"t": 0.32, "lean": 5.0, "x": 2.5}, {"t": 1.0, "lean": 0.0, "x": 0.0}]
			},
			{ # Estocada
				"length": 2.6, "hit_delay": 0.0,
				"keys": [
					{"t": 0.0, "pos": Vector2(-8.0, 1.0), "rot": -6.0},
					{"t": 0.3, "pos": Vector2(17.0, 0.0), "rot": 0.0, "ease": "out"},
					{"t": 0.55, "pos": Vector2(17.0, 0.0), "rot": 0.0},
					{"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0, "ease": "inout"}
				],
				"body": [{"t": 0.0, "lean": -4.0, "x": -2.0}, {"t": 0.3, "lean": 7.0, "x": 4.0}, {"t": 1.0, "lean": 0.0, "x": 0.0}]
			}
		]
	},
	"iron_sword": {
		"pose": {"support": Vector2(14.0, 48.7)},
		"hold": {"pos": Vector2(0.0, 1.0), "rot_deg": -8.0},
		"swings": [
			{ # Tajo amplio descendente con cuerpo y brazos acompañando
				"length": 2.4, "hit_delay": 0.02,
				"keys": [
					{"t": 0.0, "pos": Vector2(-8.0, -6.0), "rot": -72.0},
					{"t": 0.36, "pos": Vector2(13.0, 5.0), "rot": 68.0, "ease": "out"},
					{"t": 0.52, "pos": Vector2(14.0, 6.0), "rot": 78.0},
					{"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0, "ease": "inout"}
				],
				"body": [
					{"t": 0.0, "lean": -7.0, "x": -2.5},
					{"t": 0.36, "lean": 12.0, "x": 5.0},
					{"t": 0.58, "lean": 6.0, "x": 2.0},
					{"t": 1.0, "lean": 0.0, "x": 0.0}
				]
			},
			{ # Tajo amplio de revés con giro del torso
				"length": 2.4, "hit_delay": 0.02,
				"keys": [
					{"t": 0.0, "pos": Vector2(-6.0, 7.0), "rot": 68.0},
					{"t": 0.36, "pos": Vector2(13.0, -5.0), "rot": -68.0, "ease": "out"},
					{"t": 0.52, "pos": Vector2(14.0, -6.0), "rot": -78.0},
					{"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0, "ease": "inout"}
				],
				"body": [
					{"t": 0.0, "lean": 6.0, "x": -2.0},
					{"t": 0.36, "lean": -10.0, "x": 4.5},
					{"t": 0.58, "lean": -5.0, "x": 1.8},
					{"t": 1.0, "lean": 0.0, "x": 0.0}
				]
			}
		]
	},
	"katana": {
		"pose": {"support": Vector2(16.0, 26.1)},
		"hold": {"pos": Vector2(0.0, 2.0), "rot_deg": -16.0},
		"swings": [
			{ # Tajo descendente desde arriba y atrás, con la embestida
				"length": 3.2, "hit_delay": 0.0,
				"keys": [
					{"t": 0.0, "pos": Vector2(-8.0, -5.0), "rot": -75.0},
					{"t": 0.26, "pos": Vector2(11.0, 3.0), "rot": 62.0, "ease": "out"},
					{"t": 0.45, "pos": Vector2(13.0, 6.0), "rot": 88.0},
					{"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0, "ease": "inout"}
				],
				"body": [{"t": 0.0, "lean": -5.0, "x": -2.0}, {"t": 0.26, "lean": 11.0, "x": 5.0}, {"t": 1.0, "lean": 0.0, "x": 0.0}]
			},
			{ # Tajo ascendente de vuelta
				"length": 3.2, "hit_delay": 0.0,
				"keys": [
					{"t": 0.0, "pos": Vector2(-4.0, 7.0), "rot": 62.0},
					{"t": 0.26, "pos": Vector2(11.0, -5.0), "rot": -66.0, "ease": "out"},
					{"t": 0.45, "pos": Vector2(13.0, -7.0), "rot": -88.0},
					{"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0, "ease": "inout"}
				],
				"body": [{"t": 0.0, "lean": 3.0, "x": -1.0}, {"t": 0.26, "lean": 9.0, "x": 5.0}, {"t": 1.0, "lean": 0.0, "x": 0.0}]
			}
		]
	},
	"heavy_hammer": {
		"pose": {"support": Vector2(108.0, 60.5)},
		"hold": {"pos": Vector2(-2.0, -1.0), "rot_deg": -22.0},
		"swings": [
			{ # Se alza sobre el hombro y cae con todo el cuerpo; el golpe llega con el impacto
				"length": 2.8, "hit_delay": 0.22,
				"keys": [
					{"t": 0.0, "pos": Vector2.ZERO, "rot": 0.0},
					{"t": 0.30, "pos": Vector2(-10.0, -12.0), "rot": -118.0, "ease": "inout"},
					{"t": 0.36, "pos": Vector2(-10.0, -12.0), "rot": -118.0},
					{"t": 0.46, "pos": Vector2(9.0, 9.0), "rot": 52.0, "ease": "in"},
					{"t": 0.60, "pos": Vector2(9.0, 9.0), "rot": 52.0},
					{"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0, "ease": "inout"}
				],
				"body": [
					{"t": 0.0, "lean": 0.0, "x": 0.0}, {"t": 0.30, "lean": -9.0, "x": -3.0},
					{"t": 0.46, "lean": 14.0, "x": 6.0}, {"t": 0.62, "lean": 12.0, "x": 5.0}, {"t": 1.0, "lean": 0.0, "x": 0.0}
				]
			}
		]
	},
	# --- Armas de fuego: retroceso propio ---
	"pistol": {"hold": {"pos": Vector2(7.0, 0.0), "rot_deg": 0.0}, "kick": {"back": 2.0, "climb_deg": 8.0, "time": 0.14, "body": 0.5}},
	"lava_pistol": {"hold": {"pos": Vector2(7.0, 0.0), "rot_deg": 0.0}, "kick": {"back": 2.0, "climb_deg": 8.0, "time": 0.14, "body": 0.5}},
	"pistol_9mm": {"hold": {"pos": Vector2(7.0, 0.0), "rot_deg": 0.0}, "kick": {"back": 2.0, "climb_deg": 7.0, "time": 0.13, "body": 0.5}},
	"desert_eagle": {"hold": {"pos": Vector2(7.0, 0.0), "rot_deg": 0.0}, "kick": {"back": 3.2, "climb_deg": 12.0, "time": 0.2, "body": 0.9}},
	"revolver": {"hold": {"pos": Vector2(7.0, 0.0), "rot_deg": 0.0}, "kick": {"back": 2.6, "climb_deg": 10.0, "time": 0.18, "body": 0.7}},
	"colt_44": {"hold": {"pos": Vector2(7.0, 0.0), "rot_deg": 0.0}, "kick": {"back": 2.6, "climb_deg": 10.0, "time": 0.18, "body": 0.7}},
	"rust_revolver": {"hold": {"pos": Vector2(7.0, 0.0), "rot_deg": 0.0}, "kick": {"back": 2.4, "climb_deg": 9.0, "time": 0.18, "body": 0.7}},
	"smg": {"kick": {"back": 1.6, "climb_deg": 2.5, "time": 0.07, "body": 0.35}},
	"mp5": {"kick": {"back": 1.6, "climb_deg": 2.5, "time": 0.07, "body": 0.35}},
	"ak47": {"kick": {"back": 2.6, "climb_deg": 3.5, "time": 0.1, "body": 0.8}},
	"m4": {"kick": {"back": 2.2, "climb_deg": 3.0, "time": 0.09, "body": 0.7}},
	"scrap_carbine": {"kick": {"back": 2.4, "climb_deg": 4.0, "time": 0.11, "body": 0.8}},
	"shotgun": {"kick": {"back": 5.0, "climb_deg": 9.0, "time": 0.24, "body": 1.7}},
	"heavy_sniper": {"kick": {"back": 6.0, "climb_deg": 6.0, "time": 0.36, "body": 2.0}},
	"plasma_flamethrower": {"kick": {"back": 0.6, "climb_deg": 0.0, "time": 0.06, "body": 0.15}},
	"fuel_flamethrower": {"kick": {"back": 0.6, "climb_deg": 0.0, "time": 0.06, "body": 0.15}},
	"corrosive_blaster": {"kick": {"back": 1.2, "climb_deg": 2.0, "time": 0.1, "body": 0.3}}
}


## Recarga propia por arma (en mano). Estilos:
##   mag        cargador: baja el cañón, saca y mete el cargador (genérico, armas sin entrada usan este)
##   mag_rifle  cargador + tirón de la manija de carga al final (fusiles y carabina)
##   cylinder   revólver: levanta el cañón, abre el tambor, mete `count` balas de a una y lo cierra de un golpe
##   shells     escopeta: inclinada, mete `count` cartuchos de a uno y bombea al final
##   bolt       cerrojo: cargador y luego cerrojo atrás y adelante (francotirador)
##   canister   bidón: baja mucho, desenrosca el depósito con un siseo y lo vuelve a poner (armas de energía)
## `count` 0 = según el cargador (máximo 6). La animación siempre dura `reload_time`.
const RELOADS: Dictionary = {
	"rust_revolver": {"style": "cylinder"},
	"revolver": {"style": "cylinder"},
	"colt_44": {"style": "cylinder"},
	"shotgun": {"style": "shells", "count": 4},
	"heavy_sniper": {"style": "bolt"},
	"ak47": {"style": "mag_rifle"},
	"m4": {"style": "mag_rifle"},
	"scrap_carbine": {"style": "mag_rifle"},
	"mp5": {"style": "mag_rifle"},
	"plasma_flamethrower": {"style": "canister"},
	"fuel_flamethrower": {"style": "canister"},
	"corrosive_blaster": {"style": "canister"},
}

## Secuencia de disparo sostenido de las automáticas (combo de retroceso): cada disparo dentro de `window` s
## del anterior sube el cañón `climb_step` grados más (hasta `max_climb`) y alterna un vaivén de `sway` grados.
## Al dejar de disparar vuelve al reposo en `recover` s. Es solo visual: no cambia la dispersión.
const PATTERNS: Dictionary = {
	"smg": {"window": 0.16, "climb_step": 0.9, "max_climb": 7.0, "sway": 1.4, "recover": 0.22},
	"mp5": {"window": 0.17, "climb_step": 0.8, "max_climb": 6.0, "sway": 1.2, "recover": 0.22},
	"ak47": {"window": 0.2, "climb_step": 1.6, "max_climb": 11.0, "sway": 2.2, "recover": 0.3},
	"m4": {"window": 0.19, "climb_step": 1.1, "max_climb": 8.0, "sway": 1.0, "recover": 0.26},
	"plasma_flamethrower": {"window": 0.12, "climb_step": 0.3, "max_climb": 3.0, "sway": 2.6, "recover": 0.2},
	"fuel_flamethrower": {"window": 0.12, "climb_step": 0.3, "max_climb": 3.0, "sway": 2.6, "recover": 0.2},
}


## Identificador del arma (nombre del recurso), igual que en `weapon_art.gd`.
static func id_of(weapon: WeaponData) -> String:
	if weapon == null:
		return ""
	var path: String = weapon.source_resource_path if not weapon.source_resource_path.is_empty() else weapon.resource_path
	return path.get_file().get_basename()


## Perfil del arma o un diccionario vacío.
static func profile_for(weapon: WeaponData) -> Dictionary:
	return PROFILES.get(id_of(weapon), {}) as Dictionary


## Muestrea una lista de fotogramas {t, <field>} por interpolación lineal. `u` en 0..1.
static func sample(keys: Array, u: float, field: String) -> float:
	if keys.is_empty():
		return 0.0
	var prev: Dictionary = keys[0] as Dictionary
	if u <= float(prev.get("t", 0.0)):
		return float(prev.get(field, 0.0))
	for i in range(1, keys.size()):
		var nxt: Dictionary = keys[i] as Dictionary
		var t1: float = float(nxt.get("t", 1.0))
		if u <= t1:
			var t0: float = float(prev.get("t", 0.0))
			var f: float = 0.0 if t1 <= t0 else (u - t0) / (t1 - t0)
			return lerpf(float(prev.get(field, 0.0)), float(nxt.get(field, 0.0)), f)
		prev = nxt
	return float(prev.get(field, 0.0))


## Patrón de disparo sostenido del arma (vacío si no tiene).
static func pattern_for(weapon: WeaponData) -> Dictionary:
	return PATTERNS.get(id_of(weapon), {}) as Dictionary


## Fotogramas de recarga del arma: lista de {t: 0..1, pos: px desde el reposo, rot: grados desde el reposo
## (+ = baja la punta), sound: StringName opcional que suena al llegar al fotograma}. El último vuelve a (0, 0).
static func reload_keys(weapon: WeaponData) -> Array:
	var entry: Dictionary = RELOADS.get(id_of(weapon), {}) as Dictionary
	var style: String = str(entry.get("style", "mag"))
	var count: int = int(entry.get("count", 0))
	if count <= 0:
		count = clampi(weapon.magazine_size if weapon != null else 6, 1, 6)
	match style:
		"cylinder":
			return _cylinder_keys(count)
		"shells":
			return _shell_keys(count)
		"bolt":
			return _mag_keys(true, "bolt")
		"mag_rifle":
			return _mag_keys(true, "handle")
		"canister":
			return _canister_keys()
	return _mag_keys(false, "")


static func _mag_keys(with_action: bool, action: String) -> Array:
	var keys: Array = [
		{"t": 0.0, "pos": Vector2.ZERO, "rot": 0.0},
		{"t": 0.1, "pos": Vector2(-2.0, 3.0), "rot": 32.0},
		{"t": 0.42, "pos": Vector2(-3.0, 6.0), "rot": 34.0},            # cargador afuera
		{"t": 0.62, "pos": Vector2(-2.0, 3.0), "rot": 30.0, "sound": &"reload_in"},  # cargador adentro
	]
	if with_action:
		var back: Vector2 = Vector2(-5.0, 1.0) if action == "bolt" else Vector2(-4.0, 2.0)
		keys.append({"t": 0.74, "pos": Vector2(-1.0, 1.0), "rot": 10.0 if action == "bolt" else 16.0})
		keys.append({"t": 0.84, "pos": back, "rot": 6.0 if action == "bolt" else 14.0, "sound": &"reload_rack"})
		keys.append({"t": 0.9, "pos": Vector2(0.0, 1.0), "rot": 4.0})
	else:
		keys.append({"t": 0.86, "pos": Vector2(-2.0, 3.0), "rot": 28.0})
	keys.append({"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0, "ease": "back"})
	return keys


static func _cylinder_keys(count: int) -> Array:
	var keys: Array = [
		{"t": 0.0, "pos": Vector2.ZERO, "rot": 0.0},
		{"t": 0.1, "pos": Vector2(-3.0, -2.0), "rot": -58.0},                         # cañón arriba, tambor abierto
		{"t": 0.16, "pos": Vector2(-3.0, 1.0), "rot": -64.0, "sound": &"reload_out"}, # vainas afuera
		{"t": 0.22, "pos": Vector2(-2.0, 0.0), "rot": -54.0},
	]
	var start: float = 0.26
	var end: float = 0.84
	var step: float = (end - start) / float(count)
	for i in range(count):
		var t0: float = start + step * float(i)
		keys.append({"t": t0 + step * 0.45, "pos": Vector2(-2.0, 1.5), "rot": -52.0, "sound": &"reload_shell"})
		keys.append({"t": t0 + step, "pos": Vector2(-2.0, 0.0), "rot": -54.0})
	keys.append({"t": 0.9, "pos": Vector2(1.0, -1.0), "rot": -12.0})  # golpe de muñeca: cierra el tambor
	keys.append({"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0, "ease": "back"})
	return keys


static func _shell_keys(count: int) -> Array:
	var keys: Array = [
		{"t": 0.0, "pos": Vector2.ZERO, "rot": 0.0},
		{"t": 0.1, "pos": Vector2(-1.0, 3.0), "rot": 24.0},
	]
	var start: float = 0.14
	var end: float = 0.78
	var step: float = (end - start) / float(count)
	for i in range(count):
		var t0: float = start + step * float(i)
		keys.append({"t": t0 + step * 0.5, "pos": Vector2(1.5, 1.0), "rot": 20.0, "sound": &"reload_shell"})  # empuja el cartucho
		keys.append({"t": t0 + step, "pos": Vector2(-1.0, 3.0), "rot": 24.0})
	keys.append({"t": 0.84, "pos": Vector2(-1.0, 1.0), "rot": 6.0})
	keys.append({"t": 0.9, "pos": Vector2(-5.0, 1.0), "rot": 4.0, "sound": &"reload_rack"})  # bombeo atrás
	keys.append({"t": 0.95, "pos": Vector2(0.5, 0.0), "rot": 0.0})                           # y adelante
	keys.append({"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0})
	return keys


static func _canister_keys() -> Array:
	return [
		{"t": 0.0, "pos": Vector2.ZERO, "rot": 0.0},
		{"t": 0.14, "pos": Vector2(-3.0, 5.0), "rot": 48.0},
		{"t": 0.26, "pos": Vector2(-3.0, 7.0), "rot": 56.0, "sound": &"reload_out"},
		{"t": 0.34, "pos": Vector2(-2.0, 6.0), "rot": 44.0},
		{"t": 0.42, "pos": Vector2(-3.0, 7.0), "rot": 54.0},
		{"t": 0.62, "pos": Vector2(-3.0, 7.0), "rot": 52.0, "sound": &"reload_vent"},  # depósito nuevo, siseo
		{"t": 0.74, "pos": Vector2(-2.0, 5.0), "rot": 42.0, "sound": &"reload_in"},
		{"t": 0.88, "pos": Vector2(-1.0, 2.0), "rot": 18.0},
		{"t": 1.0, "pos": Vector2.ZERO, "rot": 0.0, "ease": "back"},
	]
