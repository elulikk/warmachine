extends SceneTree

func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	print("========================================")
	print("--- TEST AUTOMATIZADO FASE 4: STATS, HUD, ITEMS ---")
	print("========================================")
	
	# 1. Cargar e instanciar test_level.tscn
	var level_scene: PackedScene = load("res://core/test_level.tscn")
	assert(level_scene != null, "ERROR: No se pudo cargar res://core/test_level.tscn")
	
	var level_node: Node = level_scene.instantiate()
	root.add_child(level_node)
	current_scene = level_node
	print("[OK] test_level.tscn instanciado correctamente en SceneTree.")
	
	# Esperar un frame de procesamiento para que se ejecuten _ready() de todos los nodos
	await process_frame
	
	# 2. Localizar nodos clave
	var player: Player = level_node.get_node_or_null("Player") as Player
	assert(player != null, "ERROR: No se encontro el nodo Player")
	assert(player.stats_manager != null, "ERROR: Player no tiene StatsManager")
	
	var hud: CombatHUD = level_node.get_node_or_null("CombatHUD") as CombatHUD
	assert(hud != null, "ERROR: No se encontro el nodo CombatHUD")
	
	# Asegurar vinculación completa con el jugador
	hud.setup_with_player(player)
	
	var stats: StatsManager = player.stats_manager
	print("[Stats Iniciales] Nivel: %d | Vida: %.1f / %.1f | Vel: %.1f | Saltos Max: %d" % [
		stats.level, stats.current_health, stats.get_max_health(), stats.get_move_speed(), stats.get_max_jumps()
	])
	assert(stats.level == 1, "Level inicial debe ser 1")
	assert(stats.get_move_speed() == 240.0, "Velocidad inicial debe ser 240.0")
	assert(stats.get_max_jumps() == 1, "Saltos iniciales debe ser 1")
	assert(hud.level_label.text == "LVL 1", "HUD level_label debe decir 'LVL 1'")
	assert(hud.weapon_label.text.contains("Pistola"), "HUD weapon_label debe indicar Pistola")
	print("[OK] Verificacion de valores iniciales en StatsManager y CombatHUD aprobada.")
	
	# Restaurar vida para pruebas limpias
	stats.current_health = stats.get_max_health()
	hud._on_health_changed(stats.current_health, stats.get_max_health())
	
	# 3. Test de Pickups: Botas (+60 move_speed)
	var speed_boots: ItemData = load("res://data/items/speed_boots.tres")
	assert(speed_boots != null, "ERROR: No se pudo cargar speed_boots.tres")
	speed_boots.apply_to_stats(stats)
	print("[Post-Botas] Velocidad calculada: %.1f" % stats.get_move_speed())
	assert(stats.get_move_speed() == 300.0, "Velocidad tras botas debe ser 300.0 (240 + 60)")
	assert(player.get_current_move_speed() == 300.0, "player.get_current_move_speed() debe reflejar 300.0")
	print("[OK] Test de Modificador Plano de Velocidad (+60) aprobado.")
	
	# 4. Test de Pickups: Pluma (+1 Salto aereo / Doble Salto)
	var jump_feather: ItemData = load("res://data/items/jump_feather.tres")
	assert(jump_feather != null, "ERROR: No se pudo cargar jump_feather.tres")
	jump_feather.apply_to_stats(stats)
	player.reset_jumps()
	print("[Post-Pluma] Saltos maximos: %d | Jumps left: %d" % [stats.get_max_jumps(), player.jumps_left])
	assert(stats.get_max_jumps() == 2, "Saltos maximos debe ser 2")
	assert(player.jumps_left == 2, "jumps_left debe reiniciarse a 2 en el suelo")
	
	# Simular primer salto desde el suelo
	player.execute_jump()
	assert(player.jumps_left == 1, "Tras el primer salto debe quedar 1 salto disponible")
	assert(player.can_air_jump() == true, "can_air_jump() debe ser true al tener doble salto disponible")
	player.execute_jump()
	assert(player.jumps_left == 0, "Tras el segundo salto debe quedar 0 saltos")
	assert(player.can_air_jump() == false, "can_air_jump() debe ser false")
	print("[OK] Test de Mecanica de Doble Salto dinámico aprobado.")
	
	# 5. Test de Recepción de Daño y Actualización de HUD
	stats.take_damage(25.0)
	print("[Post-Daño] Salud actual: %.1f / %.1f" % [stats.current_health, stats.get_max_health()])
	assert(stats.current_health == 75.0, "Salud tras daño debe ser 75.0")
	assert(hud.health_bar.value == 75.0, "HUD health_bar debe reflejar 75.0")
	print("[OK] Test de Daño y sincronización con HealthBar en HUD aprobado.")
	
	# 6. Test de Experiencia y Subida de Nivel
	print("[Ganando EXP] Otorgando 40 EXP...")
	stats.add_experience(40.0)
	assert(stats.current_exp == 40.0, "EXP actual debe ser 40.0")
	assert(stats.level == 1, "Aun debe ser Nivel 1")
	assert(hud.exp_bar.value == 40.0, "HUD exp_bar debe reflejar 40.0")
	
	print("[Ganando EXP para Level Up] Otorgando 70 EXP (total 110 >= meta 100)...")
	stats.add_experience(70.0)
	assert(stats.level == 2, "Debe haber alcanzado Nivel 2")
	assert(hud.level_label.text == "LVL 2", "HUD level_label debe mostrar 'LVL 2'")
	assert(is_equal_approx(hud.health_bar.max_value, stats.get_max_health()), "HUD health_bar max_value debe reflejar salud maxima")
	assert(is_equal_approx(hud.health_bar.value, stats.current_health), "HUD health_bar value debe reflejar salud actual")
	print("[OK] Test de Experiencia, Subida de Nivel y Restauración de Salud aprobado.")
	
	# 7. Test de Cambio de Armas en HUD
	if player.weapon_manager != null:
		player.weapon_manager.select_weapon(1)
		print("[Post-Cambio Arma] Arma activa en HUD: %s" % hud.weapon_label.text)
		assert(hud.weapon_label.text.contains("Subfusil SMG"), "HUD debe reflejar cambio a Subfusil SMG")
		print("[OK] Test de Señal de Arma y HUD aprobado.")
	
	print("========================================")
	print(">>> ¡TODAS LAS PRUEBAS DE LA FASE 4 PASARON EXITOSAMENTE! <<<")
	print("========================================")
	quit(0)
