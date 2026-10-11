extends SceneTree

func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	print("==================================================")
	print("--- TEST AUTOMATIZADO FASE 5: ESTADOS Y EQUIPAMIENTO ---")
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
	assert(player.equipment_manager != null, "ERROR: Player no tiene EquipmentManager")
	assert(player.weapon_manager != null, "ERROR: Player no tiene WeaponManager")
	print("[OK] Componentes del Jugador (Stats, Equipment, Weapons) validados.")
	
	var equip_mgr: EquipmentManager = player.equipment_manager
	var stats: StatsManager = player.stats_manager
	var initial_speed: float = stats.get_move_speed()
	assert(initial_speed == 240.0, "Velocidad base debe ser 240.0")
	
	# ----------------------------------------------------
	# 2. Test de EquipmentManager (Equip / Unequip / Replace)
	# ----------------------------------------------------
	var speed_boots: ItemData = load("res://data/items/speed_boots.tres")
	assert(speed_boots != null, "ERROR: No se encontro speed_boots.tres")
	
	# Equipar botas en BOOTS
	var equip_ok: bool = equip_mgr.equip_item("BOOTS", speed_boots)
	assert(equip_ok == true, "Debe equipar exitosamente en slot BOOTS")
	assert(equip_mgr.get_equipped_item("BOOTS") == speed_boots, "El slot BOOTS debe contener speed_boots")
	assert(stats.get_move_speed() == 300.0, "Velocidad debe aumentar a 300 (+60 plano)")
	print("[OK] Equipamiento de Botas en BOOTS (+60 vel) verificado.")

	# Desequipar botas de BOOTS
	var unequipped_item: ItemData = equip_mgr.unequip_item("BOOTS")
	assert(unequipped_item == speed_boots, "El item desequipado debe ser speed_boots")
	assert(equip_mgr.get_equipped_item("BOOTS") == null, "El slot BOOTS debe quedar vacio")
	assert(stats.get_move_speed() == 240.0, "Velocidad debe volver a 240.0 al desequipar")
	print("[OK] Desequipamiento y remoción de estadísticas verificado.")
	
	# Re-equipar botas
	equip_mgr.equip_item("BOOTS", speed_boots)

	# Equipar Anillo Ígneo en la categoría ACCESSORY (cae en ACCESSORY_1, la primera libre)
	var fire_ring: ItemData = load("res://data/items/fire_ring.tres")
	assert(fire_ring != null, "ERROR: No se encontro fire_ring.tres")
	equip_mgr.equip_item("ACCESSORY", fire_ring)
	assert(equip_mgr.get_equipped_item("ACCESSORY_1") == fire_ring, "El anillo debe caer en ACCESSORY_1")
	
	var infusions: Array[String] = equip_mgr.get_attack_status_effects()
	assert(infusions.has("FIRE"), "EquipmentManager debe conferir infusión 'FIRE' por el anillo")
	print("[OK] Anillo Ígneo equipado y detección de FIRE_INFUSION verificada.")
	
	# ----------------------------------------------------
	# 3. Test de HitPayload y WeaponManager
	# ----------------------------------------------------
	var wm: WeaponManager = player.weapon_manager
	wm.select_weapon(0) # Pistola Criogénica
	assert(wm.current_weapon != null, "Arma actual no debe ser nula")
	assert(wm.current_weapon.innate_status_effects.has("ICE"), "Pistola debe tener estado innato 'ICE'")
	
	# ----------------------------------------------------
	# 4. Test de StatusReceiverComponent (Fuego, Hielo y Convivencia)
	# ----------------------------------------------------
	var test_runner_scene: PackedScene = load("res://entities/enemies/basic_runner.tscn")
	var runner_node: Node = test_runner_scene.instantiate()
	level_node.add_child(runner_node)
	var runner: BasicRunner = runner_node as BasicRunner
	assert(runner.status_receiver != null, "BasicRunner debe poseer StatusReceiverComponent")
	
	var sr: StatusReceiverComponent = runner.status_receiver
	assert(sr.burn_stacks == 0, "Stacks iniciales de fuego deben ser 0")
	assert(sr.is_frozen == false, "Estado congelado inicial debe ser false")
	assert(sr.get_speed_multiplier() == 1.0, "Multiplicador inicial de velocidad debe ser 1.0")
	
	# 4a. Aplicar impacto de Hielo
	var ice_payload: HitPayload = HitPayload.new(10.0, 0.0, Vector2.ZERO, player, ["ICE"])
	sr.apply_payload(ice_payload)
	assert(sr.is_frozen == true, "Debe quedar congelado tras recibir ICE")
	assert(sr.slow_timer > 2.0, "slow_timer debe haberse inicializado a 2.5s")
	assert(sr.get_speed_multiplier() == 0.5, "Multiplicador de velocidad de hielo debe ser 0.5")
	print("[OK] Aplicación de Hielo y reducción de velocidad (50%) aprobada.")
	
	# 4b. Aplicar Fuego simultáneo (CONVIVENCIA: no cancela el hielo)
	var fire_payload: HitPayload = HitPayload.new(5.0, 0.0, Vector2.ZERO, player, ["FIRE"], 3, 4.0)
	sr.apply_payload(fire_payload)
	assert(sr.burn_stacks == 3, "Debe haber acumulado 3 stacks de fuego")
	assert(sr.burn_timer == 3.0, "burn_timer debe inicializarse a 3.0s")
	assert(sr.is_frozen == true, "El hielo NO debe haber sido anulado por el fuego")
	assert(sr.get_speed_multiplier() == 0.5, "La velocidad reducida se mantiene activa")
	print("[OK] Convivencia simultánea de Fuego y Hielo aprobada.")
	
	# 4c. Stacking de fuego hasta el límite
	var fire_payload_more: HitPayload = HitPayload.new(5.0, 0.0, Vector2.ZERO, player, ["FIRE"], 8, 4.0)
	sr.apply_payload(fire_payload_more)
	assert(sr.burn_stacks == 10, "Los stacks de fuego deben limitarse al maximo (10)")
	print("[OK] Límite máximo de Stacking de fuego (10 stacks) aprobado.")
	
	# 4d. Ejecutar tick de daño por fuego (daño = 4.0 base * 10 stacks = 40.0)
	var initial_runner_hp: float = runner.health_component.current_health
	sr._trigger_burn_tick()
	var post_tick_hp: float = runner.health_component.current_health
	var damage_dealt: float = initial_runner_hp - post_tick_hp
	assert(is_equal_approx(damage_dealt, 40.0), "El tick debe infligir exactamente 40.0 de daño (4.0 base * 10 stacks)")
	print("[OK] Tick periódico de daño escalado por Stacks (40.0 de daño) aprobado.")
	
	# 4e. Expiración de Hielo
	sr._process_ice_status(3.0) # Forzar paso del tiempo
	assert(sr.is_frozen == false, "El hielo debe expirar tras transcurrir la duracion")
	assert(sr.get_speed_multiplier() == 1.0, "La velocidad debe restaurarse a 1.0")
	assert(sr.burn_stacks == 10, "El fuego sigue activo independientemente de la expiracion del hielo")
	print("[OK] Expiración de Hielo y persistencia independiente de Fuego aprobada.")
	
	# 4f. Expiración de Fuego
	sr._process_fire_status(4.0) # Forzar paso del tiempo
	assert(sr.burn_stacks == 0, "Los stacks de fuego deben limpiarse tras expirar el temporizador")
	print("[OK] Expiración completa de Fuego y reseteo de stacks aprobado.")
	
	print("==================================================")
	print(">>> ¡TODAS LAS PRUEBAS DE LA FASE 5 PASARON EXITOSAMENTE! <<<")
	print("==================================================")
	quit(0)
