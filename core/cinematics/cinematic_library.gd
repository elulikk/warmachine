extends RefCounted
## Cinemáticas del presente (Mundo 1). Textos de `story.md`, secciones 4 y 5. Sin class_name: se usa por `preload`.
## `steps(id, origin, level)` devuelve la lista de pasos que entiende `cinematic_player.gd`.
## `origin` es la posición del disparador (los actores y la cámara se ubican respecto de ahí).

const TIME_AGENT_SCENE: String = "res://entities/enemies/time_agent.tscn"
const CORRIDOR_NEXT: String = "res://scenes/hub/base_camp.tscn"


static func say(who: String, text: String, thought: bool = false, seconds: float = -1.0) -> Dictionary:
	var step: Dictionary = {"t": "say", "who": who, "text": text, "thought": thought}
	if seconds > 0.0:
		step["s"] = seconds
	return step


static func steps(id: String, origin: Vector2, level: Node) -> Array:
	match id:
		"p1_detonator":
			return _p1_detonator(origin)
		"p3_leak":
			return [
				{"t": "focus", "id": "player", "zoom": 1.25, "s": 0.6},
				say("GUNTHER", "Esto no lo fabricó nadie de acá.", false, 3.2),
				{"t": "release", "s": 0.5},
			]
		"p5_helicopter":
			return _p5_helicopter(origin, level)
		"p5_crystal":
			return [
				{"t": "focus", "id": "player", "zoom": 1.25, "s": 0.5},
				say("GUNTHER", "Ni plata, ni documentos. Una piedra que brilla. ¿Qué son ustedes?", false, 4.0),
				{"t": "release", "s": 0.5},
			]
		"p5_stevedore":
			return [
				{"t": "focus", "pos": origin + Vector2(0, -50), "zoom": 1.3, "s": 0.8},
				say("ESTIBADOR", "Bajaron una caja negra del barco... se la llevaron al hotel. Nadie pudo abrirla."),
				say("GUNTHER", "Al hotel. Entonces ahí es donde termina esto.", true),
				{"t": "release", "s": 0.6},
			]
		"p7_boss":
			return [
				say("JEFE DEL SINDICATO", "Un detective. En mi club. Que alguien suba a la azotea y no deje que nadie toque la mercadería."),
				say("GUNTHER", "Mercadería. Así que la venden."),
			]
		"p8_box":
			return [
				{"t": "focus", "pos": origin + Vector2(0, -90), "zoom": 1.25, "s": 1.0},
				{"t": "wait", "s": 0.6},
				say("GUNTHER", "Una caja negra en una azotea. Doce años para esto."),
				{"t": "release", "s": 0.6},
			]
		"p8_after":
			return _p8_after(origin)
	return []


static func _p1_detonator(origin: Vector2) -> Array:
	var ground: float = origin.y
	return [
		{"t": "focus", "pos": origin + Vector2(340, -70), "zoom": 1.2, "s": 1.0},
		{"t": "spawn", "id": "agent", "file": "time_agent.png", "pos": Vector2(origin.x + 480.0, ground), "h": 66.0},
		say("GUNTHER", "Otra noche de lluvia, otro marido que no vuelve a casa.", true, 3.4),
		say("GUNTHER", "...Ese equipo. Lo vi una sola vez en mi vida.", true, 3.2),
		say("GUNTHER", "¡Eh! ¡Soltalo!", false, 2.0),
		{"t": "shake", "amp": 3.0, "s": 0.25},
		{"t": "par", "steps": [
			{"t": "move", "id": "agent", "to": Vector2(origin.x + 1500.0, ground), "s": 1.6},
			say("GUNTHER", "Doce años esperando una pista. No se me va a escapar.", true, 3.4),
		]},
		{"t": "remove", "id": "agent"},
		{"t": "release", "s": 0.6},
	]


static func _p5_helicopter(origin: Vector2, level: Node) -> Array:
	var ground: float = origin.y
	var spawn_fn: Callable = func() -> void:
		if level == null or not is_instance_valid(level):
			return
		var scene: PackedScene = load(TIME_AGENT_SCENE) as PackedScene
		if scene == null:
			return
		for dx: float in [-80.0, 0.0, 90.0]:
			var agent: Node2D = scene.instantiate() as Node2D
			agent.global_position = Vector2(origin.x + 340.0 + dx, ground - 4.0)
			level.add_child(agent)
	return [
		{"t": "focus", "pos": origin + Vector2(330, -120), "zoom": 1.1, "s": 0.8},
		{"t": "spawn", "id": "heli", "file": "helicopter.png", "pos": Vector2(origin.x - 380.0, ground - 330.0), "h": 150.0, "flip": true},
		{"t": "par", "steps": [
			{"t": "move", "id": "heli", "to": Vector2(origin.x + 340.0, ground - 250.0), "s": 2.4},
			{"t": "shake", "amp": 2.0, "s": 2.2},
		]},
		say("GUNTHER", "Bueno. Ahora vinieron a buscarme a mí.", false, 3.0),
		{"t": "call", "fn": spawn_fn},
		{"t": "wait", "s": 0.6},
		{"t": "move", "id": "heli", "to": Vector2(origin.x + 1700.0, ground - 420.0), "s": 2.0},
		{"t": "remove", "id": "heli"},
		{"t": "release", "s": 0.6},
	]


static func _p8_after(origin: Vector2) -> Array:
	var ground: float = origin.y
	return [
		{"t": "focus", "pos": origin + Vector2(0, -90), "zoom": 1.25, "s": 0.8},
		{"t": "spawn", "id": "agent", "file": "time_agent.png", "pos": Vector2(origin.x - 380.0, ground), "h": 66.0, "flip": false},
		{"t": "move", "id": "agent", "to": Vector2(origin.x - 90.0, ground), "s": 1.6},
		{"t": "sfx", "name": "coin"},
		{"t": "box", "state": "open"},
		{"t": "flash", "s": 0.4},
		say("AGENTE", "No tendrías que haber visto nada. Igual que tu compañero.", false, 4.2),
		{"t": "move", "id": "agent", "to": Vector2(origin.x, ground), "s": 0.7},
		{"t": "remove", "id": "agent"},
		{"t": "shake", "amp": 4.0, "s": 0.4},
		{"t": "move", "id": "player", "to": Vector2(origin.x - 20.0, ground - 4.0), "s": 0.9},
		{"t": "fade", "to": 1.0, "s": 0.7},
		{"t": "box", "state": "closed"},
		{"t": "bg", "file": "box_corridor.jpg"},
		{"t": "fade", "to": 0.0, "s": 1.4},
		{"t": "wait", "s": 1.2},
		{"t": "show", "id": "agent", "file": "time_agent.png", "x": 0.5, "y": 0.62, "h": 0.2},
		{"t": "wait", "s": 1.6},
		{"t": "hide", "id": "agent"},
		say("GUNTHER", "...Dijo \"igual que tu compañero\".", true, 3.4),
		say("GUNTHER", "Muy bien. Sigamos el rastro.", false, 3.0),
		{"t": "fade", "to": 1.0, "s": 1.0},
		{"t": "call", "fn": _save_progress},
		{"t": "goto", "path": CORRIDOR_NEXT},
	]


static func _save_progress() -> void:
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		for path: String in LevelRegistry.world_entry_paths():
			if not sm.unlocked_levels.has(path):
				sm.unlocked_levels.append(path)
		sm.save_to_disk()
