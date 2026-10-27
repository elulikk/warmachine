extends Marker2D
## Marcador de spawn de enemigos configurable desde el editor.
## Colócalo como hijo de un WaveManager (o en cualquier lugar del nivel para modo directo).
##
## Modo WaveManager: si el padre directo es un WaveManager, este marcador se registra como
## punto de spawn y también puede agregar su escena/cantidad al gestor de rondas.
## Modo directo: si auto_spawn es true y el nodo NO tiene WaveManager padre,
## instancia los enemigos en su posición al iniciar la escena.

## Escena del enemigo a instanciar. Debe ser BasicRunner o EnemyBase.
@export var enemy_scene: PackedScene = null

## Cuántos enemigos genera este marcador (solo en modo directo con auto_spawn=true,
## o como aportación de cantidad si se usa configure_wave_manager()).
@export_range(1, 50, 1) var count: int = 1

## En qué ronda aparece este grupo (0 = siempre; solo relevante si configure_wave_manager es true).
@export_range(0, 20, 1) var round_index: int = 0

## Si es true y NO hay WaveManager padre, instancia los enemigos directamente al _ready().
@export var auto_spawn: bool = true

## Intervalo en segundos entre spawns consecutivos (modo directo).
@export_range(0.0, 5.0, 0.1) var spawn_interval: float = 0.5

## Segundos de destello antes de que nazca cada enemigo en modo directo (0 = al instante).
@export_range(0.0, 3.0, 0.1) var spawn_warning: float = 1.0

## Si es true, los enemigos nacen ya en estado agresivo.
@export var aggro_on_spawn: bool = false

const SpawnTelegraph := preload("res://combat/spawn_telegraph.gd")

var _parent_wm: WaveManager = null
var _spawn_queue: int = 0


func _ready() -> void:
	var parent: Node = get_parent()
	if parent is WaveManager:
		_parent_wm = parent as WaveManager
		# Registrar este Marker2D como punto de spawn del WaveManager padre
		if not _parent_wm.spawn_points.has(self):
			_parent_wm.spawn_points.append(self)
		# Registrar la escena si el WaveManager no tiene ninguna asignada y nosotros sí
		if enemy_scene != null and _parent_wm.enemy_scene == null:
			_parent_wm.enemy_scene = enemy_scene
		print("[EnemySpawnMarker] Registrado en WaveManager '%s' como punto de spawn." % parent.name)
	elif auto_spawn and enemy_scene != null:
		_spawn_queue = count
		_spawn_next()


func _spawn_next() -> void:
	if _spawn_queue <= 0 or enemy_scene == null:
		return
	if spawn_warning > 0.0:
		SpawnTelegraph.play(_get_container(), global_position, spawn_warning)
		get_tree().create_timer(spawn_warning).timeout.connect(_spawn_now)
		return
	_spawn_now()


func _spawn_now() -> void:
	var instance: Node = enemy_scene.instantiate()
	if not (instance is BasicRunner or instance is EnemyBase):
		push_warning("[EnemySpawnMarker] La escena '%s' no es BasicRunner ni EnemyBase; ignorado." % enemy_scene.resource_path)
		instance.queue_free()
		return

	var enemy: Node2D = instance as Node2D
	enemy.global_position = global_position
	if "is_aggroed" in enemy:
		enemy.set("is_aggroed", aggro_on_spawn)

	_get_container().add_child(enemy)

	_spawn_queue -= 1
	if _spawn_queue > 0:
		get_tree().create_timer(spawn_interval).timeout.connect(_spawn_next)


func _get_container() -> Node:
	var container: Node = get_tree().current_scene
	if container == null:
		container = owner if owner != null else get_parent()
	return container
