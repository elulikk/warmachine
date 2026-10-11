class_name TestLevel
extends Node2D
const LevelSkinScript = preload("res://levels/level_skin.gd")
## Controlador de la escena de prueba (Sandbox).
## Administra la posición de reaparición del jugador y los atajos globales de depuración.

const RUNNER_SCENE: PackedScene = preload("res://entities/enemies/basic_runner.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemies/armored_brute.tscn")
const SENTINEL_SCENE: PackedScene = preload("res://entities/enemies/shielded_sentinel.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://entities/enemies/zombie.tscn")
const GHOST_SCENE: PackedScene = preload("res://entities/enemies/ghost.tscn")

## Distancia frente al jugador a la que aparecen los enemigos spawneados por atajo.
const SPAWN_DISTANCE: float = 280.0
const SPAWN_MIN_X: float = -200.0
const SPAWN_MAX_X: float = 5100.0

@onready var player: Player = $Player

var initial_spawn_position: Vector2 = Vector2(350, 575)


func _ready() -> void:
	LevelSkinScript.apply(self, 0)
	GameFeel.music_start_level(self)
	if player != null:
		initial_spawn_position = player.global_position
		if player.stats_manager != null:
			player.stats_manager.coins = 999
			player.stats_manager.coins_changed.emit(999)
			print("[TestLevel / Modo Fruta] 999 monedas asignadas al jugador para pruebas instantáneas.")
	SaveManager.set_respawn_point(initial_spawn_position)


func _unhandled_input(event: InputEvent) -> void:
	# Atajo F3: Teletransportar al jugador a la posición de inicio
	if event.is_action_pressed("debug_respawn"):
		respawn_player()
	elif event.is_action_pressed("debug_spawn_runner"):
		_spawn_enemy(RUNNER_SCENE)
	elif event.is_action_pressed("debug_spawn_brute"):
		_spawn_enemy(BRUTE_SCENE)
	elif event.is_action_pressed("debug_spawn_sentinel"):
		_spawn_enemy(SENTINEL_SCENE)
	elif event.is_action_pressed("debug_spawn_zombie"):
		_spawn_enemy(ZOMBIE_SCENE)
	elif event.is_action_pressed("debug_spawn_ghost"):
		_spawn_enemy(GHOST_SCENE)
	elif event.is_action_pressed("debug_kill_all"):
		_kill_all_enemies()
	elif event.is_action_pressed("debug_heal"):
		_heal_player()


func _physics_process(_delta: float) -> void:
	# Detección de caída al vacío si supera los límites inferiores del mapa expandido
	if player != null and player.global_position.y > 900.0:
		respawn_player()


## Teletransporta al jugador y restaura su vitalidad.
func respawn_player() -> void:
	if player != null:
		player.respawn(initial_spawn_position)
		print("[Debug F3] Jugador reaparecido en la posición inicial (%s)" % initial_spawn_position)


## Permite actualizar la posición de reaparición dinámicamente mediante checkpoints.
func set_respawn_position(pos: Vector2) -> void:
	initial_spawn_position = pos


## Instancia un enemigo frente al jugador (en la dirección hacia la que mira).
func _spawn_enemy(scene: PackedScene) -> void:
	if player == null or scene == null:
		return
	var enemy: Node2D = scene.instantiate() as Node2D
	if enemy == null:
		return
	add_child(enemy)
	var spawn_x: float = player.global_position.x + float(player.facing_direction) * SPAWN_DISTANCE
	enemy.global_position = Vector2(clampf(spawn_x, SPAWN_MIN_X, SPAWN_MAX_X), player.global_position.y - 8.0)


## Elimina a todos los enemigos vivos, salvo las torretas fijas de práctica (parry y sniper).
func _kill_all_enemies() -> void:
	var killed: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if node is TrainingTurret or node is SniperTurret:
			continue
		var hc: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and not hc.is_dead:
			hc.apply_damage(hc.current_health + 1.0)
			killed += 1
	print("[Debug K] %d enemigo(s) eliminados." % killed)


## Restaura la salud del jugador al máximo.
func _heal_player() -> void:
	if player != null and player.stats_manager != null:
		player.stats_manager.heal(player.stats_manager.get_max_health())
		print("[Debug L] Salud del jugador restaurada.")
