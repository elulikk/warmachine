class_name WaveManager
extends Node
## Gestor de oleadas.
## Modo continuo (por defecto, sandbox): mantiene hasta `max_alive` enemigos activos y genera
## el siguiente tras `respawn_delay` segundos desde la eliminación de uno.
## Modo rondas (`round_sizes` no vacío): lanza rondas de tamaño fijo con descanso entre ellas
## y emite `all_rounds_cleared` al eliminar a todos los enemigos de la última.

signal round_started(round_number: int, enemy_count: int)
signal round_cleared(round_number: int)
signal all_rounds_cleared

const SpawnTelegraph := preload("res://combat/spawn_telegraph.gd")

## Escena del enemigo a instanciar (por defecto basic_runner.tscn).
@export var enemy_scene: PackedScene = preload("res://entities/enemies/basic_runner.tscn")

## Marcadores espaciales de spawn ubicados en los extremos del mapa.
@export var spawn_points: Array[Marker2D] = []

## Tiempo de espera entre la muerte de un enemigo y el spawn del siguiente (modo continuo).
@export var respawn_delay: float = 2.0

## Cantidad máxima de enemigos simultáneos (modo continuo).
@export var max_alive: int = 1

## Separación entre spawns consecutivos mientras se rellena o se lanza una ronda.
@export var refill_interval: float = 0.6

## Dispersión horizontal aleatoria (px) para que los enemigos no nazcan apilados.
@export var spawn_jitter: float = 30.0

## Segundos de destello en el punto de nacimiento antes de que aparezca cada enemigo (0 = al instante).
@export var spawn_warning: float = 1.0

@export_group("Rondas")
## Tamaño de cada ronda (ej: [3, 4, 6]). Vacío = modo continuo.
@export var round_sizes: Array[int] = []

## Segundos de descanso entre el final de una ronda y el inicio de la siguiente.
@export var rest_between_rounds: float = 4.0

## Si es true arranca solo al cargar; si es false hay que llamar a start().
@export var auto_start: bool = true

## Si es true los enemigos nacen en estado de persecución (sin esperar al aggro por distancia).
@export var aggro_on_spawn: bool = false

## Enemigo especial de las rondas (ej: ArmoredBrute). Puede ser cualquier `BasicRunner` o `EnemyBase`.
@export var elite_scene: PackedScene = null

## Cuántos enemigos de cada ronda son `elite_scene` (parejo con `round_sizes`; cuentan dentro del
## tamaño de la ronda y salen primero). Vacío o 0 = ronda solo de `enemy_scene`.
@export var elite_per_round: Array[int] = []

var alive_enemies: Array[Node] = []
var respawn_timer: Timer = null
var rest_timer: Timer = null
var defeated_counter: int = 0
var current_round: int = 0

var _round_index: int = -1
var _pending_spawns: int = 0
var _pending_elites: int = 0
var _rounds_active: bool = false
var _in_flight: int = 0       # Destellos mostrados cuyo enemigo todavía no nació
var _generation: int = 0      # Sube en stop_and_clear para descartar destellos viejos


func _ready() -> void:
	# Descubrir puntos de spawn hijos si no se asignaron en el inspector
	if spawn_points.is_empty():
		for child in get_children():
			if child is Marker2D:
				spawn_points.append(child as Marker2D)

	# Configurar el temporizador de reaparición / lanzamiento escalonado
	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.wait_time = respawn_delay
	respawn_timer.timeout.connect(_on_respawn_timeout)
	add_child(respawn_timer)

	# Temporizador de descanso entre rondas
	rest_timer = Timer.new()
	rest_timer.one_shot = true
	rest_timer.timeout.connect(_on_rest_timeout)
	add_child(rest_timer)

	if auto_start:
		get_tree().create_timer(0.6).timeout.connect(start)


## Indica si el gestor trabaja por rondas de tamaño fijo.
func is_rounds_mode() -> bool:
	return not round_sizes.is_empty()


## Inicia las oleadas (primer spawn continuo o primera ronda).
func start() -> void:
	if _rounds_active:
		return
	if is_rounds_mode():
		_begin_round(0)
	else:
		_on_respawn_timeout()


## Detiene las oleadas y elimina a los enemigos vivos (ej: tras la derrota del jugador).
func stop_and_clear() -> void:
	_rounds_active = false
	_pending_spawns = 0
	_pending_elites = 0
	_round_index = -1
	current_round = 0
	_in_flight = 0
	_generation += 1
	if respawn_timer != null:
		respawn_timer.stop()
	if rest_timer != null:
		rest_timer.stop()
	for enemy in alive_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	alive_enemies.clear()


## Genera un nuevo enemigo en un punto de spawn aleatorio (modo continuo).
func spawn_enemy() -> void:
	_prune_invalid_enemies()
	if alive_enemies.size() + _in_flight >= max_alive:
		return
	_spawn_one()


## Elige un punto de spawn y genera un enemigo ahí. Retorna false si no pudo generarlo.
## Con `use_elite` genera `elite_scene` (si está asignada) en lugar de `enemy_scene`.
## Si `spawn_warning` > 0 muestra primero un destello y el enemigo nace cuando termina.
func _spawn_one(use_elite: bool = false) -> bool:
	var scene: PackedScene = elite_scene if use_elite and elite_scene != null else enemy_scene
	if scene == null or spawn_points.is_empty():
		return false

	var chosen_marker: Marker2D = spawn_points.pick_random()
	var spawn_pos: Vector2 = chosen_marker.global_position
	spawn_pos.x += randf_range(-spawn_jitter, spawn_jitter)

	if spawn_warning <= 0.0:
		return _instantiate_enemy(scene, spawn_pos)

	SpawnTelegraph.play(_get_container(), spawn_pos, spawn_warning)
	_in_flight += 1
	get_tree().create_timer(spawn_warning).timeout.connect(_on_telegraph_finished.bind(scene, spawn_pos, _generation))
	return true


func _on_telegraph_finished(scene: PackedScene, spawn_pos: Vector2, generation: int) -> void:
	if generation != _generation:
		return # El gestor se detuvo mientras se mostraba el destello
	_in_flight -= 1
	if not _instantiate_enemy(scene, spawn_pos):
		push_warning("[WaveManager] No se pudo generar un enemigo tras el destello.")
	_check_round_cleared()


func _get_container() -> Node:
	var container: Node = get_tree().current_scene
	if container == null:
		container = owner if owner != null else get_parent()
	if container == null:
		container = get_tree().root
	return container


## Crea el enemigo en `spawn_pos` y lo agrega al nivel. Retorna false si la escena no es un enemigo válido.
func _instantiate_enemy(scene: PackedScene, spawn_pos: Vector2) -> bool:
	var enemy_instance: Node = scene.instantiate()
	if not (enemy_instance is BasicRunner or enemy_instance is EnemyBase):
		enemy_instance.queue_free()
		return false

	var enemy: Node2D = enemy_instance as Node2D
	enemy.global_position = spawn_pos
	if "is_aggroed" in enemy:
		enemy.set("is_aggroed", aggro_on_spawn)
	enemy.connect(&"died", _on_enemy_died.bind(enemy))
	alive_enemies.append(enemy)
	_get_container().add_child(enemy)
	return true


func _prune_invalid_enemies() -> void:
	for i in range(alive_enemies.size() - 1, -1, -1):
		if not is_instance_valid(alive_enemies[i]):
			alive_enemies.remove_at(i)


func _begin_round(index: int) -> void:
	_rounds_active = true
	_round_index = index
	current_round = index + 1
	_pending_spawns = round_sizes[index]
	_pending_elites = 0
	if index < elite_per_round.size():
		_pending_elites = clampi(elite_per_round[index], 0, _pending_spawns)
	round_started.emit(current_round, _pending_spawns)
	print("[WaveManager] Ronda %d/%d: %d enemigos." % [current_round, round_sizes.size(), _pending_spawns])
	_spawn_pending()


## Genera de a un enemigo de la ronda, escalonados por `refill_interval`.
func _spawn_pending() -> void:
	if not _rounds_active or _pending_spawns <= 0:
		return

	var spawn_elite: bool = _pending_elites > 0
	if not _spawn_one(spawn_elite):
		push_warning("[WaveManager] No se pudo generar un enemigo de la ronda (¿faltan spawn_points?).")
		_pending_spawns = 0
		_pending_elites = 0
		_check_round_cleared()
		return

	if spawn_elite:
		_pending_elites -= 1
	_pending_spawns -= 1
	if _pending_spawns > 0:
		respawn_timer.start(refill_interval)


func _check_round_cleared() -> void:
	_prune_invalid_enemies()
	if not _rounds_active or _pending_spawns > 0 or _in_flight > 0 or not alive_enemies.is_empty():
		return

	_rounds_active = false
	round_cleared.emit(current_round)
	print("[WaveManager] Ronda %d superada." % current_round)

	if _round_index + 1 < round_sizes.size():
		rest_timer.start(maxf(rest_between_rounds, 0.01))
	else:
		all_rounds_cleared.emit()
		print("[WaveManager] ¡Todas las rondas superadas!")


func _on_enemy_died(enemy: Node) -> void:
	defeated_counter += 1
	alive_enemies.erase(enemy)

	if _rounds_active:
		_check_round_cleared()
		return

	if respawn_timer.is_stopped():
		respawn_timer.start(respawn_delay)


func _on_respawn_timeout() -> void:
	if _rounds_active:
		_spawn_pending()
		return

	if is_rounds_mode():
		return

	spawn_enemy()
	_prune_invalid_enemies()
	if alive_enemies.size() + _in_flight < max_alive and respawn_timer.is_stopped():
		respawn_timer.start(refill_interval)


func _on_rest_timeout() -> void:
	_begin_round(_round_index + 1)
