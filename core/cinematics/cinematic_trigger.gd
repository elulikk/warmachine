extends Node2D
## Disparador de cinemáticas del presente. Se coloca en el nivel (posición = punto de referencia de la escena).
##   - sin `zone_width` ni `after_arena`: al empezar el nivel;
##   - con `zone_width`: cuando el jugador entra a esa franja horizontal centrada en el nodo;
##   - con `after_arena`: al despejarse esa arena;
##   - con `needs_crystal`: además espera a que el jugador tenga un cristal de tiempo.
## Se reproduce una sola vez por personaje (flag `cine:<id>` del slot).

const PlayerScript = preload("res://core/cinematics/cinematic_player.gd")
const LibraryScript = preload("res://core/cinematics/cinematic_library.gd")

@export var cinematic_id: String = ""
@export var zone_width: float = 0.0
@export var after_arena: NodePath = NodePath("")
@export var needs_crystal: bool = false
@export var start_delay: float = 0.8

var _fired: bool = false
var _armed: bool = false


func _ready() -> void:
	if _already_seen():
		_fired = true
		set_process(false)
		return
	if not after_arena.is_empty():
		var arena: Node = get_node_or_null(after_arena)
		if arena != null and arena.has_signal(&"encounter_cleared"):
			arena.connect(&"encounter_cleared", _fire_after_delay)
		set_process(false)
		return
	if zone_width <= 0.0 and not needs_crystal:
		set_process(false)
		_fire_after_delay()
		return
	_armed = true


func _process(_delta: float) -> void:
	if _fired or not _armed or PlayerScript.active:
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	if zone_width > 0.0 and absf(player.global_position.x - global_position.x) > zone_width * 0.5:
		return
	if needs_crystal:
		var stats: Variant = player.get("stats_manager")
		if stats == null or int(stats.get("time_crystals")) <= 0:
			return
	_fire()


func _fire_after_delay() -> void:
	if _fired:
		return
	await get_tree().create_timer(start_delay).timeout
	_fire()


func _fire() -> void:
	if _fired or PlayerScript.active:
		return
	_fired = true
	var level: Node = get_tree().current_scene
	var steps: Array = LibraryScript.steps(cinematic_id, global_position, level)
	if steps.is_empty():
		return
	SaveManager.set_world_flag("cine:" + cinematic_id)
	PlayerScript.play(self, steps)


func _already_seen() -> bool:
	return SaveManager.has_world_flag("cine:" + cinematic_id)
