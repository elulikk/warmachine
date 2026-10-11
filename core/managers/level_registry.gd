class_name LevelRegistry
extends RefCounted
## Registro Central de Niveles y Capítulos de la Campaña de Warmachine.
## Mapea las 50 expediciones divididas en 5 capítulos temáticos de 10 niveles cada uno.

const TOTAL_CHAPTERS: int = 5
const LEVELS_PER_CHAPTER: int = 10

## Niveles con contenido real. El resto son esqueletos vacíos y el selector los marca como pendientes.
const IMPLEMENTED_LEVELS: Array[String] = [
	"res://levels/chapter_1/level_1_01.tscn",
	"res://levels/chapter_1/level_1_02.tscn",
	"res://levels/chapter_1/level_1_03.tscn",
	"res://levels/chapter_1/level_1_04.tscn",
	"res://levels/chapter_1/level_1_05.tscn"
]

static var CHAPTER_NAMES: Dictionary = {
	1: "CAPÍTULO 1: PERIFERIA SUBTERRÁNEA",
	2: "CAPÍTULO 2: COMPLEJO INDUSTRIAL",
	3: "CAPÍTULO 3: LABORATORIOS BIOTEC",
	4: "CAPÍTULO 4: CIUDADELA BLINDADA",
	5: "CAPÍTULO 5: NÚCLEO DEL REACTOR"
}

static var CHAPTER_COLORS: Dictionary = {
	1: Color(0.2, 0.65, 0.85, 1.0), # Azul metálico frío
	2: Color(0.9, 0.55, 0.2, 1.0),  # Naranja herrumbre industrial
	3: Color(0.2, 0.85, 0.55, 1.0), # Verde cian biológico
	4: Color(0.85, 0.3, 0.35, 1.0), # Carmesí blindado
	5: Color(0.75, 0.35, 0.95, 1.0) # Púrpura plasma reactor
}


## Genera el listado completo de los 50 niveles con sus metadatos.
static func get_all_levels() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for chap in range(1, TOTAL_CHAPTERS + 1):
		for lvl in range(1, LEVELS_PER_CHAPTER + 1):
			var id_str: String = "%d_%02d" % [chap, lvl]
			var path_str: String = "res://levels/chapter_%d/level_%d_%02d.tscn" % [chap, chap, lvl]
			var is_boss: bool = (lvl == LEVELS_PER_CHAPTER)
			var suffix: String = " [JEFE]" if is_boss else ""
			var name_str: String = "Sector %d-%d%s" % [chap, lvl, suffix]

			var next_path: String = ""
			if lvl < LEVELS_PER_CHAPTER:
				next_path = "res://levels/chapter_%d/level_%d_%02d.tscn" % [chap, chap, lvl + 1]
			elif chap < TOTAL_CHAPTERS:
				next_path = "res://levels/chapter_%d/level_%d_01.tscn" % [chap + 1, chap + 1]
			else:
				next_path = "res://scenes/hub/base_camp.tscn"
			
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
