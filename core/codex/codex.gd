extends RefCounted
## Códice de enemigos y armas: catálogo, descubrimientos y retratos. Sin class_name: se usa por `preload`.
##
## - Un enemigo se descubre al matarlo (`record_enemy`, lo llaman EnemyBase y BasicRunner al morir).
##   La clave es su `entity_name`; lo no catalogado igual aparece (al final, con texto genérico).
## - Un arma se descubre al tenerla: recogerla, comprarla o equiparla (`record_weapon`).
##   El catálogo de armas son todos los .tres de `WEAPONS_DIR`: un arma nueva entra sola.
## - Lo descubierto se guarda en MetricsManager (`codex_enemies`, `codex_weapons`) con el slot.
## Para sumar un enemigo nuevo al catálogo: agregar una línea en `ENEMIES` (ver skill add-enemy).

const WEAPONS_DIR: String = "res://data/weapons/"
const ENEMY_ART_PATH: String = "res://entities/enemies/enemy_art.gd"
const ARMOR_ART_PATH: String = "res://core/art/armor_art.gd"

## Orden del códice. `name` = entity_name exacto (clave), `kind` = arte para el retrato (MOB_FRAMES o MOBS),
## `world` = dónde aparece, `boss` = jefe, `lore` = descripción.
const ENEMIES: Array[Dictionary] = [
	{"name": "Rata", "kind": "rat", "world": "Ciudad de Jano", "lore": "Ratas de callejón y alcantarilla, grandes como perros. Débiles de a una, peligrosas en manada. Algo que se filtra desde abajo las está haciendo crecer."},
	{"name": "Rata de techo", "kind": "rat", "world": "Ciudad de Jano", "lore": "Se cuelga de las cañerías del techo y cae encima cuando pasás debajo. Mirá para arriba en las alcantarillas."},
	{"name": "Ladrón", "kind": "thief", "world": "Ciudad de Jano", "lore": "Raterito del Sindicato. Corre, pega con lo que tenga a mano y huye. Nunca viene solo."},
	{"name": "Asaltante", "kind": "gunman", "world": "Ciudad de Jano", "lore": "Matón del Sindicato con un arma de fuego barata. Se queda a distancia y dispara: acortá la distancia o cubrite."},
	{"name": "Matón", "kind": "thug", "world": "Ciudad de Jano", "lore": "Músculo del Sindicato. Lento pero resistente; avisa antes de pegar, y cuando pega duele."},
	{"name": "Patovica", "kind": "bouncer", "world": "Ciudad de Jano", "lore": "Seguridad de la discoteca y el hotel. Un tanque cuerpo a cuerpo con mucha armadura: conviene el daño perforante."},
	{"name": "Guardia Antidisturbios", "kind": "bouncer", "world": "Ciudad de Jano", "lore": "Custodia la torre del Sindicato detrás de un escudo que para las balas. De frente no le hacés nada: saltalo y pegale por la espalda, o aturdilo."},
	{"name": "Sicario", "kind": "hitman_smg", "world": "Ciudad de Jano", "lore": "La élite del Sindicato, con subfusil. Ráfagas cortas y rápidas; no te quedes quieto en su línea de tiro."},
	{"name": "Sicario de Élite", "kind": "hitman_elite", "world": "Ciudad de Jano", "lore": "Los más pesados del Sindicato, los que custodian la mercadería en la azotea. Aguantan mucho y castigan cualquier error."},
	{"name": "Agente del Tiempo", "kind": "time_agent", "world": "Todas las épocas", "lore": "Soldados de negro con visor que vigilan el pasillo entre mundos: nadie viaja. Aparecen cada tanto para atraparte. Llevan cristales de tiempo, lo único que abre las puertas."},
	{"name": "Rata Gigante", "kind": "rat", "world": "Ciudad de Jano", "boss": true, "lore": "Lo que vive al fondo de las alcantarillas. Eso no es una rata de acá. Guarda una flauta que no debería existir."},
	{"name": "Bruto Acorazado", "kind": "brute", "world": "Otras épocas", "lore": "Un coloso con placas de metal y un martillo. Absorbe el daño común; las armas perforantes lo abren."},
	{"name": "Centinela de Escudo", "kind": "sentinel", "world": "Otras épocas", "lore": "Avanza detrás de un escudo que frena los disparos de frente. Rodealo o rompé la guardia."},
	{"name": "Torreta Francotiradora", "kind": "sniper_base", "world": "Otras épocas", "lore": "Cañón automático que apunta con un láser antes de disparar. Cuando ves la línea, movete."},
	{"name": "Fantasma", "kind": "", "world": "Otras épocas", "lore": "Una presencia que flota y atraviesa lo que encuentra. Difícil de seguir con la mira."},
	{"name": "Zombi", "kind": "", "world": "Otras épocas", "lore": "Lento, insistente, y nunca solo. Aguanta más de lo que parece."},
	{"name": "Coloso del Núcleo", "kind": "brute", "world": "Otras épocas", "boss": true, "lore": "Un bruto enorme alimentado por un núcleo inestable. Sus golpes contra el suelo levantan ondas de choque."},
]

const UNKNOWN_LORE: String = "Sin datos todavía. Seguí peleando para saber más."

static var _weapon_cache: Array[WeaponData] = []


# ==============================================================================
# Registro
# ==============================================================================

static func record_enemy(enemy: Node) -> void:
	var metrics: MetricsManager = MetricsManager.get_instance()
	if metrics == null or enemy == null:
		return
	var enemy_name: String = str(enemy.get("entity_name")) if enemy.get("entity_name") != null else ""
	if enemy_name.is_empty():
		return
	var entry: Dictionary = metrics.codex_enemies.get(enemy_name, {}) as Dictionary
	entry["kills"] = int(entry.get("kills", 0)) + 1
	var kind: Variant = enemy.get("art_kind")
	if kind != null and not str(kind).is_empty():
		entry["kind"] = str(kind)
	var hc: Node = enemy.get_node_or_null("HealthComponent")
	if hc != null and hc.get("max_health") != null:
		entry["max_hp"] = maxf(float(entry.get("max_hp", 0.0)), float(hc.get("max_health")))
	var level: Variant = enemy.get("enemy_level")
	if level != null:
		entry["max_level"] = maxi(int(entry.get("max_level", 0)), int(level))
	metrics.codex_enemies[enemy_name] = entry


static func record_weapon(weapon: Resource) -> void:
	var metrics: MetricsManager = MetricsManager.get_instance()
	if metrics == null or not (weapon is WeaponData):
		return
	var id: String = weapon_id(weapon as WeaponData)
	if not id.is_empty():
		metrics.codex_weapons[id] = true


## Ruta del .tres original (las armas en mano son copias con `source_resource_path`).
static func weapon_id(weapon: WeaponData) -> String:
	if weapon.resource_path.begins_with("res://") and weapon.resource_path.ends_with(".tres"):
		return weapon.resource_path
	return weapon.source_resource_path


# ==============================================================================
# Consulta (para la ventana)
# ==============================================================================

## Entradas de enemigos: {name, kind, world, boss, lore, found, kills, max_hp, max_level}.
static func enemy_entries() -> Array[Dictionary]:
	var found: Dictionary = {}
	var metrics: MetricsManager = MetricsManager.get_instance()
	if metrics != null:
		found = metrics.codex_enemies
	var result: Array[Dictionary] = []
	var listed: Dictionary = {}
	for base: Dictionary in ENEMIES:
		listed[base["name"]] = true
		result.append(_enemy_entry(base, found.get(base["name"], null)))
	for enemy_name: Variant in found.keys():
		if not listed.has(enemy_name):
			var extra: Dictionary = {"name": str(enemy_name), "kind": "", "world": "?", "lore": UNKNOWN_LORE}
			result.append(_enemy_entry(extra, found[enemy_name]))
	return result


## Entradas de armas: {id, weapon, found}, ordenadas por rareza y nombre.
static func weapon_entries() -> Array[Dictionary]:
	var found: Dictionary = {}
	var metrics: MetricsManager = MetricsManager.get_instance()
	if metrics != null:
		found = metrics.codex_weapons
	var result: Array[Dictionary] = []
	for weapon: WeaponData in all_weapons():
		result.append({"id": weapon.resource_path, "weapon": weapon, "found": found.has(weapon.resource_path)})
	return result


## Todas las armas del juego (los .tres de WEAPONS_DIR; en la versión exportada vienen como .remap).
static func all_weapons() -> Array[WeaponData]:
	if not _weapon_cache.is_empty():
		return _weapon_cache
	var dir: DirAccess = DirAccess.open(WEAPONS_DIR)
	if dir == null:
		return _weapon_cache
	for file: String in dir.get_files():
		var clean: String = file.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var weapon: WeaponData = load(WEAPONS_DIR + clean) as WeaponData
		if weapon != null:
			_weapon_cache.append(weapon)
	_weapon_cache.sort_custom(func(a: WeaponData, b: WeaponData) -> bool:
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.weapon_name.naturalnocasecmp_to(b.weapon_name) < 0)
	return _weapon_cache


## Retrato del enemigo: primer cuadro de la marcha dibujada, o la ilustración fija. null si no hay.
static func enemy_portrait(kind: String) -> Texture2D:
	if kind.is_empty():
		return null
	var frames: Dictionary = _script_const(ENEMY_ART_PATH, "MOB_FRAMES")
	if frames.has(kind):
		var path: String = str((frames[kind] as Dictionary).get("dir", "")) + "walk_0.png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	var mobs: Dictionary = _script_const(ARMOR_ART_PATH, "MOBS")
	if mobs.has(kind):
		var file: String = str((mobs[kind] as Dictionary).get("file", ""))
		if ResourceLoader.exists(file):
			return load(file) as Texture2D
	return null


static func _enemy_entry(base: Dictionary, data: Variant) -> Dictionary:
	var entry: Dictionary = base.duplicate()
	entry["found"] = data != null
	if data is Dictionary:
		var d: Dictionary = data as Dictionary
		entry["kills"] = int(d.get("kills", 0))
		entry["max_hp"] = float(d.get("max_hp", 0.0))
		entry["max_level"] = int(d.get("max_level", 0))
		if str(entry.get("kind", "")).is_empty():
			entry["kind"] = str(d.get("kind", ""))
	return entry


static func _script_const(path: String, const_name: String) -> Dictionary:
	var script: GDScript = load(path) as GDScript
	if script == null:
		return {}
	var value: Variant = script.get_script_constant_map().get(const_name, {})
	return value as Dictionary if value is Dictionary else {}
