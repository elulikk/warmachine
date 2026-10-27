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
const ResupplyPodScript = preload("res://entities/interactables/resupply_pod.gd")
const EnemySpawnerPodScript = preload("res://entities/interactables/enemy_spawner_pod.gd")

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
		player.invulnerable = true # en las pruebas no se muere
		initial_spawn_position = player.global_position
		if player.stats_manager != null:
			player.stats_manager.coins = 999
			player.stats_manager.coins_changed.emit(999)
			print("[TestLevel / Modo Fruta] 999 monedas asignadas al jugador para pruebas instantáneas.")
	SaveManager.set_respawn_point(initial_spawn_position)
	_spawn_resupply_pods()
	if "--test-aura" in OS.get_cmdline_args():
		_run_test_aura_sequence.call_deferred()


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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U:
		_level_up_player()


func _physics_process(_delta: float) -> void:
	# Detección de caída al vacío si supera los límites inferiores del mapa expandido
	if player != null and player.global_position.y > 900.0:
		respawn_player()


## Pods de vida, munición y granadas junto al inicio, y una placa de daño para probar el de vida.
func _spawn_resupply_pods() -> void:
	var pods: Array = [
		[ResupplyPodScript.Kind.HEALTH, 420.0],
		[ResupplyPodScript.Kind.AMMO, 475.0],
		[ResupplyPodScript.Kind.GEAR, 530.0],
		[ResupplyPodScript.Kind.DRAIN, 585.0],
	]
	for entry: Array in pods:
		var pod: Area2D = ResupplyPodScript.new()
		pod.kind = entry[0]
		pod.position = Vector2(entry[1], 575.0)
		add_child(pod)
	_spawn_enemy_pods()


## Invocadores de enemigos del mundo 1 a la izquierda del inicio ([E] encima), y uno para limpiar en el hub.
func _spawn_enemy_pods() -> void:
	var pods: Array = [
		["Matón", "res://entities/enemies/city_thug.tscn"],
		["Patovica", "res://entities/enemies/city_bouncer.tscn"],
		["Ladrón", "res://entities/enemies/city_thief.tscn"],
		["Asaltante", "res://entities/enemies/city_gunman.tscn"],
		["Sicario", "res://entities/enemies/city_hitman_smg.tscn"],
		["Sicario
de Élite", "res://entities/enemies/city_hitman_elite.tscn"],
		["Rata", "res://entities/enemies/city_rat.tscn"],
		["Rata
de techo", "res://entities/enemies/ceiling_rat.tscn"],
		["Rata Gigante
(jefe)", "res://entities/enemies/giant_rat.tscn"],
	]
	for i: int in pods.size():
		var pod: Area2D = EnemySpawnerPodScript.new()
		pod.label_text = pods[i][0]
		pod.enemy_scene = load(pods[i][1])
		pod.ceiling = pods[i][1].ends_with("ceiling_rat.tscn")
		pod.position = Vector2(-230.0 + 60.0 * float(i), 575.0)
		add_child(pod)
	var clear_pod: Area2D = EnemySpawnerPodScript.new()
	clear_pod.label_text = "Limpiar"
	clear_pod.position = Vector2(960.0, 575.0)
	add_child(clear_pod)
	var banner: Label = Label.new()
	banner.text = "INVOCADORES DE ENEMIGOS — [E] sobre el pod"
	banner.position = Vector2(-250.0, 405.0)
	banner.custom_minimum_size = Vector2(540.0, 0.0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 13)
	banner.add_theme_color_override("font_color", Color(0.85, 0.5, 1.0))
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 3)
	add_child(banner)


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


## Otorga experiencia para subir de nivel de inmediato (para pruebas del aura y progresión).
func _level_up_player() -> void:
	if player != null and player.stats_manager != null:
		player.stats_manager.add_experience(player.stats_manager.exp_to_next_level)
		print("[Debug U] Experiencia otorgada. Nivel actual del jugador: %d" % player.stats_manager.level)


## Secuencia automatizada de validación del aura (solo se ejecuta si se pasa --test-aura).
func _run_test_aura_sequence() -> void:
	print("--- INICIANDO VERIFICACIÓN AUTOMATIZADA DEL AURA DE NIVEL ---")
	await get_tree().create_timer(0.2).timeout
	if player == null or player.stats_manager == null:
		push_error("[TestAura] Player o StatsManager no encontrados")
		return

	# 1. Subida de nivel individual
	print("[TestAura] Paso 1: Subiendo a nivel 2...")
	_level_up_player()
	await get_tree().process_frame

	var aura: Node2D = null
	for child: Node in player.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("level_up_aura.gd"):
			aura = child as Node2D
			break

	if aura != null:
		print("[TestAura OK] Nodo de aura creado exitosamente sobre el jugador: %s" % aura.name)
	else:
		push_error("[TestAura FAIL] No se encontró el nodo del aura sobre el jugador.")
		return

	# 2. Subidas consecutivas rápidas (niveles 3 y 4)
	print("[TestAura] Paso 2: Subidas consecutivas a nivel 3 y 4...")
	await get_tree().create_timer(0.3).timeout
	_level_up_player()
	await get_tree().create_timer(0.1).timeout
	_level_up_player()
	await get_tree().process_frame

	var aura_count: int = 0
	for child: Node in player.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("level_up_aura.gd"):
			aura_count += 1

	if aura_count == 1:
		print("[TestAura OK] Subidas consecutivas validadas: exactamente 1 nodo de aura activo reiniciado.")
	else:
		push_error("[TestAura FAIL] Conteo inesperado de auras activas: %d (debe ser 1)" % aura_count)
		return

	# 3. Esperar que transcurra la duración (2.2s) para verificar auto-eliminación limpia
	print("[TestAura] Paso 3: Esperando desvanecimiento completo del aura (2.4s)...")
	await get_tree().create_timer(2.4).timeout

	var leftover_count: int = 0
	for child: Node in player.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("level_up_aura.gd"):
			leftover_count += 1

	if leftover_count == 0:
		print("[TestAura OK] El aura desapareció por completo sin dejar restos en el árbol de nodos.")
	else:
		push_error("[TestAura FAIL] Quedaron %d nodo(s) colgados tras la finalización." % leftover_count)
		return

	print("==================================================")
	print("--- ¡AURA DE NIVEL VALIDADA CON ÉXITO TOTAL! ---")
	print("==================================================")


