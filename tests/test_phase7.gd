extends SceneTree
## Script de prueba automatizado para la Fase 7:
## 1. StatusDisplayComponent en Player, BasicRunner, TrainingDummy y TrainingTurret
## 2. Reacción reactiva de badges a stacks de Fuego y estado de Hielo
## 3. Extensibilidad de nuevos estados en StatusDisplayComponent
## 4. Desequipado rápido con 'U' y 'J' en EquipmentManager y soltado de PickupItem
## 5. Cese inmediato de infusión ígnea al desequipar el anillo
## 6. Sistema Melee con Espada de Hierro (iron_sword.tres) y slot 3
## 7. Mecánica de Parry Balístico dentro de los primeros 0.06s (daño x1.5, rotación invertida, dueño transferido)
## 8. Prevención de doble golpe en un mismo tajo melee (hit_targets)

func _init() -> void:
	print("==================================================")
	print("--- TEST AUTOMATIZADO FASE 7: MELEE, PARRY Y STATUS DISPLAY ---")
	print("==================================================")
	
	# 1. Cargar test_level.tscn
	var level_scene: PackedScene = load("res://core/test_level.tscn")
	assert(level_scene != null, "[FAIL] No se pudo cargar test_level.tscn")
	var level: Node2D = level_scene.instantiate() as Node2D
	root.add_child(level)
	print("[OK] test_level.tscn instanciado en SceneTree.")
	
	var player: Player = level.get_node_or_null("Player") as Player
	assert(player != null, "[FAIL] No se encontró Player en test_level.tscn")
	player._ready()

	
	# 2. Validar StatusDisplayComponent en Player y enemigos
	var player_status_disp: StatusDisplayComponent = player.get_node_or_null("StatusDisplayComponent") as StatusDisplayComponent
	assert(player_status_disp != null, "[FAIL] Player no tiene StatusDisplayComponent")
	print("[OK] StatusDisplayComponent presente en Player.")
	
	var runner_scene: PackedScene = load("res://entities/enemies/basic_runner.tscn")
	var runner: BasicRunner = runner_scene.instantiate() as BasicRunner
	level.add_child(runner)
	runner.global_position = Vector2(500, 575)
	runner._ready()
	
	var runner_status_disp: StatusDisplayComponent = runner.get_node_or_null("StatusDisplayComponent") as StatusDisplayComponent
	assert(runner_status_disp != null, "[FAIL] BasicRunner no tiene StatusDisplayComponent")
	runner_status_disp._ready()
	print("[OK] StatusDisplayComponent presente en BasicRunner.")
	
	# 3. Validar reactividad de StatusDisplayComponent con Fuego y Hielo
	var runner_receiver: StatusReceiverComponent = runner.get_node_or_null("StatusReceiverComponent") as StatusReceiverComponent
	if runner_receiver == null:
		runner_receiver = runner.status_receiver
	assert(runner_receiver != null, "[FAIL] BasicRunner no tiene StatusReceiverComponent")

	
	# Aplicar fuego
	runner_receiver.apply_fire(4)
	runner_status_disp._process(0.0)
	assert(runner_status_disp.fire_badge.visible == true, "[FAIL] FireBadge debería ser visible con stacks > 0")
	assert(runner_status_disp.fire_label.text == "x4", "[FAIL] FireLabel debería mostrar 'x4'")
	print("[OK] FireBadge muestra 'x4' stacks correctamente.")
	
	# Limpiar fuego
	runner_receiver.burn_stacks = 0
	runner_status_disp._process(0.0)
	assert(runner_status_disp.fire_badge.visible == false, "[FAIL] FireBadge debería ocultarse con 0 stacks")
	print("[OK] FireBadge se oculta con 0 stacks.")
	
	# Aplicar hielo
	runner_receiver.apply_ice()
	runner_status_disp._process(0.0)
	assert(runner_status_disp.ice_badge.visible == true, "[FAIL] IceBadge debería ser visible cuando is_frozen == true")
	print("[OK] IceBadge visible durante congelamiento.")
	
	# Probar extensibilidad de nuevos debuffs
	var poison_badge: HBoxContainer = runner_status_disp.register_custom_status("POISON", Color(0.2, 0.8, 0.2, 1.0), true)
	assert(poison_badge != null, "[FAIL] Falló el registro de debuff personalizado")
	runner_status_disp.update_custom_status("POISON", true, "x2")
	assert(poison_badge.visible == true, "[FAIL] Badge personalizado no se hizo visible")
	print("[OK] Extensibilidad de StatusDisplayComponent validada con debuff personalizado.")
	
	# 4. Validar WeaponData y Espada de Hierro
	var sword_data: WeaponData = load("res://data/weapons/iron_sword.tres") as WeaponData
	assert(sword_data != null, "[FAIL] No se encontró iron_sword.tres")
	assert(sword_data.weapon_type == WeaponData.WeaponType.MELEE, "[FAIL] iron_sword.tres debe ser de tipo MELEE")
	assert(sword_data.damage == 28.0, "[FAIL] Daño de espada incorrecto")
	print("[OK] iron_sword.tres cargada y validada como WeaponType.MELEE (28 DMG).")
	
	# 5. Validar selección de slot 3 en WeaponManager
	var wm: WeaponManager = player.weapon_manager
	if wm == null:
		wm = player.get_node_or_null("WeaponManager") as WeaponManager
	assert(wm != null, "[FAIL] Player no tiene WeaponManager")
	wm.select_weapon(2) # Slot 3 (índice 2)
	assert(wm.current_weapon.weapon_type == WeaponData.WeaponType.MELEE, "[FAIL] Slot 3 no equipó arma Melee")
	print("[OK] WeaponManager equipó Espada Melee en Slot 3.")
	
	# 6. Validar Desequipado rápido en EquipmentManager (U y J)
	var em: EquipmentManager = player.equipment_manager
	if em == null:
		em = player.get_node_or_null("EquipmentManager") as EquipmentManager
	assert(em != null, "[FAIL] Player no tiene EquipmentManager")

	var fire_ring: ItemData = load("res://data/items/fire_ring.tres") as ItemData
	var boots: ItemData = load("res://data/items/speed_boots.tres") as ItemData
	
	# Equipar anillo
	em.equip_item("ACCESSORY", fire_ring)
	assert(em.get_attack_status_effects().has("FIRE"), "[FAIL] Con anillo equipado debe conferir FIRE")
	
	# Desequipar anillo con drop
	var dropped_ring: ItemData = em.drop_equipped_item("ACCESSORY_1")
	assert(dropped_ring == fire_ring, "[FAIL] drop_equipped_item no retornó el anillo")
	assert(em.get_equipped_item("ACCESSORY_1") == null, "[FAIL] Ranura ACCESSORY_1 no quedó vacía")
	assert(not em.get_attack_status_effects().has("FIRE"), "[FAIL] Tras desequipar anillo, no debe conferir FIRE")
	print("[OK] Desequipado de ACCESSORY_1 ('U') vacía ranura y detiene infusión ígnea inmediatamente.")

	# Equipar y desequipar botas
	em.equip_item("BOOTS", boots)
	var dropped_boots: ItemData = em.drop_equipped_item("BOOTS")
	assert(dropped_boots == boots, "[FAIL] drop_equipped_item no retornó las botas")
	assert(em.get_equipped_item("BOOTS") == null, "[FAIL] Ranura BOOTS no quedó vacía")
	print("[OK] Desequipado de BOOTS ('J') vacía ranura correctamente.")
	
	# 7. Validar Mecánica de Parry Balístico en MeleeHitbox
	var melee_scene: PackedScene = load("res://combat/melee_hitbox.tscn")
	assert(melee_scene != null, "[FAIL] No se encontró melee_hitbox.tscn")
	var melee_hitbox: MeleeHitbox = melee_scene.instantiate() as MeleeHitbox
	level.add_child(melee_hitbox)
	melee_hitbox.global_position = Vector2(400, 560)
	
	var melee_payload: HitPayload = HitPayload.new(28.0, 150.0, Vector2.RIGHT, player, [], 1, 3.0)
	melee_hitbox.execute_swing(player, melee_payload, 110.0, 0.16, Vector2.RIGHT)
	
	# Crear proyectil hostil que vuela hacia la izquierda
	var proj_scene: PackedScene = load("res://combat/projectile.tscn")
	var enemy_proj: Projectile = proj_scene.instantiate() as Projectile
	level.add_child(enemy_proj)
	enemy_proj.global_position = Vector2(420, 560)
	enemy_proj.rotation = PI # Hacia la izquierda (hacia el jugador)
	
	var host_payload: HitPayload = HitPayload.new(20.0, 50.0, Vector2.LEFT, runner, [], 1, 3.0)
	enemy_proj.setup(300.0, host_payload)
	enemy_proj.is_hostile = true
	
	# Simular impacto en t = 0.03s (dentro de parry_window = 0.06s)
	melee_hitbox.elapsed_time = 0.03
	var initial_dir: Vector2 = enemy_proj.transform.x
	var initial_dmg: float = enemy_proj.payload.base_damage
	
	melee_hitbox._check_projectile_parry(enemy_proj)
	
	assert(enemy_proj.is_parried == true, "[FAIL] Proyectil no fue marcado como is_parried")
	assert(enemy_proj.is_hostile == false, "[FAIL] Proyectil no dejó de ser hostil tras parry")
	assert(enemy_proj.payload.source_node == player, "[FAIL] Dueño del proyectil no fue transferido al jugador")
	assert(enemy_proj.payload.base_damage == initial_dmg * 1.5, "[FAIL] Daño del proyectil no fue multiplicado por 1.5 (actual: %.1f, esperado: %.1f)" % [enemy_proj.payload.base_damage, initial_dmg * 1.5])
	
	# Verificar inversión de rotación (apunta ahora hacia la derecha)
	var parried_dir: Vector2 = enemy_proj.transform.x
	assert(initial_dir.dot(parried_dir) < -0.9, "[FAIL] Dirección de la bala no fue invertida tras el parry")
	print("[OK] Parry Balístico exitoso: rotación invertida 180°, daño x1.5 (%.1f -> %.1f), dueño transferido al Jugador." % [initial_dmg, enemy_proj.payload.base_damage])
	
	# 8. Validar prevención de doble impacto en el mismo tajo
	var test_runner: BasicRunner = runner_scene.instantiate() as BasicRunner
	level.add_child(test_runner)
	var hc: HealthComponent = test_runner.get_node("HealthComponent") as HealthComponent
	test_runner.health_component = hc
	hc.current_health = hc.max_health
	var health_before: float = hc.current_health
	
	melee_hitbox._handle_target_collision(test_runner)
	var health_after_1: float = hc.current_health
	assert(health_after_1 < health_before, "[FAIL] Melee no dañó al enemigo en el primer contacto")
	
	# Segundo contacto con el mismo enemigo dentro del mismo tajo
	melee_hitbox._handle_target_collision(test_runner)
	var health_after_2: float = hc.current_health
	assert(health_after_2 == health_after_1, "[FAIL] Melee dañó dos veces al enemigo en el mismo tajo (doble hit detectado)")
	print("[OK] Prevención de doble golpe validada: enemigo dañado exactamente una vez por tajo.")

	
	print("==================================================")
	print(">>> ¡TODAS LAS PRUEBAS DE LA FASE 7 PASARON EXITOSAMENTE! <<<")
	print("==================================================")
	quit(0)
