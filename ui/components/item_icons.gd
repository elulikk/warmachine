extends RefCounted
## Íconos de ítems en pixel art 16x16, definidos como texto (no hay assets de arte en el proyecto).
## Sin class_name a propósito: se carga por `preload` (ver ItemSlot y TradeWindow).
##
## Cada ícono es de colores neutros (acero, cuero, etc.): la rareza NO se pinta en el ícono sino
## en el borde del casillero, como en WoW. Para sumar un ícono: agregar sus 16 filas a ICON_ROWS y
## devolver su nombre desde `kind_for`. Para reemplazarlos por arte real, bastaría que
## `get_icon_for` devuelva un Texture2D cargado de disco.

const ArtScript = preload("res://core/art/art.gd")
const WeaponArt = preload("res://core/art/weapon_art.gd")
const WeaponHeldArt = preload("res://core/art/weapon_held_art.gd")
const WeaponMotion = preload("res://core/art/weapon_motion.gd")

## Carpeta de íconos de arte (assets/art): items/<item_id>.png, consumables/<id>.png, runes/<rune_id>.png
## y weapons/<archivo del .tres>.png. Si falta el PNG se usa el ícono pixel art 16x16 de abajo.
const ART_ITEMS_DIR: String = "res://assets/art/items/"
const ART_CONSUMABLES_DIR: String = "res://assets/art/consumables/"
const ART_RUNES_DIR: String = "res://assets/art/runes/"
## Íconos de inventario simplificados (32 px, pixel art): icons/<id>.png con el id del arma o del ítem.
## Tienen prioridad sobre el arte grande; el arma en mano también los usa (ver weapon_held_art.gd).
const ART_ICONS_DIR: String = "res://assets/art/icons/"

const SIZE: int = 16

## Letras de la paleta de los mapas de píxeles. "." es transparente.
const PALETTE: Dictionary = {
	"K": Color(0.06, 0.07, 0.09, 1.0), # contorno
	"S": Color(0.82, 0.87, 0.93, 1.0), # acero claro
	"s": Color(0.55, 0.62, 0.72, 1.0), # acero medio
	"d": Color(0.32, 0.38, 0.47, 1.0), # acero oscuro
	"W": Color(1.00, 1.00, 1.00, 1.0), # brillo
	"B": Color(0.60, 0.40, 0.22, 1.0), # cuero / madera
	"b": Color(0.36, 0.22, 0.12, 1.0), # cuero oscuro
	"Y": Color(0.95, 0.78, 0.25, 1.0), # dorado
	"R": Color(0.85, 0.25, 0.20, 1.0), # rojo
	"G": Color(0.35, 0.80, 0.45, 1.0), # verde
	"C": Color(0.40, 0.85, 1.00, 1.0), # cian
	"O": Color(0.95, 0.55, 0.15, 1.0)  # naranja
}

static var _cache: Dictionary = {}
static var _pose_cache: Dictionary = {}
static var _slot_cache: Dictionary = {}
## Lado mayor (px) del arte reducido para los casilleros: ~2x el casillero, para que se vea nítido.
const SLOT_ART_MAX: int = 96

const ICON_ROWS: Dictionary = {
	"helmet": [
		"................",
		"................",
		"....KKKKKKKK....",
		"...KSSSSSSSsK...",
		"..KSSWWSSSSssK..",
		"..KSSWSSSSSssK..",
		"..KSSSSSSSSssK..",
		"..KSSSSSSSSssK..",
		"..KKKKKKKKKKKK..",
		"..KCCCCCCCCCCK..",
		"..KCCWCCCCCCCK..",
		"..KKKKKKKKKKKK..",
		"..KSSsK..KsSsK..",
		"..KSsK....KsdK..",
		"...KKK....KKK...",
		"................"
	],
	"chest": [
		"................",
		"..KKKK....KKKK..",
		".KSSSSK..KSSSSK.",
		".KSSWSSKKSSSSsK.",
		".KSSSSSSSSSSSsK.",
		".KSSSSSSSSSSssK.",
		"..KSSSSddSSSsK..",
		"..KSSSSddSSSsK..",
		"..KSWSSddSSSsK..",
		"..KSSSSddSSssK..",
		"..KsSSSddSSssK..",
		"..KsSSSSSSSssK..",
		"..KdsSSSSSssdK..",
		"...KdsssssssK...",
		"....KKKKKKKK....",
		"................"
	],
	"boots": [
		"................",
		"................",
		"....KKKK........",
		"...KBBBBK.......",
		"...KBYYBK.......",
		"...KBBBBK.......",
		"...KBBBBK.......",
		"...KBBBBK.......",
		"...KBBBBKKKK....",
		"...KBBBBBBBBKK..",
		"..KBBBBBBBBBBBK.",
		"..KBBBBBBBBBBbK.",
		"..KbbbbbbbbbbbK.",
		"..KdddddddddddK.",
		"..KKKKKKKKKKKKK.",
		"................"
	],
	"ring": [
		"................",
		".......KK.......",
		"......KCCK......",
		"......KWCK......",
		".....KKKKKK.....",
		"....KYYYYYYK....",
		"...KYK....KYK...",
		"...KY......YK...",
		"...KY......YK...",
		"...KYK....KYK...",
		"....KYYYYYYK....",
		".....KKKKKK.....",
		"................",
		"................",
		"................",
		"................"
	],
	"jetpack": [
		"................",
		"...KKKK..KKKK...",
		"..KSSSSKKSSSSK..",
		"..KSWSsKKSWSsK..",
		"..KSSSsKKSSSsK..",
		"..KSSSsKKSSSsK..",
		"..KSSSsKKSSSsK..",
		"..KRRRRKKRRRRK..",
		"..KdddKKKKdddK..",
		"...KKK....KKK...",
		"...KOK....KOK...",
		"....Y......Y....",
		"................",
		"................",
		"................",
		"................"
	],
	"wings": [
		"................",
		"................",
		"KK............KK",
		"KWK..........KWK",
		"KWWK........KWWK",
		"KWWWK......KWWWK",
		".KWWWKK..KKWWWK.",
		".KSWWWWKKWWWWSK.",
		"..KSSWWWKWWWSSK.",
		"..KSSSWWKWWSSsK.",
		"...KsSSSKSSSsK..",
		"....KKsSKSsKK...",
		".....KKKKKKK....",
		"................",
		"................",
		"................"
	],
	"grenade": [
		"................",
		".......KKK......",
		"......KddK......",
		".....KKKKKK.....",
		"....KGGGGGGK....",
		"...KGGWGGGGGK...",
		"...KGGGGGGGGK...",
		"...KGGGGGGGGK...",
		"...KGGGGGGGGK...",
		"...KGGGGGGGGK...",
		"....KGGGGGGK....",
		".....KKKKKK.....",
		"................",
		"................",
		"................",
		"................"
	],
	"gem": [
		"................",
		"................",
		".....KKKKKK.....",
		"....KCWCCCCK....",
		"...KCWCCCCCCK...",
		"..KCCCCCCCCCCK..",
		"...KCCCCCCCCK...",
		"....KCCCCCCK....",
		".....KCCCCK.....",
		"......KCCK......",
		".......KK.......",
		"................",
		"................",
		"................",
		"................",
		"................"
	],
	"hook": [
		"................",
		"......KKKK......",
		".....KSSSSK.....",
		".....KS..SK.....",
		".....KS..SK.....",
		"......KKSK......",
		".......KSK......",
		".......KSK......",
		"......KSK.......",
		".....KSK........",
		"....KSK.........",
		"...KBBK.........",
		"..KBBK..........",
		"..KKK...........",
		"................",
		"................"
	],
	"beacon": [
		"................",
		".......KK.......",
		"......KCCK......",
		".....KCWCCK.....",
		"......KCCK......",
		".....KKddKK.....",
		"....KSSddSSK....",
		"....KSSddSSK....",
		"....KsSSSSsK....",
		"....KddddddK....",
		".....KKKKKK.....",
		"................",
		"................",
		"................",
		"................",
		"................"
	],
	"knife": [
		"................",
		"................",
		"................",
		"............KK..",
		"...........KWK..",
		"..........KWSK..",
		".........KWSK...",
		"........KWSK....",
		".......KWSK.....",
		"......KSsK......",
		".....KKKK.......",
		"...KBBK.........",
		"..KBbK..........",
		"..KKK...........",
		"................",
		"................"
	],
	"sword": [
		"..............KK",
		".............KWK",
		"............KWSK",
		"...........KWSK.",
		"..........KWSK..",
		".........KWSK...",
		"..KK....KWSK....",
		"..KYK..KWSK.....",
		"...KYKKWSK......",
		"....KYYSK.......",
		"....KYYK........",
		"...KBBK.KK......",
		"..KBbK..........",
		".KBbK...........",
		".KKK............",
		"................"
	],
	"katana": [
		"..............KK",
		".............KWK",
		"............KWK.",
		"...........KWK..",
		"..........KWK...",
		".........KWK....",
		"........KWK.....",
		".......KWK......",
		"......KWK.......",
		".....KYYK.......",
		"....KRRK........",
		"...KRbK.........",
		"..KRRK..........",
		".KRbK...........",
		".KKK............",
		"................"
	],
	"hammer": [
		"................",
		"....KKKKKKKK....",
		"...KSSSSSSSsK...",
		"...KSWSSSSSsK...",
		"...KSSSSSSSsK...",
		"...KsssssssdK...",
		"....KKKKBKKK....",
		".......KBK......",
		".......KBK......",
		".......KBK......",
		".......KbK......",
		".......KbK......",
		".......KbK......",
		"......KKKKK.....",
		"................",
		"................"
	],
	"pistol": [
		"................",
		"................",
		"................",
		"..KKKKKKKKKKK...",
		"..KSSSSSSSSsK...",
		"..KSWSSSSSSsK...",
		"..KsssssssssK...",
		"..KKKKKKKKKKK...",
		"....KddKK.......",
		"....KBBK........",
		"....KBBK........",
		"....KbbK........",
		".....KK.........",
		"................",
		"................",
		"................"
	],
	"revolver": [
		"................",
		"................",
		"..KKKKKKKKKKKK..",
		"..KsssssssssdK..",
		"..KSSSSKYYKSSK..",
		"..KSWSSKYYKSsK..",
		"..KKKKKKKKKKKK..",
		"...KddK.........",
		"...KBBK.........",
		"...KBBK.........",
		"...KbbK.........",
		"....KK..........",
		"................",
		"................",
		"................",
		"................"
	],
	"smg": [
		"................",
		"................",
		"..KKKKKKKKKKKKK.",
		"KKSSSSSSSSSSSSsK",
		"KSSWSSSSSSSsssdK",
		"KKSSSSSSSSSKKKK.",
		".KKKKKKKKKKK....",
		"...KdK..KdK.....",
		"...KdK..KddK....",
		"...KdK..KBBK....",
		"...KdK..KBBK....",
		"...KKK..KKK.....",
		"................",
		"................",
		"................",
		"................"
	],
	"shotgun": [
		"................",
		"................",
		"................",
		"................",
		"KKKKKKKKKKKKKKK.",
		"KsssssssssssssdK",
		"KKKKKKKKKKKKKKK.",
		"....KBBBBBBBBBBK",
		"...KBBbbbbBBBBBK",
		"..KBBbK...KBBBK.",
		"..KBbK....KKKK..",
		"..KKK...........",
		"................",
		"................",
		"................",
		"................"
	],
	"rifle": [
		"................",
		"................",
		"......KKKK......",
		"......KCWK......",
		"KKKKKKKKKKKKKKK.",
		"KsSSSSSSSSSSSSdK",
		"KKKKKKKKKKKKKKK.",
		"...KBBBBBKdK....",
		"..KBBBBBBKdK....",
		".KBBbbBBBKKK....",
		".KBbKKKKK.......",
		".KKK............",
		"................",
		"................",
		"................",
		"................"
	],
	"carbine": [
		"................",
		"................",
		"................",
		"....KKKKKKKKKKK.",
		"....KsssssssssdK",
		"....KKKKKKKKKKK.",
		"KKKKKSSSSSKdK...",
		"KBBBBSSWSSKdK...",
		"KBBBBKKKKKKKK...",
		".KBBBK..........",
		"..KKK...........",
		"................",
		"................",
		"................",
		"................",
		"................"
	],
	"blaster": [
		"................",
		"................",
		"................",
		"..KKKKKKKKKKK...",
		"..KSSSSSSSSsK...",
		"..KSGGGGGGGsK...",
		"..KsGGWGGGGsK...",
		"..KKKKKKKKKKK...",
		"....KddKK.......",
		"....KBBK........",
		"....KBBK........",
		"....KbbK........",
		".....KK.........",
		"................",
		"................",
		"................"
	],
	"flamer": [
		"................",
		"................",
		"......KKK.......",
		".....KRRRK......",
		"..KKKKRRRKKKKOO.",
		"KKSSSSSSSSSSKOYO",
		"KSWSSSSSSSssKOOO",
		"KKKKKKKKKKKKKKKK",
		"...KdK...KddK...",
		"...KBBK..KddK...",
		"...KbbK..KKKK...",
		"................",
		"................",
		"................",
		"................",
		"................"
	]
}


## Cómo se sostiene cada arma en mano usando su propio ícono (ver WeaponManager._update_weapon_visual).
## - grip: píxel del ícono que queda en la mano del jugador (para armas de fuego, a la altura del cañón,
##   así la línea de tiro coincide con el eje del arma).
## - tip_x: columna del ícono donde termina el arma; ahí se coloca el `Muzzle`.
## - rot_deg: giro para que el arma apunte hacia +X (los filos del ícono miran arriba a la derecha).
## - scale: ampliación del ícono de 16x16.
## Ampliación del ícono de las armas de fuego en mano (se multiplica por WeaponManager.WEAPON_SCALE).
const RANGED_POSE_SCALE: float = 1.4

const WEAPON_POSES: Dictionary = {
	# Las armas melee son grandes a propósito: la punta llega a ~40 px del jugador, dentro del alcance del hitbox (2 a 50 px)
	"knife": {"grip": Vector2(3.5, 11.5), "tip_x": 13.0, "rot_deg": 45.0, "scale": 2.2},
	"sword": {"grip": Vector2(3.0, 12.0), "tip_x": 15.0, "rot_deg": 45.0, "scale": 2.4},
	"katana": {"grip": Vector2(3.5, 11.5), "tip_x": 14.0, "rot_deg": 45.0, "scale": 2.5},
	"hammer": {"grip": Vector2(7.5, 11.0), "tip_x": 8.0, "rot_deg": 90.0, "scale": 3.2},
	"pistol": {"grip": Vector2(5.0, 5.0), "tip_x": 13.0, "rot_deg": 0.0, "scale": RANGED_POSE_SCALE},
	"revolver": {"grip": Vector2(4.0, 4.0), "tip_x": 14.0, "rot_deg": 0.0, "scale": RANGED_POSE_SCALE},
	"smg": {"grip": Vector2(8.5, 4.0), "tip_x": 16.0, "rot_deg": 0.0, "scale": RANGED_POSE_SCALE},
	"shotgun": {"grip": Vector2(4.0, 5.0), "tip_x": 15.0, "rot_deg": 0.0, "scale": RANGED_POSE_SCALE},
	"rifle": {"grip": Vector2(5.0, 5.0), "tip_x": 15.0, "rot_deg": 0.0, "scale": RANGED_POSE_SCALE},
	"carbine": {"grip": Vector2(5.0, 4.0), "tip_x": 15.0, "rot_deg": 0.0, "scale": RANGED_POSE_SCALE},
	"blaster": {"grip": Vector2(5.0, 5.0), "tip_x": 13.0, "rot_deg": 0.0, "scale": RANGED_POSE_SCALE},
	"flamer": {"grip": Vector2(6.0, 5.5), "tip_x": 16.0, "rot_deg": 0.0, "scale": RANGED_POSE_SCALE},
	# Escudos: el ícono es de 32 px (no de 16), así que la escala es la mitad: el escudo mide ~24 px en el mundo
	"shield": {"grip": Vector2(16.0, 16.0), "tip_x": 16.0, "rot_deg": 0.0, "scale": 0.5}
}


## Pose en mano del arma (ver WEAPON_POSES). Vacío si el arma no tiene ícono ni pose.
static func get_weapon_pose(weapon: WeaponData) -> Dictionary:
	if weapon == null:
		return {}
	# Arma con arte HD: pose calculada al extraer el sprite (agarre, boca del cañón, mano de apoyo)
	var art_id: String = _weapon_file_id(weapon)
	var art_data: Dictionary = WeaponArt.WEAPONS.get(art_id, {}) as Dictionary
	if not art_data.is_empty():
		# Cuántas manos ocupa sale de los datos del arma (`grip`), no del arte; la pose se cachea por arma y empuñadura
		var cache_key: String = "%s|%d" % [art_id, int(weapon.grip)]
		if _pose_cache.has(cache_key):
			return _pose_cache[cache_key] as Dictionary
		# El perfil de movimiento puede cambiar el agarre (p. ej. la mano de apoyo del martillo)
		var override: Dictionary = WeaponMotion.profile_for(weapon).get("pose", {}) as Dictionary
		var pose: Dictionary = art_data.merged(override, true) if not override.is_empty() else art_data.duplicate()
		pose["two_hand"] = weapon.is_two_handed()
		# En mano se dibuja el ícono (mismo marco que el arte grande, a escala `ratio`): se escalan los puntos
		var ratio: float = held_ratio(weapon)
		if ratio != 1.0:
			for key: String in ["grip", "hand", "support", "size"]:
				if pose.has(key):
					var point: Vector2 = pose[key] as Vector2
					pose[key] = point if point.x < 0.0 else point * ratio
			pose["tip_x"] = float(pose.get("tip_x", 0.0)) * ratio
			pose["scale"] = float(pose.get("scale", 1.0)) / ratio
		_pose_cache[cache_key] = pose
		return pose
	var kind: String = _weapon_kind(weapon)
	return WEAPON_POSES.get(kind, {}) as Dictionary


## Ícono (Texture2D) de un recurso: ItemData, WeaponData o RuneData. null si no hay ícono para él.
static func get_icon_for(res: Resource) -> Texture2D:
	if res == null:
		return null
	var art_icon: Texture2D = get_art_icon(res)
	if art_icon != null:
		return art_icon
	var kind: String = kind_for(res)
	if kind.is_empty():
		return null

	# Las runas se tiñen con su color para distinguirlas entre sí
	var tint: Color = Color(0.40, 0.85, 1.00, 1.0)
	var rune: RuneData = res as RuneData
	if rune != null:
		tint = rune.rune_color

	var cache_key: String = "%s|%s" % [kind, tint.to_html()]
	if _cache.has(cache_key):
		return _cache[cache_key] as Texture2D

	var rows: Array = ICON_ROWS.get(kind, []) as Array
	if rows.size() != SIZE:
		return null

	var image: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(SIZE):
		var row: String = str(rows[y])
		for x in range(mini(SIZE, row.length())):
			var letter: String = row[x]
			if letter == ".":
				continue
			var color: Color = PALETTE.get(letter, Color(1.0, 0.0, 1.0, 1.0))
			if letter == "C" and rune != null:
				color = tint
			image.set_pixel(x, y, color)

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[cache_key] = texture
	return texture


## Ícono de arte (PNG de assets/art) de un recurso, o null si no hay.
static func get_art_icon(res: Resource) -> Texture2D:
	if res == null:
		return null
	if is_icon_file(res):
		return ArtScript.tex(_icon_file_path(res))
	return get_hd_art(res)


## Textura del arma para dibujarla en mano: el ícono de inventario puesto en el marco del arte grande
## (weapon_held_art.gd); si no lo hay, el arte grande; y si tampoco, el ícono normal.
static func get_held_texture(weapon: WeaponData) -> Texture2D:
	if weapon != null:
		var held: Dictionary = WeaponHeldArt.WEAPONS.get(_weapon_file_id(weapon), {}) as Dictionary
		if not held.is_empty():
			var held_tex: Texture2D = ArtScript.tex(str(held.get("file", "")))
			if held_tex != null:
				return held_tex
	var hd: Texture2D = get_hd_art(weapon)
	return hd if hd != null else get_icon_for(weapon)


## Escala de la textura en mano respecto del arte grande (1 si se dibuja el arte grande).
static func held_ratio(weapon: WeaponData) -> float:
	if weapon == null:
		return 1.0
	var held: Dictionary = WeaponHeldArt.WEAPONS.get(_weapon_file_id(weapon), {}) as Dictionary
	if held.is_empty() or ArtScript.tex(str(held.get("file", ""))) == null:
		return 1.0
	return float(held.get("ratio", 1.0))


## Textura para dibujar en un casillero. El arte grande se reduce de antemano con filtro de calidad
## (Lanczos): reducirlo de golpe al tamaño del casillero deja el dentado y el aspecto deformado.
static func get_slot_texture(res: Resource) -> Texture2D:
	var tex: Texture2D = get_icon_for(res)
	if tex == null or is_icon_file(res) or get_art_icon(res) == null:
		return tex
	var key: int = tex.get_instance_id()
	if _slot_cache.has(key):
		return _slot_cache[key] as Texture2D
	var image: Image = tex.get_image()
	if image == null or image.is_empty():
		return tex
	var longest: int = maxi(image.get_width(), image.get_height())
	if longest > SLOT_ART_MAX:
		var factor: float = float(SLOT_ART_MAX) / float(longest)
		image.resize(maxi(1, roundi(image.get_width() * factor)), maxi(1, roundi(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	var reduced: Texture2D = ImageTexture.create_from_image(image)
	_slot_cache[key] = reduced
	return reduced


## Arte grande (assets/art) de un recurso, sin pasar por los íconos simplificados.
static func get_hd_art(res: Resource) -> Texture2D:
	if res == null:
		return null
	if res is WeaponData:
		var data: Dictionary = WeaponArt.WEAPONS.get(_weapon_file_id(res as WeaponData), {}) as Dictionary
		if data.is_empty():
			return null
		return ArtScript.tex(str(data.get("file", "")))
	if res is RuneData:
		return ArtScript.tex(ART_RUNES_DIR + (res as RuneData).rune_id + ".png")
	if res is ItemData:
		return ArtScript.tex(ART_ITEMS_DIR + (res as ItemData).item_id + ".png")
	if "consumable_id" in res:
		return ArtScript.tex(ART_CONSUMABLES_DIR + str(res.get("consumable_id")) + ".png")
	return null


## true si el recurso tiene un ícono de inventario simplificado en ART_ICONS_DIR.
static func is_icon_file(res: Resource) -> bool:
	var path: String = _icon_file_path(res)
	return not path.is_empty() and (FileAccess.file_exists(path) or ResourceLoader.exists(path))


## Ruta del ícono simplificado de un arma (por su .tres) o un ítem (por item_id). Vacía si no aplica.
static func _icon_file_path(res: Resource) -> String:
	if res is WeaponData:
		return ART_ICONS_DIR + _weapon_file_id(res as WeaponData) + ".png"
	if res is ItemData:
		return ART_ICONS_DIR + (res as ItemData).item_id + ".png"
	return ""


## Nombre del archivo `.tres` del arma sin extensión (clave de las tablas de arte).
static func _weapon_file_id(weapon: WeaponData) -> String:
	var path: String = weapon.source_resource_path if not weapon.source_resource_path.is_empty() else weapon.resource_path
	return path.get_file().get_basename()


## Nombre del ícono que corresponde al recurso (ver ICON_ROWS). Vacío si no tiene.
static func kind_for(res: Resource) -> String:
	var weapon: WeaponData = res as WeaponData
	if weapon != null:
		return _weapon_kind(weapon)

	var item: ItemData = res as ItemData
	if item != null:
		return _item_kind(item)

	if res is RuneData:
		return "gem"
	return ""


static func _item_kind(item: ItemData) -> String:
	# Casos puntuales por identificador
	match item.item_id:
		"jetpack":
			return "jetpack"
		"feather_wings":
			return "wings"
		"grappling_hook":
			return "hook"
		"teleport_beacon":
			return "beacon"
	# Resto por ranura de equipo
	match item.equip_slot.to_upper():
		"HEAD":
			return "helmet"
		"CHEST":
			return "chest"
		"BOOTS":
			return "boots"
		"BACK":
			return "jetpack"
		"ACCESSORY":
			return "ring"
		"TACTICAL":
			return "grenade"
	return "gem"


static func _weapon_kind(weapon: WeaponData) -> String:
	var path: String = weapon.source_resource_path if not weapon.source_resource_path.is_empty() else weapon.resource_path
	match path.get_file().get_basename():
		"combat_knife":
			return "knife"
		"iron_sword", "frostmourne", "demon_sword", "scythe":
			return "sword"
		"katana":
			return "katana"
		"heavy_hammer", "abyss_axe", "mjolnir":
			return "hammer"
		"pistol", "pistol_9mm", "desert_eagle", "lava_pistol":
			return "pistol"
		"rust_revolver", "revolver", "colt_44":
			return "revolver"
		"smg", "mp5":
			return "smg"
		"ak47":
			return "rifle"
		"m4":
			return "carbine"
		"shotgun":
			return "shotgun"
		"heavy_sniper":
			return "rifle"
		"scrap_carbine", "old_rifle":
			return "carbine"
		"corrosive_blaster":
			return "blaster"
		"plasma_flamethrower", "fuel_flamethrower":
			return "flamer"
		"mirror_shield", "wooden_shield":
			return "shield"
		"javelin", "fire_staff", "ice_staff", "hell_trident", "soul_staff", "sulfur_scepter":
			return "sword"
	# Armas sin ícono propio: por tipo
	if weapon.weapon_type == WeaponData.WeaponType.MELEE:
		return "sword"
	return "pistol"
