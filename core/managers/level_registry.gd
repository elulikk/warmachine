class_name LevelRegistry
extends RefCounted
## Registro Central de Niveles y Capítulos de la Campaña de Warmachine.
## Mapea las 50 expediciones divididas en 5 capítulos temáticos de 10 niveles cada uno.

const TOTAL_CHAPTERS: int = 5
const LEVELS_PER_CHAPTER: int = 10

## Niveles con contenido real. El resto son esqueletos vacíos y el selector los marca como pendientes.
const IMPLEMENTED_LEVELS: Array[String] = [
	# Mundo 1: Ciudad de Jano (ciudad moderna, 8 sectores)
	"res://levels/chapter_1/level_1_01.tscn",
	"res://levels/chapter_1/level_1_02.tscn",
	"res://levels/chapter_1/level_1_03.tscn",
	"res://levels/chapter_1/level_1_04.tscn",
	"res://levels/chapter_1/level_1_05.tscn",
	"res://levels/chapter_1/level_1_06.tscn",
	"res://levels/chapter_1/level_1_07.tscn",
	"res://levels/chapter_1/level_1_08.tscn",
	"res://levels/chapter_2/level_2_01.tscn",
	"res://levels/chapter_2/level_2_02.tscn",
	"res://levels/chapter_2/level_2_03.tscn",
	"res://levels/chapter_2/level_2_04.tscn",
	"res://levels/chapter_2/level_2_05.tscn",
	"res://levels/chapter_2/level_2_06.tscn",
	"res://levels/chapter_2/level_2_07.tscn",
	"res://levels/chapter_2/level_2_08.tscn",
	"res://levels/chapter_2/level_2_09.tscn",
	"res://levels/chapter_2/level_2_10.tscn",
	"res://levels/chapter_3/level_3_01.tscn",
	"res://levels/chapter_3/level_3_02.tscn",
	"res://levels/chapter_3/level_3_03.tscn",
	"res://levels/chapter_3/level_3_04.tscn",
	"res://levels/chapter_3/level_3_05.tscn",
	"res://levels/chapter_3/level_3_06.tscn",
	"res://levels/chapter_3/level_3_07.tscn",
	"res://levels/chapter_3/level_3_08.tscn",
	"res://levels/chapter_3/level_3_09.tscn",
	"res://levels/chapter_3/level_3_10.tscn",
	# Mundo 4: Periferia Subterránea (steampunk, 10 sectores)
	"res://levels/chapter_4/level_4_01.tscn",
	"res://levels/chapter_4/level_4_02.tscn",
	"res://levels/chapter_4/level_4_03.tscn",
	"res://levels/chapter_4/level_4_04.tscn",
	"res://levels/chapter_4/level_4_05.tscn",
	"res://levels/chapter_4/level_4_06.tscn",
	"res://levels/chapter_4/level_4_07.tscn",
	"res://levels/chapter_4/level_4_08.tscn",
	"res://levels/chapter_4/level_4_09.tscn",
	"res://levels/chapter_4/level_4_10.tscn"
]

## Cantidad de niveles por capítulo cuando no es LEVELS_PER_CHAPTER. El último de cada capítulo es el jefe o el final.
const LEVEL_COUNTS: Dictionary = {1: 8}
## La Caja: campamento y pasillo de puertas. Es el destino del último sector de cada mundo y el hub de la campaña.
const HUB_PATH: String = "res://scenes/hub/base_camp.tscn"
## Destino del último nivel de un mundo: siempre la Caja (los mundos ya no encadenan entre sí).
const CHAPTER_EXIT: Dictionary = {1: HUB_PATH, 2: HUB_PATH, 3: HUB_PATH, 4: HUB_PATH, 5: HUB_PATH}
## Nombres de los sectores de Ciudad de Jano (capítulo 1). Los demás sectores solo llevan el número.
const JANO_SECTOR_NAMES: Dictionary = {
	1: "La calle", 2: "Los callejones", 3: "Las alcantarillas", 4: "El barrio de casitas",
	5: "El muelle", 6: "El hotel", 7: "La discoteca", 8: "La azotea"
}

## Nombres visibles de los mundos. Sin número: el orden no importa, todos se abren desde la Caja.
static var CHAPTER_NAMES: Dictionary = {
	1: "CIUDAD DE JANO",
	2: "VALLE ESMERALDA",
	3: "ABISMO ÍGNEO",
	4: "PERIFERIA SUBTERRÁNEA",
	5: "NÚCLEO DEL REACTOR"
}

static var CHAPTER_COLORS: Dictionary = {
	1: Color(0.5, 0.65, 1.0, 1.0), # Azul frío de ciudad nocturna
	2: Color(0.45, 0.85, 0.35, 1.0), # Verde pradera medieval
	3: Color(1.0, 0.38, 0.12, 1.0), # Rojo fuego infernal
	4: Color(0.2, 0.65, 0.85, 1.0), # Azul metálico frío
	5: Color(0.75, 0.35, 0.95, 1.0) # Púrpura plasma reactor
}


static func levels_in_chapter(chapter: int) -> int:
	return int(LEVEL_COUNTS.get(chapter, LEVELS_PER_CHAPTER))


## Genera el listado completo de los 50 niveles con sus metadatos.
static func get_all_levels() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for chap in range(1, TOTAL_CHAPTERS + 1):
		var count: int = levels_in_chapter(chap)
		for lvl in range(1, count + 1):
			var id_str: String = "%d_%02d" % [chap, lvl]
			var path_str: String = "res://levels/chapter_%d/level_%d_%02d.tscn" % [chap, chap, lvl]
			var is_boss: bool = (lvl == count)
			var suffix: String = " [JEFE]" if is_boss else ""
			var sector_name: String = (" · " + JANO_SECTOR_NAMES[lvl]) if chap == 4 and JANO_SECTOR_NAMES.has(lvl) else ""
			var name_str: String = "Sector %02d%s%s" % [lvl, sector_name, suffix]

			var next_path: String = ""
			if lvl < count:
				next_path = "res://levels/chapter_%d/level_%d_%02d.tscn" % [chap, chap, lvl + 1]
			else:
				next_path = str(CHAPTER_EXIT.get(chap, HUB_PATH))

			list.append({
				"id": id_str,
				"chapter": chap,
				"number": lvl,
				"title": name_str,
				"path": path_str,
				"next_path": next_path,
				"is_boss": is_boss
			})
	return list


## true si el nivel tiene contenido jugable (ver IMPLEMENTED_LEVELS).
static func is_implemented(path: String) -> bool:
	return IMPLEMENTED_LEVELS.has(path)


## Retorna los 10 niveles correspondientes a un capítulo específico.
static func get_levels_for_chapter(chapter_num: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for lvl_info in get_all_levels():
		if int(lvl_info.get("chapter", 0)) == chapter_num:
			results.append(lvl_info)
	return results


## Obtiene la información de un nivel según su ruta en el proyecto.
static func get_level_by_path(path: String) -> Dictionary:
	for lvl in get_all_levels():
		if str(lvl.get("path", "")) == path:
			return lvl
	return {}


## Retorna la ruta del siguiente nivel para encadenar victorias continuas.
static func get_next_level_path(current_path: String) -> String:
	var info: Dictionary = get_level_by_path(current_path)
	if not info.is_empty():
		return str(info.get("next_path", "res://scenes/hub/base_camp.tscn"))
	return "res://scenes/hub/base_camp.tscn"


## Primer sector de cada mundo que tiene contenido jugable. La Caja los desbloquea todos al entrar.
static func world_entry_paths() -> Array[String]:
	var list: Array[String] = []
	for chap in range(1, TOTAL_CHAPTERS + 1):
		var entry: String = "res://levels/chapter_%d/level_%d_01.tscn" % [chap, chap]
		if is_implemented(entry):
			list.append(entry)
	return list
