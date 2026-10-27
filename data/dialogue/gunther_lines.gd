extends RefCounted
## Frases que Gunther dice solo mientras avanza (solo subtítulo; la voz se agrega después).
## Las lee `levels/gunther_lines.gd`. Cada frase tiene un id: es el nombre del archivo de voz.
##
## VOCES: grabar `assets/voice/gunther/<id>.ogg` (por ejemplo `assets/voice/gunther/rata_1.ogg`).
## Si el archivo existe suena solo, sin tocar código; si no, se ve solo el subtítulo.
##
## Tono: seco, irónico, pocas palabras (ver story.md). Una línea por momento alcanza.

## Por nivel (`level_id` del LevelBase): frases que salen al pasar por un punto, una sola vez por entrada al nivel.
##   "x": sale cuando Gunther pasa ese x (hacia la derecha).
##   "y": sale cuando Gunther sube por encima de ese y (para pisos de la torre). Se pueden combinar los dos.
## Si se arranca desde un checkpoint, las que quedaron atrás no salen.
## "eventos" (opcional) reemplaza las frases de un evento solo en ese nivel (mismas claves que EVENTOS).
const NIVELES: Dictionary = {
	"1_01": {
		"puntos": {
			"calle_inicio": {"x": 320, "text": "Otra noche, otro encargo. Ojalá esta vez paguen."},
			"calle_mensajero": {"x": 4300, "text": "El mensajero corre como si me debiera plata. Y me la debe."},
			"calle_lluvia": {"x": 9200, "text": "Esta ciudad no duerme. Yo tampoco."},
			"calle_arma": {"x": 13900, "text": "Algo para el camino."},
			"calle_mitad": {"x": 18200, "text": "Cuantos más mandan, más cerca estoy."},
			"calle_barrio": {"x": 25400, "text": "Barrio del Sindicato. Se nota en el olor."},
			"calle_final": {"x": 33300, "text": "Una alcantarilla. Claro. Las ratas siempre van para abajo."},
		},
	},
	"1_03": {
		"puntos": {
			"cloaca_inicio": {"x": 260, "text": "Qué olor... y yo con el piloto recién lavado."},
			"cloaca_ratas": {"x": 3600, "text": "Estas ratas están demasiado grandes."},
			"cloaca_filtra": {"x": 7300, "text": "Algo se está filtrando acá abajo. Y no es agua."},
			"cloaca_fondo": {"x": 12900, "text": "Se escucha algo grande ahí adelante."},
		},
		"eventos": {
			"jefe_visto": {"cloaca_jefe": "...Eso no es una rata de acá."},
			"jefe_caido": {"cloaca_flauta": "Linda flauta. Me la quedo."},
		},
	},
	"1_04": {
		"puntos": {
			"torre_inicio": {"x": 300, "text": "Piso por piso, entonces."},
			"torre_piso1": {"y": 200, "text": "Ni un ascensor. Típico del Sindicato."},
			"torre_piso3": {"y": -600, "text": "Cada piso huele más a plata."},
			"torre_thompson": {"x": 880, "y": -900, "text": "Una Thompson. El Sindicato no escatima en máquinas de escribir."},
			"torre_techos": {"x": 4300, "y": -900, "text": "Los techos. Que no se me ocurra mirar para abajo."},
			"torre_azotea": {"x": 10400, "y": -900, "text": "El Patrón está ahí arriba. Lo huelo."},
		},
	},
}

## Al ver por primera vez (en cada nivel) un enemigo de este tipo. La clave es el `entity_name` del enemigo.
## Si hay varias, sale una al azar.
const AL_VER: Dictionary = {
	"Rata": {
		"rata_1": "Malditas ratas.",
		"rata_2": "Ratas. Siempre ratas.",
	},
	"Rata de techo": {
		"rata_techo_1": "¿Ratas en el techo? Esta ciudad está perdida.",
	},
	"Ladrón": {
		"ladron_1": "Un ladrón. En esta ciudad es una profesión respetable.",
		"ladron_2": "Guardá esas manos, pibe.",
	},
	"Asaltante": {
		"asaltante_1": "El Sindicato, siempre ocasionando problemas.",
		"asaltante_2": "Gente del Sindicato. Qué sorpresa.",
	},
	"Sicario": {
		"sicario_1": "Sicarios. Alguien se está poniendo nervioso.",
	},
	"Sicario de Élite": {
		"sicario_elite_1": "Ese no es un matón cualquiera.",
	},
	"Bruto Acorazado": {
		"bruto_1": "Grande. Lento, espero.",
	},
	"Agente del Tiempo": {
		"agente_1": "¿Y estos de dónde salieron?",
		"agente_2": "Esos no son del Sindicato.",
	},
}

## Frases por evento. Sale una al azar (sin repetir la última).
const EVENTOS: Dictionary = {
	"arena_inicio": {
		"arena_inicio_1": "Me encerraron. Error de ellos.",
		"arena_inicio_2": "Bueno. A trabajar.",
		"arena_inicio_3": "Vengan de a uno... o todos juntos, da igual.",
	},
	"arena_limpia": {
		"arena_limpia_1": "Limpio.",
		"arena_limpia_2": "¿Nadie más? Bien.",
		"arena_limpia_3": "Siguiente.",
	},
	"checkpoint": {
		"checkpoint_1": "Un respiro.",
		"checkpoint_2": "Anotado.",
	},
	"vida_baja": {
		"vida_baja_1": "Esto se está poniendo feo.",
		"vida_baja_2": "Necesito un trago. Y un médico.",
		"vida_baja_3": "No es mi mejor noche.",
	},
	"racha": {
		"racha_1": "¿Eso es todo lo que tienen?",
		"racha_2": "Uno menos. Y otro. Y otro.",
		"racha_3": "Fácil.",
	},
	"reaparece": {
		"reaparece_1": "Eso dolió.",
		"reaparece_2": "Otra vez. Con más cuidado.",
	},
	"quieto": {
		"quieto_1": "El caso no se va a cerrar mirando la lluvia.",
		"quieto_2": "La noche no se resuelve sola.",
	},
	"jefe_visto": {
		"jefe_visto_1": "Ese es grande.",
	},
	"jefe_caido": {
		"jefe_caido_1": "Caso cerrado. Bueno, este.",
	},
}

## Por evento: [probabilidad de que hable, segundos mínimos entre dos frases de ese evento].
const REGLAS: Dictionary = {
	"arena_inicio": [0.8, 20.0],
	"arena_limpia": [0.7, 20.0],
	"checkpoint": [0.35, 45.0],
	"vida_baja": [1.0, 40.0],
	"racha": [0.6, 45.0],
	"reaparece": [1.0, 0.0],
	"quieto": [1.0, 90.0],
	"jefe_visto": [1.0, 0.0],
	"jefe_caido": [1.0, 0.0],
}
