extends RefCounted
## Textos de la pantalla de carga: consejos de juego, frases del mundo y fondos por destino.
## Sin class_name: se usa por `preload` desde core/scene_loader.gd. Para sumar un consejo, agregarlo a TIPS.

## Consejos de juego (cabecera "CONSEJO").
const TIPS: Array[String] = [
	"El Bruto Acorazado no salta: subite a una plataforma y castigalo desde arriba.",
	"La runa de Afilado suma daño antes de la armadura: rinde mucho contra blindados.",
	"[R] recarga antes de que se vacíe el cargador. Cambiar de arma cancela la recarga.",
	"Las pociones se usan con los botones laterales del ratón o los casilleros 4 a 6.",
	"Los checkpoints guardan dónde reaparecés si caés en combate.",
	"El Herrero engarza y quita runas de los sockets de tus armas.",
	"Repetir un sector es la forma más rápida de juntar monedas y experiencia.",
	"En Opciones > Accesibilidad podés agrandar la interfaz o activar el filtro para daltonismo.",
	"Con [C] ves la ficha del personaje con el DPS real de tu arma.",
	"La dificultad se cambia en cualquier momento desde Opciones > Juego.",
	"[I] abre la mochila: ahí está todo lo que juntaste en el sector.",
	"[E] interactúa con puertas, cofres, comerciantes y la Caja.",
	"Las arenas cierran el paso hasta que cae la última oleada: no te quedes en el centro.",
	"Los Agentes del Tiempo no sueltan monedas: sueltan cristales de tiempo.",
	"Las puertas del pasillo de la Caja se abren con cristales de tiempo.",
	"Los enemigos de las arenas entran desde fuera de la vista: mirá los bordes de la pantalla.",
	"Un arma cuerpo a cuerpo puede devolver balas si golpeás justo a tiempo.",
	"Si un enemigo te supera, volvé al campamento a mejorar el equipo y probá de nuevo.",
	"Los controles se pueden reasignar en Opciones > Controles.",
	"Vender lo que no usás al comerciante financia el arma que sí vas a usar.",
]

## Frases del mundo (cabecera "DEL ARCHIVO"). Salen de lore.md: no inventar reglas nuevas acá.
const LORE: Array[String] = [
	"Por fuera, la Caja no parece nada. Por dentro es un pasillo negro infinito, lleno de puertas.",
	"Es la misma Caja en todos los mundos. Por eso siempre se puede volver.",
	"Las puertas cercanas a la entrada llevan a los mundos más tranquilos. Las del fondo, no.",
	"Una puerta encendida tiene una luz tenue en el marco. Las apagadas todavía no te esperan.",
	"Los cristales de tiempo no se fabrican ni se compran. Solo los llevan los Agentes.",
	"Los que te persiguen son tu combustible.",
	"Regla de los Agentes del Tiempo: nadie viaja.",
	"Relojes que se atrasan, luces que parpadean, lluvia que cae hacia arriba un segundo: filtraciones.",
	"Cuanto más se usa una Caja, más filtraciones quedan alrededor.",
	"Traje negro, visor opaco, ninguna insignia. Armas que no son de ninguna época.",
	"El Sindicato no sabe qué es la caja negra del hotel. Solo sabe que alguien paga muy bien por ella.",
	"En el presente, los Agentes llegan en helicópteros negros con reflector.",
	"Núcleo encontró su propia Caja bajo su sede, y copió lo que pudo entender.",
	"Caronte no cobra el óbolo. Cobra cristales de tiempo.",
	"Lucifer custodia su Caja hace eones. Nunca tuvo cristales para abrir una puerta.",
]

## Fondos por mundo (capítulo). El sector elige uno por su número; Ciudad de Jano tiene uno por sector.
const WORLD_BACKGROUNDS: Dictionary = {
	1: ["city_street", "city_alley", "city_sewer", "city_houses", "city_dock", "city_hotel", "city_club", "city_rooftop"],
	2: ["meadow", "forest_green", "forest", "castle", "castle_sunset"],
	3: ["hell_plain", "lava_cavern", "demon_citadel"],
	4: ["workshop", "city_night_base", "box_corridor"],
	5: ["box_corridor"],
}
const BG_DIR: String = "res://assets/art/bg/"
const BG_DEFAULT: String = "city"


## Devuelve [cabecera, texto] al azar, con dos consejos por cada frase del mundo.
static func random_line() -> Array[String]:
	if randf() < 0.34:
		return ["DEL ARCHIVO", LORE[randi() % LORE.size()]]
	return ["CONSEJO", TIPS[randi() % TIPS.size()]]


## Ruta del fondo para una escena destino.
static func background_for(path: String) -> String:
	var file: String = path.get_file().get_basename()
	var name: String = BG_DEFAULT
	if file == "base_camp" or file.begins_with("stress"):
		name = "box_corridor"
	elif file == "test_level":
		name = "workshop"
	elif file.begins_with("level_"):
		var parts: PackedStringArray = file.trim_prefix("level_").split("_")
		if parts.size() == 2:
			var list: Array = WORLD_BACKGROUNDS.get(int(parts[0]), []) as Array
			if not list.is_empty():
				name = str(list[(int(parts[1]) - 1) % list.size()])
	return BG_DIR + name + ".jpg"
