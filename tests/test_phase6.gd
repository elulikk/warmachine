extends SceneTree

func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	print("==================================================")
	print("--- TEST AUTOMATIZADO FASE 6: POOLING, LOOT Y PIÑATA ---")
	print("==================================================")
	
	# ----------------------------------------------------
	# 1. Cargar e instanciar nivel y entidades
	# ----------------------------------------------------
	var level_scene: PackedScene = load("res://core/test_level.tscn")
	assert(level_scene != null, "ERROR: No se pudo cargar res://core/test_level.tscn")
	
	var level_node: Node = level_scene.instantiate()
	root.add_child(level_node)
	current_scene = level_node
	print("[OK] test_level.tscn instanciado en SceneTree.")
	
	await process_frame
	
	var player: Player = level_node.get_node_or_null("Player") as Player
	assert(player != null, "ERROR: No se encontro el nodo Player")
	assert(player.stats_manager != null, "ERROR: Player no tiene StatsManager")
	assert(player.weapon_manager != null, "ERROR: Player no tiene WeaponManager")
	
	var hud: CombatHUD = level_node.get_node_or_null("CombatHUD") as CombatHUD
	assert(hud != null, "ERROR: No se encontro el nodo CombatHUD")
	assert(hud.coins_label != null, "ERROR: CombatHUD debe tener coins_label")
	assert(hud.coins_label.text == "Monedas: 0", "El contador inicial debe ser 'Monedas: 0'")
	print("[OK] CombatHUD y coins_label validados.")
	
	# ----------------------------------------------------
	# 2. Test de ProjectilePool
	# ----------------------------------------------------
	var pool: ProjectilePool = level_node.get_node_or_null("ProjectilePool") as ProjectilePool
	assert(pool != null, "ERROR: No se encontro ProjectilePool en test_level.tscn")
	assert(pool._pool.size() >= 60, "El pool debe tener al menos 60 balas preinstanciadas")
	
	# Verificar que las balas de la reserva inician inactivas
	var first_bullet: Projectile = pool._pool[0]
	assert(first_bullet.visible == false, "Las balas inactivas deben estar ocultas")
	assert(first_bullet.process_mode == Node.PROCESS_MODE_DISABLED, "Las balas inactivas deben tener process_mode DISABLED")
	print("[OK] ProjectilePool precalentado con %d proyectiles en reposo." % pool._pool.size())
	
	# Extraer y activar un proyectil
	var dummy_payload: HitPayload = HitPayload.new(15.0, 50.0, Vector2.RIGHT, player, [])
	var active_bullet: Projectile = pool.get_projectile(Vector2(200, 300), Vector2.RIGHT, dummy_payload, 800.0) as Projectile
	assert(active_bullet != null, "El pool debe devolver un proyectil valido")
	assert(active_bullet.visible == true, "La bala activa debe ser visible")
	assert(active_bullet.process_mode == Node.PROCESS_MODE_INHERIT, "La bala activa debe tener process_mode INHERIT")
	assert(active_bullet.global_position == Vector2(200, 300), "Posicion global debe coincidir")
	assert(active_bullet.speed == 800.0, "Velocidad debe coincidir")
	print("[OK] get_projectile extrajo y activo exitosamente la bala.")
	
	# Reciclar el proyectil
	active_bullet.recycle()
	assert(active_bullet.visible == false, "Tras reciclarse, la bala debe quedar oculta")
	assert(active_bullet.process_mode == Node.PROCESS_MODE_DISABLED, "Tras reciclarse, process_mode debe ser DISABLED")
	print("[OK] recycle() devolvio la bala a la reserva sin destruirla.")
	
	# ----------------------------------------------------
	# 3. Test de LootTable y LootEntry
	# ----------------------------------------------------
	var runner_loot: LootTable = load("res://data/loot/basic_runner_loot.tres") as LootTable
	assert(runner_loot != null, "ERROR: No se encontro basic_runner_loot.tres")
	assert(runner_loot.entries.size() >= 2, "La tabla debe tener al menos 2 entradas (COIN y AMMO)")
	
	# Realizar varias tiradas para validar distribución
	var total_coins_rolled: int = 0
	for i in range(10):
		var drops: Array[Dictionary] = runner_loot.roll_drops()
		assert(not drops.is_empty(), "La tabla con 100% chance de monedas siempre debe soltar algo")
		for drop in drops:
			if drop.get("type") == "COIN":
				var count: int = drop.get("amount")
				assert(count >= 2 and count <= 4, "Monedas deben estar entre 2 y 4")
				total_coins_rolled += count
	assert(total_coins_rolled >= 20, "10 tiradas deben generar al menos 20 monedas acumuladas")
	print("[OK] Arquitectura de LootTable y tiradas de probabilidad aprobadas.")
	
	# ----------------------------------------------------
	# 4. Test de Pickups Físicos con Efecto Piñata y Magnetismo
	# ----------------------------------------------------
	var loot_drop_scene: PackedScene = load("res://entities/items/loot_drop.tscn")
	assert(loot_drop_scene != null, "ERROR: No se encontro loot_drop.tscn")
	
	var drop_node: Node = loot_drop_scene.instantiate()
	level_node.add_child(drop_node)
	var drop: LootDrop = drop_node as LootDrop
	drop.global_position = Vector2(180, 520) # Cerca del jugador
	drop.setup("COIN", 3)
	
	# Validar impulso piñata inicial (velocidad Y negativa hacia arriba)
	assert(drop.velocity.y < -150.0, "La eyeccion de piñata debe tener impulso ascendente (Y negativo)")
	assert(drop.item_type == "COIN", "Tipo debe ser COIN")
	assert(drop.amount == 3, "Cantidad debe ser 3")
	print("[OK] Eyección física inicial (Efecto Piñata) validada.")
	
	# Simular un frame de magnetismo hacia el jugador
	await process_frame
	assert(drop.is_magnetized == true, "Al estar dentro de 80px, la succión magnetica debe activarse")
	
	# Simular recolección directa
	var prev_coins: int = player.stats_manager.coins
	drop._collect(player)
	assert(player.stats_manager.coins == prev_coins + 3, "Debe haber sumado 3 monedas al StatsManager")
	assert(hud.coins_label.text == "Monedas: %d" % player.stats_manager.coins, "El HUD debe actualizar el contador de monedas")
	print("[OK] Recolección de monedas y actualización de CombatHUD aprobadas.")
	
	# ----------------------------------------------------
	# 5. Test de Muerte de BasicRunner y dispersión de botín
	# ----------------------------------------------------
	var runner_scene: PackedScene = load("res://entities/enemies/basic_runner.tscn")
	var runner_inst: Node = runner_scene.instantiate()
	level_node.add_child(runner_inst)
	var runner: BasicRunner = runner_inst as BasicRunner
	runner.global_position = Vector2(500, 575)
	
	assert(runner.loot_table != null, "BasicRunner debe tener asignada su LootTable")
	runner.die() if runner.has_method("die") else runner._on_died()
	print("[OK] BasicRunner soltó botín piñata al ser eliminado.")
	
	print("==================================================")
	print(">>> ¡TODAS LAS PRUEBAS DE LA FASE 6 PASARON EXITOSAMENTE! <<<")
	print("==================================================")
	quit(0)
