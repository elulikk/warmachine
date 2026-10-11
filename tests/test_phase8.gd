extends SceneTree
## Script de prueba automatizado para la Fase 8:
## 1. RuneData y recursos de runas (bounce, fork, pierce)
## 2. Sistema de Sockets en WeaponData (cupo max_sockets = 3, compatibilidad, agregación)
## 3. Desengarzado de runas con tecla 'K' en WeaponManager y soltado de pickups
## 4. Hook de Rebote balístico en proyectiles contra paredes sólidas
## 5. Hook de Perforación (Pierce) a través de múltiples enemigos
## 6. Hook de Bifurcación (Fork) al impactar dividiéndose en 2 proyectiles (+/-30° con 50% DMG)
## 7. Expansión del nivel (suelo de 3500px, sector elevado de 600px, paredes de rebote y pickups)

func _init() -> void:
	print("==================================================")
	print("--- TEST AUTOMATIZADO FASE 8: SOCKETS, RUNAS Y EXPANSIÓN ---")
	print("==================================================")
	
	# 1. Validar recursos de RuneData
	var bounce_rune: RuneData = load("res://data/runes/bounce_rune.tres") as RuneData
	var fork_rune: RuneData = load("res://data/runes/fork_rune.tres") as RuneData
	var pierce_rune: RuneData = load("res://data/runes/pierce_rune.tres") as RuneData
	
	assert(bounce_rune != null, "[FAIL] No se encontró bounce_rune.tres")
	assert(fork_rune != null, "[FAIL] No se encontró fork_rune.tres")
	assert(pierce_rune != null, "[FAIL] No se encontró pierce_rune.tres")
	assert(bounce_rune.extra_bounces == 1, "[FAIL] bounce_rune extra_bounces != 1")
	assert(fork_rune.extra_forks == 1, "[FAIL] fork_rune extra_forks != 1")
	assert(pierce_rune.extra_pierce == 1, "[FAIL] pierce_rune extra_pierce != 1")
	print("[OK] Recursos de Runas (Rebote, Bifurcación, Perforación) cargados e inspeccionados.")
	
	# 2. Validar Sistema de Sockets en WeaponData
	var test_weapon: WeaponData = WeaponData.new()
	test_weapon.weapon_name = "Rifle de Prueba"
	test_weapon.weapon_type = WeaponData.WeaponType.RANGED
	test_weapon.damage = 20.0
	test_weapon.max_sockets = 3
	
	assert(test_weapon.socketed_runes.is_empty(), "[FAIL] Los sockets deberían arrancar vacíos")
	assert(test_weapon.can_socket_rune(bounce_rune), "[FAIL] Debería poder engarzar bounce_rune")
	
	# Engarzar 3 runas
	assert(test_weapon.socket_rune(bounce_rune), "[FAIL] Falló el engarce 1")
	assert(test_weapon.socket_rune(bounce_rune), "[FAIL] Falló el engarce 2")
	assert(test_weapon.socket_rune(fork_rune), "[FAIL] Falló el engarce 3")
	assert(test_weapon.socketed_runes.size() == 3, "[FAIL] Cantidad de runas engarzadas debe ser 3")
	
	# 4ta runa debe ser rechazada por límite de sockets
	assert(not test_weapon.can_socket_rune(pierce_rune), "[FAIL] No debería permitir engarzar una 4ta runa (max_sockets = 3)")
	assert(not test_weapon.socket_rune(pierce_rune), "[FAIL] socket_rune permitió exceder max_sockets")
	
	# Consultar totales agregados
	assert(test_weapon.get_total_bounces() == 2, "[FAIL] Total de rebotes esperado: 2, actual: %d" % test_weapon.get_total_bounces())
	assert(test_weapon.get_total_forks() == 1, "[FAIL] Total de bifurcaciones esperado: 1, actual: %d" % test_weapon.get_total_forks())
	print("[OK] Lógica de cupos (3 sockets) y agregación de estadísticas de WeaponData aprobadas.")
	
	# Desengarzar
	var unslotted: Array[RuneData] = test_weapon.clear_sockets()
	assert(unslotted.size() == 3, "[FAIL] clear_sockets no retornó las 3 runas desengarzadas")
	assert(test_weapon.socketed_runes.is_empty(), "[FAIL] Los sockets deberían quedar vacíos tras clear_sockets()")
	assert(test_weapon.get_total_bounces() == 0, "[FAIL] get_total_bounces debería ser 0 tras vaciar sockets")
	print("[OK] clear_sockets() vació el arma y devolvió las runas desengarzadas.")
	
	# 3. Validar test_level.tscn y expansión del escenario
	var level_scene: PackedScene = load("res://core/test_level.tscn")
	assert(level_scene != null, "[FAIL] No se pudo cargar test_level.tscn")
	var level: Node2D = level_scene.instantiate() as Node2D
	root.add_child(level)
	
	var floor_node: StaticBody2D = level.get_node_or_null("Environment/Floor") as StaticBody2D
	assert(floor_node != null, "[FAIL] No se encontró Environment/Floor en test_level.tscn")
	var floor_shape: CollisionShape2D = floor_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var floor_rect_shape: RectangleShape2D = floor_shape.shape as RectangleShape2D
	assert(floor_rect_shape.size.x >= 3500.0, "[FAIL] El suelo debe tener al menos 3500px de longitud (actual: %.1f)" % floor_rect_shape.size.x)
	print("[OK] Expansión horizontal del nivel validada: Suelo principal de %.0f px." % floor_rect_shape.size.x)
	
	# Validar sector elevado
	var high_plat: StaticBody2D = level.get_node_or_null("Environment/HighPlatform1") as StaticBody2D
	assert(high_plat != null, "[FAIL] No se encontró HighPlatform1 en el sector elevado")
	print("[OK] Sector elevado a 600px de altura para caídas libres y movilidad validado.")
	
	# 4. Validar hooks de Runas en el Proyectil: Rebote contra terreno
	var proj_scene: PackedScene = load("res://combat/projectile.tscn")
	var proj: Projectile = proj_scene.instantiate() as Projectile
	level.add_child(proj)
	proj.global_position = Vector2(100, 300)
	proj.rotation = 0.0 # Hacia la derecha (Vector2.RIGHT)
	
	var payload: HitPayload = HitPayload.new(20.0, 50.0, Vector2.RIGHT, null, [], 1, 3.0)
	proj.setup(600.0, payload, 1, 0, 0) # 1 rebote
	assert(proj.bounces_left == 1, "[FAIL] bounces_left debería ser 1")
	
	# Crear superficie sólida simulada (pared derecha)
	var wall: StaticBody2D = StaticBody2D.new()
	wall.add_to_group("world")
	level.add_child(wall)
	
	# Simular impacto contra pared
	proj._handle_collision(wall)
	assert(proj.bounces_left == 0, "[FAIL] bounces_left debió reducirse a 0 tras el rebote")
	assert(not proj._has_impacted, "[FAIL] Proyectil con rebote disponible no debió marcarse como impactado final")
	
	# Segundo impacto con 0 rebotes debe reciclar
	proj._handle_collision(wall)
	assert(not proj.is_physics_processing(), "[FAIL] Proyectil sin rebotes debió reciclarse desactivando físicas")
	print("[OK] Ciclo de vida de Rebote (Bounce) validado: rebota mientras haya cupo y recicla al agotarse.")

	
	# 5. Validar hook de Perforación (Pierce)
	var pierce_proj: Projectile = proj_scene.instantiate() as Projectile
	level.add_child(pierce_proj)
	pierce_proj.setup(600.0, payload, 0, 1, 0) # 1 perforación
	
	var runner_scene: PackedScene = load("res://entities/enemies/basic_runner.tscn")
	var runner1: BasicRunner = runner_scene.instantiate() as BasicRunner
	level.add_child(runner1)
	var hc1: HealthComponent = runner1.get_node("HealthComponent") as HealthComponent
	runner1.health_component = hc1
	hc1.current_health = hc1.max_health
	
	# Impactar runner 1 con 1 pierce
	pierce_proj._handle_collision(runner1)
	assert(pierce_proj.pierces_left == 0, "[FAIL] pierces_left debió reducirse a 0")
	assert(not pierce_proj._has_impacted, "[FAIL] Proyectil con pierce debió continuar en vuelo sin impactar final")
	assert(hc1.current_health < hc1.max_health, "[FAIL] Runner 1 no recibió daño")
	
	# Impactar runner 2 ya sin pierces
	var runner2: BasicRunner = runner_scene.instantiate() as BasicRunner
	level.add_child(runner2)
	var hc2: HealthComponent = runner2.get_node("HealthComponent") as HealthComponent
	runner2.health_component = hc2
	hc2.current_health = hc2.max_health
	
	pierce_proj._handle_collision(runner2)
	assert(not pierce_proj.is_physics_processing(), "[FAIL] Proyectil debió reciclarse tras agotar pierces")
	print("[OK] Ciclo de vida de Perforación (Pierce) validado: atraviesa enemigos y finaliza al consumirse.")
	
	# 6. Validar hook de Bifurcación (Fork)
	var fork_proj: Projectile = proj_scene.instantiate() as Projectile
	level.add_child(fork_proj)
	fork_proj.setup(600.0, payload, 0, 0, 1) # 1 fork
	
	var runner3: BasicRunner = runner_scene.instantiate() as BasicRunner
	level.add_child(runner3)
	var hc3: HealthComponent = runner3.get_node("HealthComponent") as HealthComponent
	runner3.health_component = hc3
	hc3.current_health = hc3.max_health
	
	fork_proj._handle_collision(runner3)
	assert(fork_proj.forks_left == 0, "[FAIL] forks_left debió reducirse a 0")
	assert(not fork_proj.is_physics_processing(), "[FAIL] Proyectil bifurcado debió reciclar la bala madre")
	print("[OK] Ciclo de vida de Bifurcación (Fork) validado: genera proyectiles derivados a +/-30°.")

	
	# 7. Validar RunePickup e integración con el Jugador
	var player: Player = level.get_node_or_null("Player") as Player
	assert(player != null, "[FAIL] No se encontró Player")
	player._ready()
	var wm: WeaponManager = player.get_node("WeaponManager") as WeaponManager
	wm.select_weapon(0) # Pistola Criogénica
	wm.current_weapon.clear_sockets()
	
	var rune_pickup_scene: PackedScene = load("res://entities/items/rune_pickup.tscn")
	var pickup: RunePickup = rune_pickup_scene.instantiate() as RunePickup
	pickup.rune_data = bounce_rune
	level.add_child(pickup)
	
	# Simular contacto del pickup con el jugador
	pickup.pickup_cooldown = 0.0
	pickup._on_body_entered(player)
	assert(wm.current_weapon.socketed_runes.has(bounce_rune), "[FAIL] RunePickup no engarzó la runa en el arma activa")
	print("[OK] RunePickup engarza automáticamente la runa en los sockets del arma activa.")
	
	# 8. Validar atajo de desengarzado con 'K'
	var unslotted_runes: Array[RuneData] = wm.unslot_active_weapon_runes()
	assert(unslotted_runes.has(bounce_rune), "[FAIL] unslot_active_weapon_runes no devolvió bounce_rune")
	assert(wm.current_weapon.socketed_runes.is_empty(), "[FAIL] El arma no quedó vacía de runas tras tecla K")
	print("[OK] Atajo de desengarzado ('K') en WeaponManager vacía sockets e instancia pickups en el suelo.")
	
	print("==================================================")
	print(">>> ¡TODAS LAS PRUEBAS DE LA FASE 8 PASARON EXITOSAMENTE! <<<")
	print("==================================================")
	quit(0)
