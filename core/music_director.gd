extends Node
## Director de música dinámica de un nivel.
## Cada pocas décimas de segundo revisa los enemigos hostiles cercanos al jugador y pide a Music
## la pista de combate, élite o jefe; al terminar la pelea espera unos segundos antes de volver
## a la música de exploración (para que no parpadee entre pistas).
## Sin class_name a propósito: lo instancia GameFeel.music_start_level().
##
## Prioridad: jefe (grupo `boss`) > élite (ArmoredBrute, ShieldedSentinel) > combate.

const MusicScript = preload("res://core/music.gd")

## Cada cuánto se revisa el campo de batalla (s).
const CHECK_INTERVAL: float = 0.35
## Distancia máxima (px) a la que un enemigo cuenta como amenaza.
const THREAT_RANGE: float = 700.0
## Segundos que se mantiene la música de combate tras ver al último enemigo.
const HOLD_SECONDS: float = 4.5

var _check_timer: float = 0.0
var _hold_left: float = 0.0


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CHECK_INTERVAL

	var found: StringName = _detect_threat()
	if found != &"":
		_hold_left = HOLD_SECONDS
		MusicScript.set_situation(self, found)
	elif _hold_left > 0.0:
		_hold_left -= CHECK_INTERVAL
		if _hold_left <= 0.0:
			MusicScript.set_situation(self, &"")


## Devuelve &"boss", &"elite", &"combat" o vacío según los enemigos activos cerca del jugador.
func _detect_threat() -> StringName:
	var tree: SceneTree = get_tree()
	if tree == null:
		return &""
	var player: Node2D = tree.get_first_node_in_group(&"player") as Node2D
	if player == null:
		return &""

	var result: StringName = &""
	for node: Node in tree.get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if enemy.get(&"is_dead") == true:
			continue
		if enemy.global_position.distance_to(player.global_position) > THREAT_RANGE:
			continue
		# Un enemigo que todavía no te vio no cuenta como combate
		if "is_aggroed" in enemy and enemy.get(&"is_aggroed") != true:
			continue
		if enemy.is_in_group(&"boss"):
			return &"boss"
		if _is_elite(enemy):
			result = &"elite"
		elif result == &"":
			result = &"combat"
	return result


## Élite por nombre de clase global. No se usa `is ArmoredBrute`: esas clases extienden EnemyBase, que a su vez
## depende de GameFeel -> este script, y la referencia directa forma un ciclo que impide compilar a ambos enemigos.
func _is_elite(enemy: Node) -> bool:
	var script: Script = enemy.get_script() as Script
	while script != null:
		var global_name: StringName = script.get_global_name()
		if global_name == &"ArmoredBrute" or global_name == &"ShieldedSentinel":
			return true
		script = script.get_base_script()
	return false
