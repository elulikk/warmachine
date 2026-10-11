class_name WeaponManager
extends Node
## Administrador del arsenal y sistema de disparo del Jugador.
## Gestiona la selección de armas, tiempos de enfriamiento (fire rate),
## retroceso físico (recoil) y el modo de depuración de munición infinita.

signal weapon_changed(weapon: WeaponData, index: int)
signal weapon_fired(weapon: WeaponData)
signal infinite_ammo_toggled(is_infinite: bool)
signal weapon_reloaded(weapon: WeaponData)
signal ammo_changed(current: int, max_mag: int)
signal reload_started(duration: float)
signal reload_completed

const RELOAD_INDICATOR_SCRIPT: GDScript = preload("res://ui/reload_indicator.gd")
const ItemIconsScript = preload("res://ui/components/item_icons.gd")
const WeaponMotion = preload("res://core/art/weapon_motion.gd")
const ShotFx = preload("res://combat/shot_fx.gd")

## Escala del cuerpo del jugador respecto del sprite original de 32x32 (ver `Visuals.scale` en player.tscn).
## Mueve donde está la mano y el centro del cuerpo.
const BODY_SCALE: float = 2.0

## Cuánto se amplía el arma en mano sobre su tamaño base (`ItemIcons.WEAPON_POSES`).
## Es menor que BODY_SCALE a propósito: las armas no necesitan crecer tanto como el cuerpo.
const WEAPON_SCALE: float = 1.5

## Cuánto se amplía el hitbox melee. Va de la mano con WEAPON_SCALE para que la punta del arma caiga dentro.
const HITBOX_SCALE: float = 1.5

## Distancia horizontal desde el pivote de apuntado hasta la mano que sostiene el arma.
const HAND_OFFSET_X: float = 4.0 * BODY_SCALE

## Lista de recursos de armas disponibles en el inventario del jugador.
@export var weapons: Array[WeaponData] = []

## Índice del arma actualmente equipada.
@export var current_weapon_index: int = 0

## Referencias a componentes del arma
@export var weapon_pivot: WeaponPivot
@export var muzzle: Marker2D

var current_weapon: WeaponData = null
var fire_cooldown_timer: float = 0.0
var reload_timer: float = 0.0
var is_reloading: bool = false
var infinite_ammo: bool = false
## Mientras es true los disparos no consumen munición ni se inicia la recarga (poción Sin Recarga).
var free_ammo_active: bool = false
## Lo activa la barra de acceso rápido cuando el casillero en mano no es un arma (consumible o vacío):
## mientras esté activo no se dispara ni se recarga.
var hand_locked: bool = false
var weapon_magazines: Dictionary[WeaponData, int] = {}
var player: Player = null
var projectile_pool: ProjectilePool = null

var _weapon_sprite: Sprite2D = null
var _sprite_rest_position: Vector2 = Vector2.ZERO
var _sprite_rest_rotation: float = 0.0
var _hand_tween: Tween = null

## Última animación disparada (la lee CharacterRig al recibir `weapon_fired`):
## {"body": fotogramas del cuerpo, "length": duración en s, "recoil": factor de retroceso del torso}
var last_motion: Dictionary = {}
## Disparos seguidos de la ráfaga actual (combo de retroceso de las automáticas, ver `PATTERNS` en weapon_motion.gd).
var _burst_count: int = 0
var _last_shot_msec: int = -100000
var _swing_index: int = 0
var _current_swing: Dictionary = {}


func _ready() -> void:
	player = owner as Player
	GameFeel.sfx_prewarm(self)
	_create_reload_indicator()
	_ensure_weapons()
	if not weapons.is_empty():
		select_weapon(clampi(current_weapon_index, 0, weapons.size() - 1))
	else:
		current_weapon = null
		_update_weapon_visual()
		weapon_changed.emit(null, -1)


## Crea la barra de recarga flotante sobre el jugador (hija del Player, diferida porque
## el padre aún está montando sus hijos durante _ready).
func _create_reload_indicator() -> void:
	if player == null:
		return
	var indicator: Node2D = RELOAD_INDICATOR_SCRIPT.new() as Node2D
	if indicator == null:
		return
	indicator.name = "ReloadIndicator"
	indicator.call("setup", self)
	player.add_child.call_deferred(indicator)


func _ensure_weapons() -> void:
	var is_sandbox: bool = false
	if is_inside_tree() and get_tree() != null:
		var scene: Node = get_tree().current_scene
		if scene != null:
			if scene is TestLevel or scene.scene_file_path.ends_with("test_level.tscn"):
				is_sandbox = true
	
	if not is_sandbox and player != null:
		var p_parent: Node = player.get_parent()
		if p_parent != null and (p_parent is TestLevel or p_parent.scene_file_path.ends_with("test_level.tscn")):
			is_sandbox = true
	
	if not is_sandbox and owner != null and owner.get_parent() != null:
		var o_parent: Node = owner.get_parent()
		if o_parent is TestLevel or o_parent.scene_file_path.ends_with("test_level.tscn"):
			is_sandbox = true
	
	if is_sandbox:
		weapons.clear()
		# En el Sandbox otorgamos todas las armas para pruebas libres
		var weapon_paths: Array[String] = [
			"res://data/weapons/combat_knife.tres",
			"res://data/weapons/pistol.tres",
			"res://data/weapons/smg.tres",
			"res://data/weapons/katana.tres",
			"res://data/weapons/heavy_hammer.tres"
		]
		for w_path in weapon_paths:
			if ResourceLoader.exists(w_path):
				var loaded_w: WeaponData = load(w_path) as WeaponData
				if loaded_w != null:
					var w_inst: WeaponData = loaded_w.duplicate()
					w_inst.source_resource_path = w_path
					weapons.append(w_inst)
		print("[WeaponManager] Modo Sandbox: arsenal completo cargado (%d armas)." % weapons.size())
	else:
		# En modo campaña/base, un personaje nuevo inicia desarmado salvo que SaveManager cargue armas
		pass


## Agrega un arma al inventario del jugador y opcionalmente la equipa de inmediato.
func add_weapon(weapon: WeaponData, auto_equip: bool = true) -> void:
	if weapon == null:
		return
	var src_path: String = weapon.resource_path if not weapon.resource_path.is_empty() else weapon.source_resource_path
	var weapon_instance: WeaponData = weapon.duplicate()
	weapon_instance.source_resource_path = src_path
	weapons.append(weapon_instance)
	print("[WeaponManager] Nueva arma adquirida: %s. Total armas: %d" % [weapon_instance.weapon_name, weapons.size()])
	if auto_equip:
		select_weapon(weapons.size() - 1)


func _process(delta: float) -> void:
	if fire_cooldown_timer > 0.0:
		fire_cooldown_timer = maxf(0.0, fire_cooldown_timer - delta)
	
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			finish_reload()
	
	_handle_debug_input()
	_handle_firing_input()


## Obtiene la munición actual del arma especificada en el diccionario de cargadores.
func get_weapon_ammo(weapon: WeaponData) -> int:
	if weapon == null:
		return 0
	if not weapon_magazines.has(weapon):
		weapon_magazines[weapon] = weapon.magazine_size
	return weapon_magazines[weapon]


## Establece la munición actual para el arma y emite la señal de cambio si es el arma activa.
func set_weapon_ammo(weapon: WeaponData, amount: int) -> void:
	if weapon == null:
		return
	var max_mag: int = weapon.magazine_size
	var clamped_amount: int = clampi(amount, 0, max_mag)
	weapon_magazines[weapon] = clamped_amount
	if weapon == current_weapon:
		ammo_changed.emit(clamped_amount, max_mag)


## Inicia el proceso de recarga si el arma tiene cargador y no está llena.
func start_reload() -> void:
	if current_weapon == null or is_reloading or free_ammo_active:
		return
	if current_weapon.weapon_type == WeaponData.WeaponType.MELEE or current_weapon.magazine_size <= 0:
		return
	
	var cur_ammo: int = get_weapon_ammo(current_weapon)
	if cur_ammo >= current_weapon.magazine_size:
		return
	
	is_reloading = true
	reload_timer = current_weapon.reload_time
	reload_started.emit(current_weapon.reload_time)
	GameFeel.sfx(self, &"reload_out", Vector2.INF, -4.0)
	_play_reload_animation(current_weapon.reload_time)
	weapon_changed.emit(current_weapon, current_weapon_index)


## Cancela la recarga en curso (por ejemplo al cambiar de arma).
func cancel_reload() -> void:
	if is_reloading:
		is_reloading = false
		reload_timer = 0.0
		_cancel_hand_tween()


## Activa o desactiva el modo sin recarga. Al activarlo cancela la recarga en curso y llena el cargador.
func set_free_ammo(enabled: bool) -> void:
	free_ammo_active = enabled
	if enabled:
		cancel_reload()
		if current_weapon != null and current_weapon.magazine_size > 0:
			set_weapon_ammo(current_weapon, current_weapon.magazine_size)
		weapon_changed.emit(current_weapon, current_weapon_index)


## Concluye la recarga restaurando el cargador completo.
func finish_reload() -> void:
	is_reloading = false
	reload_timer = 0.0
	if current_weapon != null and current_weapon.magazine_size > 0:
		set_weapon_ammo(current_weapon, current_weapon.magazine_size)
		reload_completed.emit()
		GameFeel.sfx(self, &"reload_done", Vector2.INF, -3.0)
		weapon_reloaded.emit(current_weapon)
		weapon_changed.emit(current_weapon, current_weapon_index)


## Atajo de depuración F1: alterna munición infinita y sin cooldown.
## La selección de armas (teclas, rueda, L1/R1, Q) la maneja la barra de acceso rápido (ui/hotbar.gd).
func _handle_debug_input() -> void:
	if Input.is_action_just_pressed("debug_infinite_ammo"):
		set_infinite_ammo(not infinite_ammo)


## Procesa la intención de disparo según el tipo de arma (semiautomática vs automática).
func _handle_firing_input() -> void:
	if current_weapon == null or hand_locked:
		return

	# Recarga manual con tecla R o acción 'reload'
	# Solo por acción (R por defecto): así respeta la reasignación de Opciones > Controles
	if Input.is_action_just_pressed("reload"):
		start_reload()
		return
	
	# Durante la recarga, bloquear la ejecución de fire()
	if is_reloading:
		return
	
	var wants_to_fire: bool = false
	if current_weapon.is_automatic:
		wants_to_fire = Input.is_action_pressed("attack")
	else:
		wants_to_fire = Input.is_action_just_pressed("attack")
	
	if wants_to_fire:
		if current_weapon.weapon_type != WeaponData.WeaponType.MELEE and current_weapon.magazine_size > 0:
			var cur_ammo: int = get_weapon_ammo(current_weapon)
			if cur_ammo <= 0 and not infinite_ammo:
				# Si el cargador llega a 0 y se intenta disparar, detonar recarga automática
				start_reload()
				return
		
		if fire_cooldown_timer <= 0.0 or infinite_ammo:
			fire()


## Ejecuta el disparo o ataque melee según el tipo de arma.
func fire() -> void:
	if current_weapon == null:
		return
	
	# Si es un arma cuerpo a cuerpo, ejecutar barrido de corte Melee
	if current_weapon.weapon_type == WeaponData.WeaponType.MELEE:
		_execute_melee_attack()
		return
	
	if current_weapon.projectile_scene == null:
		return
	
	var spawn_pos: Vector2 = muzzle.global_position if muzzle != null else player.global_position
	var aim_dir: Vector2 = weapon_pivot.get_aim_direction() if weapon_pivot != null else Vector2.RIGHT
	
	# 1. Crear el HitPayload escalado por el multiplicador de daño del StatsManager y daño de runas
	var dmg_mult: float = 1.0
	if player != null and player.stats_manager != null:
		dmg_mult = player.stats_manager.get_damage_multiplier()
	
	# Recopilar estados base del arma + infusiones de runas + infusiones del EquipmentManager
	var payload_effects: Array[String] = []
	for eff in current_weapon.get_elemental_infusions():
		if not payload_effects.has(eff):
			payload_effects.append(eff)
	
	if player != null and player.equipment_manager != null:
		for eff in player.equipment_manager.get_attack_status_effects():
			if not payload_effects.has(eff):
				payload_effects.append(eff)
	
	var final_damage: float = current_weapon.get_effective_damage() * dmg_mult
	var knockback: float = current_weapon.knockback_force if current_weapon.knockback_force > 0.0 else current_weapon.recoil_force * 1.5
	var armor_pen: float = current_weapon.armor_penetration
	
	# Consultar modificadores de runas acumulados
	var bounces: int = current_weapon.get_total_bounces()
	var pierces: int = current_weapon.get_total_pierce()
	var forks: int = current_weapon.get_total_forks()
	
	# 2. Disparar proyectil(es) (soporta disparo único o perdigones en abanico)
	var pool: ProjectilePool = _get_projectile_pool()
	var pellets: int = maxi(1, current_weapon.pellets_per_shot)
	var spread_deg: float = current_weapon.spread_angle_degrees
	var base_angle: float = aim_dir.angle()
	
	for i in range(pellets):
		var pellet_dir: Vector2 = aim_dir
		if pellets > 1 and spread_deg > 0.0:
			var step: float = deg_to_rad(spread_deg) / float(pellets - 1)
			var angle_offset: float = -deg_to_rad(spread_deg) * 0.5 + float(i) * step
			pellet_dir = Vector2.from_angle(base_angle + angle_offset)
		elif pellets == 1 and spread_deg > 0.0:
			# Disparo único: desvío aleatorio dentro del cono (spread_deg es el ángulo total)
			pellet_dir = aim_dir.rotated(deg_to_rad(randf_range(-0.5, 0.5) * spread_deg))

		var payload: HitPayload = HitPayload.new(
			final_damage,
			knockback,
			pellet_dir,
			player,
			payload_effects,
			1,
			3.0,
			armor_pen
		)
		
		if pool != null:
			pool.get_projectile(spawn_pos, pellet_dir, payload, current_weapon.projectile_speed, bounces, pierces, forks)
		else:
			# Fallback de reserva si no existe pool en la escena
			var fallback_node: Node = current_weapon.projectile_scene.instantiate()
			if fallback_node is Projectile:
				var proj: Projectile = fallback_node as Projectile
				proj.global_position = spawn_pos
				proj.rotation = pellet_dir.angle()
				proj.setup(current_weapon.projectile_speed, payload, bounces, pierces, forks)
				var container: Node = get_tree().current_scene
				if container == null:
					container = owner.get_parent() if owner != null else get_parent()
				if container == null:
					container = get_tree().root
				container.add_child(fallback_node)
	
	_play_weapon_kick()
	ShotFx.muzzle_flash(self, spawn_pos, aim_dir)
	ShotFx.muzzle_smoke(self, spawn_pos, aim_dir)
	GameFeel.sfx_weapon_fire(self, current_weapon)

	# 3. Aplicar fuerza de retroceso sobre el jugador
	if player != null and current_weapon.recoil_force > 0.0:
		player.velocity -= aim_dir * current_weapon.recoil_force
	GameFeel.on_weapon_fired(self, current_weapon.recoil_force)
	
	# 4. Descontar munición si el arma posee cargador
	if not infinite_ammo and not free_ammo_active and current_weapon.magazine_size > 0:
		var current_mag: int = get_weapon_ammo(current_weapon)
		current_mag = maxi(0, current_mag - 1)
		set_weapon_ammo(current_weapon, current_mag)
		if current_mag <= 0:
			start_reload()
	
	# 5. Iniciar tiempo de recarga / cooldown
	if not infinite_ammo:
		fire_cooldown_timer = current_weapon.get_fire_interval()
	else:
		# Con munición infinita permitimos disparos ultra rápidos pero controlados
		fire_cooldown_timer = 0.04
	
	weapon_fired.emit(current_weapon)
	weapon_changed.emit(current_weapon, current_weapon_index)


## Ejecuta el barrido angular del arma Melee (espada) orientada al cursor del mouse.
func _execute_melee_attack() -> void:
	var swings: Array = WeaponMotion.profile_for(current_weapon).get("swings", []) as Array
	_current_swing = {}
	if not swings.is_empty():
		_current_swing = swings[_swing_index % swings.size()] as Dictionary
		_swing_index += 1
	var total: float = maxf(current_weapon.swing_duration, 0.05) * float(_current_swing.get("length", 1.0))
	last_motion = {"body": _current_swing.get("body", []), "length": total, "recoil": 0.0}

	if not infinite_ammo:
		fire_cooldown_timer = current_weapon.get_fire_interval()
	else:
		fire_cooldown_timer = 0.08

	var delay: float = float(_current_swing.get("hit_delay", 0.0))
	if delay <= 0.0:
		_melee_strike(false)
		weapon_fired.emit(current_weapon)
		return

	# El golpe llega con el impacto de la animación (martillo): el cuerpo y el arma empiezan ya
	var swung: WeaponData = current_weapon
	if _has_weapon_sprite():
		_play_melee_swing(swung.swing_arc_degrees, swung.swing_duration)
	weapon_fired.emit(swung)
	await get_tree().create_timer(delay).timeout
	if current_weapon != swung or player == null or not is_instance_valid(player):
		return
	_melee_strike(true)


## Crea el golpe efectivo del arma melee: hitbox, impulso y onda de choque.
func _melee_strike(visual_done: bool) -> void:
	var aim_dir: Vector2 = weapon_pivot.get_aim_direction() if weapon_pivot != null else Vector2.RIGHT
	
	var dmg_mult: float = 1.0
	if player != null and player.stats_manager != null:
		dmg_mult = player.stats_manager.get_damage_multiplier()
	
	var payload_effects: Array[String] = []
	for eff in current_weapon.get_elemental_infusions():
		if not payload_effects.has(eff):
			payload_effects.append(eff)
	
	if player != null and player.equipment_manager != null:
		for eff in player.equipment_manager.get_attack_status_effects():
			if not payload_effects.has(eff):
				payload_effects.append(eff)
	
	var final_damage: float = current_weapon.get_effective_damage() * dmg_mult
	var payload: HitPayload = HitPayload.new(
		final_damage,
		current_weapon.knockback_force if current_weapon.knockback_force > 0.0 else 160.0,
		aim_dir,
		player,
		payload_effects,
		1,
		3.0
	)
	
	var melee_scene: PackedScene = preload("res://combat/melee_hitbox.tscn")
	var melee_instance: MeleeHitbox = melee_scene.instantiate() as MeleeHitbox
	
	var container: Node = get_tree().current_scene
	if container == null:
		container = owner.get_parent() if owner != null else get_parent()
	if container == null:
		container = get_tree().root
	
	container.add_child(melee_instance)
	var spawn_pos: Vector2 = player.global_position + Vector2(0, -16.0 * BODY_SCALE) if player != null else Vector2.ZERO
	melee_instance.global_position = spawn_pos
	# El hitbox crece junto con el arma en mano
	var hitbox_scale: float = HITBOX_SCALE * maxf(0.1, current_weapon.melee_hitbox_scale)
	melee_instance.scale = Vector2(hitbox_scale, hitbox_scale)
	
	if current_weapon.crit_multiplier > 1.0:
		melee_instance.custom_crit_multiplier = current_weapon.crit_multiplier
	
	melee_instance.execute_swing(
		player,
		payload,
		current_weapon.swing_arc_degrees,
		current_weapon.swing_duration,
		aim_dir
	)
	GameFeel.sfx_weapon_swing(self, current_weapon)

	# El arma en mano hace el tajo con su propia estela; el rectángulo blanco del hitbox se oculta
	if _has_weapon_sprite():
		if not visual_done:
			_play_melee_swing(current_weapon.swing_arc_degrees, current_weapon.swing_duration)
		var slash: Node2D = melee_instance.get_node_or_null("SlashVisual") as Node2D
		if slash != null:
			slash.visible = false

	# Mecánica Katana: Impulso horizontal instantáneo y ventana de fase para atravesar enemigos
	if player != null and current_weapon.melee_dash_impulse > 0.0:
		var dash_dir: float = float(player.facing_direction)
		if absf(aim_dir.x) > 0.2:
			dash_dir = signf(aim_dir.x)
		player.velocity.x += dash_dir * current_weapon.melee_dash_impulse
		var phase_dur: float = current_weapon.melee_phase_duration if current_weapon.melee_phase_duration > 0.0 else 0.15
		player.activate_melee_phase(phase_dur)
	
	# Mecánica Martillo Pesado: Onda de expansión física en el piso
	if current_weapon.creates_ground_shockwave:
		_spawn_ground_shockwave(spawn_pos, aim_dir)
		GameFeel.shake(self, 6.0, 0.25)

	# Si tiene recoil force, empujar al jugador
	if player != null and current_weapon.recoil_force > 0.0:
		player.velocity -= aim_dir * current_weapon.recoil_force
	


## Genera una onda de expansión física proyectada sobre el suelo más cercano.
func _spawn_ground_shockwave(from_pos: Vector2, aim_dir: Vector2) -> void:
	var shock_scene: PackedScene = current_weapon.shockwave_scene
	if shock_scene == null:
		shock_scene = preload("res://combat/ground_shockwave.tscn")
	if shock_scene == null:
		return
	
	var container: Node = get_tree().current_scene
	if container == null:
		container = owner.get_parent() if owner != null else get_parent()
	if container == null:
		container = get_tree().root
	
	# Proyectar rayo hacia abajo para encontrar la superficie del suelo
	var ground_pos: Vector2 = from_pos + aim_dir * 32.0
	if player != null and player.is_inside_tree():
		var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			ground_pos + Vector2(0.0, -16.0),
			ground_pos + Vector2(0.0, 120.0),
			1 # Capa 1: Terreno
		)
		var res: Dictionary = space_state.intersect_ray(query)
		if not res.is_empty() and res.has("position"):
			ground_pos = res["position"]
		else:
			ground_pos.y += 24.0 # Fallback si está en el aire o sobre plataforma
	
	var shock: Node2D = shock_scene.instantiate() as Node2D
	if shock != null:
		if "source_node" in shock:
			shock.set("source_node", player)
		shock.global_position = ground_pos
		container.add_child(shock)





## Obtiene o genera la reserva de proyectiles en la escena actual.
func _get_projectile_pool() -> ProjectilePool:
	if projectile_pool != null and is_instance_valid(projectile_pool):
		return projectile_pool
	
	projectile_pool = get_tree().get_first_node_in_group(&"projectile_pool") as ProjectilePool
	if projectile_pool == null:
		var container: Node = get_tree().current_scene
		if container == null:
			container = owner.get_parent() if owner != null else get_parent()
		if container == null:
			container = get_tree().root
		projectile_pool = container.get_node_or_null("ProjectilePool") as ProjectilePool
		if projectile_pool == null and container != null:
			projectile_pool = ProjectilePool.new()
			projectile_pool.name = "ProjectilePool"
			container.add_child(projectile_pool)
	return projectile_pool


## Añade munición al arsenal del jugador (pickup AMMO).
func add_ammo(amount: int = 1) -> void:
	print("[WeaponManager] +%d paquete(s) de munición recogido(s)." % amount)



## Selecciona un arma por índice directo en el array.
func select_weapon(index: int) -> void:
	if weapons.is_empty():
		cancel_reload()
		current_weapon = null
		_update_weapon_visual()
		weapon_changed.emit(null, -1)
		ammo_changed.emit(0, 0)
		return
	
	# Si se cambia de arma durante la recarga, cancelar el timer actual
	cancel_reload()
	
	var clamped_index: int = clampi(index, 0, weapons.size() - 1)
	if clamped_index != current_weapon_index and current_weapon != null:
		GameFeel.sfx(self, &"weapon_swap", Vector2.INF, -6.0)
	current_weapon_index = clamped_index
	current_weapon = weapons[current_weapon_index]
	fire_cooldown_timer = 0.0
	_update_weapon_visual()
	
	var cur_ammo: int = get_weapon_ammo(current_weapon)
	ammo_changed.emit(cur_ammo, current_weapon.magazine_size)
	weapon_changed.emit(current_weapon, current_weapon_index)


## Deja la mano vacía sin tocar el arsenal (la barra rápida lo usa al elegir un casillero sin arma).
func unequip_hand() -> void:
	if current_weapon == null:
		return
	cancel_reload()
	current_weapon = null
	_update_weapon_visual()
	weapon_changed.emit(null, -1)


## Dibuja el arma en mano con el mismo ícono pixel art del inventario (ver ItemIcons.WEAPON_POSES).
## Si el arma no tiene ícono ni pose, cae al rectángulo de color de siempre.
func _update_weapon_visual() -> void:
	if weapon_pivot == null:
		return
	var visual: ColorRect = weapon_pivot.get_node_or_null("WeaponVisual") as ColorRect
	_cancel_hand_tween()
	if current_weapon == null:
		if visual != null:
			visual.visible = false
		if _weapon_sprite != null and is_instance_valid(_weapon_sprite):
			_weapon_sprite.visible = false
		return

	if _apply_weapon_sprite(visual):
		return

	if _weapon_sprite != null and is_instance_valid(_weapon_sprite):
		_weapon_sprite.visible = false
	if visual == null:
		return

	visual.visible = true
	if current_weapon.weapon_type == WeaponData.WeaponType.MELEE:
		visual.color = Color(0.85, 0.9, 0.98, 1.0) # Hoja de cuchillo táctico
		visual.size = Vector2(16, 3)
		visual.position = Vector2(5, -1.5)
	else:
		visual.color = Color(0.75, 0.78, 0.82, 1.0) # Cañón metálico estándar
		visual.size = Vector2(18, 6)
		visual.position = Vector2(6, -3)


## Coloca el sprite del ícono del arma activa en la mano. Devuelve false si no hay ícono o pose.
func _apply_weapon_sprite(fallback_rect: ColorRect) -> bool:
	var pose: Dictionary = ItemIconsScript.get_weapon_pose(current_weapon)
	var icon: Texture2D = ItemIconsScript.get_icon_for(current_weapon) as Texture2D
	if pose.is_empty() or icon == null:
		return false

	if _weapon_sprite == null or not is_instance_valid(_weapon_sprite):
		_weapon_sprite = Sprite2D.new()
		_weapon_sprite.name = "WeaponSprite"
		_weapon_sprite.centered = false
		weapon_pivot.add_child(_weapon_sprite)

	var grip: Vector2 = pose.get("grip", Vector2(8.0, 8.0)) as Vector2
	var scale_factor: float = float(pose.get("scale", 1.5)) * WEAPON_SCALE
	scale_factor *= float(WeaponMotion.profile_for(current_weapon).get("scale", 1.0))
	var tip_x: float = float(pose.get("tip_x", 15.0))

	_weapon_sprite.texture = icon
	# Arte HD (pose con "file"): filtro lineal; los íconos pixel art 16x16 conservan el filtro de vecino más cercano
	_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if pose.has("file") else CanvasItem.TEXTURE_FILTER_NEAREST
	_weapon_sprite.offset = -grip
	_weapon_sprite.scale = Vector2(scale_factor, scale_factor)
	_sprite_rest_rotation = deg_to_rad(float(pose.get("rot_deg", 0.0)))
	_sprite_rest_position = Vector2(HAND_OFFSET_X, 0.0)
	# Cada arma se sostiene a su manera (ver weapon_motion.gd)
	var hold: Dictionary = WeaponMotion.profile_for(current_weapon).get("hold", {}) as Dictionary
	if not hold.is_empty():
		var hold_pos: Vector2 = hold.get("pos", Vector2.ZERO) as Vector2
		if current_weapon.weapon_type == WeaponData.WeaponType.MELEE:
			_sprite_rest_position += hold_pos
			_sprite_rest_rotation += deg_to_rad(float(hold.get("rot_deg", 0.0)))
		else:
			# Armas de fuego: solo se adelanta, para que el cañón y los disparos sigan sobre la línea de puntería
			_sprite_rest_position.x += hold_pos.x
	_weapon_sprite.rotation = _sprite_rest_rotation
	_weapon_sprite.position = _sprite_rest_position
	_weapon_sprite.visible = true

	if fallback_rect != null:
		fallback_rect.visible = false

	# La boca del cañón queda en la punta del arma dibujada
	if current_weapon.weapon_type == WeaponData.WeaponType.RANGED and muzzle != null:
		muzzle.position = Vector2(_sprite_rest_position.x + (tip_x - grip.x) * scale_factor, 0.0)
	return true


func _cancel_hand_tween() -> void:
	if _hand_tween != null and _hand_tween.is_valid():
		_hand_tween.kill()
	_hand_tween = null
	if _weapon_sprite != null and is_instance_valid(_weapon_sprite):
		_weapon_sprite.position = _sprite_rest_position
		_weapon_sprite.rotation = _sprite_rest_rotation


func _has_weapon_sprite() -> bool:
	return _weapon_sprite != null and is_instance_valid(_weapon_sprite) and _weapon_sprite.visible


## Golpe de retroceso del arma de fuego al disparar: se echa hacia atrás y el cañón sube (ver `kick` en weapon_motion.gd).
func _play_weapon_kick() -> void:
	var kick: Dictionary = WeaponMotion.profile_for(current_weapon).get("kick", {}) as Dictionary
	var power: float = 1.0
	if current_weapon != null:
		power = clampf(current_weapon.recoil_force / 60.0, 0.6, 2.0)
	var back: float = float(kick.get("back", 3.0 * power))
	var climb: float = float(kick.get("climb_deg", 4.0 * power))
	var time: float = float(kick.get("time", 0.12))
	# Combo de disparo sostenido (automáticas): el cañón sube de a poco y se mece mientras dure la ráfaga
	var pattern: Dictionary = WeaponMotion.pattern_for(current_weapon)
	var burst_offset: float = 0.0
	var recover: float = 0.0
	if not pattern.is_empty():
		var now: int = Time.get_ticks_msec()
		if now - _last_shot_msec <= int(float(pattern.get("window", 0.2)) * 1000.0):
			_burst_count += 1
		else:
			_burst_count = 0
		_last_shot_msec = now
		var lift: float = minf(float(_burst_count) * float(pattern.get("climb_step", 1.0)), float(pattern.get("max_climb", 6.0)))
		var sway: float = float(pattern.get("sway", 0.0)) * (1.0 if _burst_count % 2 == 0 else -1.0) * minf(float(_burst_count), 3.0) / 3.0
		burst_offset = deg_to_rad(-lift + sway)
		recover = float(pattern.get("recover", 0.25))
	last_motion = {"body": [], "length": time, "recoil": float(kick.get("body", 1.0)) * (1.0 + minf(float(_burst_count), 8.0) * 0.04)}
	if not _has_weapon_sprite():
		return
	_cancel_hand_tween()
	var settle_rot: float = _sprite_rest_rotation + burst_offset
	_weapon_sprite.position = _sprite_rest_position + Vector2(-back, 0.0) * WEAPON_SCALE
	_weapon_sprite.rotation = settle_rot - deg_to_rad(climb)
	_hand_tween = create_tween()
	_hand_tween.set_parallel(true)
	_hand_tween.tween_property(_weapon_sprite, "position", _sprite_rest_position, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hand_tween.tween_property(_weapon_sprite, "rotation", settle_rot, time * 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if recover > 0.0 and not is_zero_approx(burst_offset):
		# Si no llega otro disparo, el arma vuelve al reposo (el siguiente disparo mata este tween)
		_hand_tween.chain().tween_interval(float(pattern.get("window", 0.2)))
		_hand_tween.chain().tween_property(_weapon_sprite, "rotation", _sprite_rest_rotation, recover).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Tajo del arma en mano: recorre el mismo arco y duración que el barrido del MeleeHitbox.
## En local el arma siempre va de -arco/2 a +arco/2 (el pivote espeja el eje Y al apuntar a la izquierda).
func _play_melee_swing(arc_degrees: float, duration: float) -> void:
	if not _has_weapon_sprite():
		return
	_cancel_hand_tween()
	var keys: Array = _current_swing.get("keys", []) as Array
	if keys.size() >= 2:
		_play_keyed_swing(keys, swing_time_total(duration))
		return
	var half_arc: float = deg_to_rad(arc_degrees * 0.5)
	var swing_time: float = maxf(duration, 0.05)
	_weapon_sprite.rotation = _sprite_rest_rotation - half_arc
	_weapon_sprite.position = _sprite_rest_position + Vector2(-2.0, 0.0) * WEAPON_SCALE
	_hand_tween = create_tween()
	_hand_tween.set_parallel(true)
	_hand_tween.tween_property(_weapon_sprite, "rotation", _sprite_rest_rotation + half_arc, swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hand_tween.tween_property(_weapon_sprite, "position", _sprite_rest_position + Vector2(3.0, 0.0) * WEAPON_SCALE, swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Vuelta suave a la posición de reposo
	_hand_tween.chain().tween_property(_weapon_sprite, "rotation", _sprite_rest_rotation, 0.12)
	_hand_tween.tween_property(_weapon_sprite, "position", _sprite_rest_position, 0.12)

	# Estela: copias del arma que se desvanecen detrás del filo durante el tajo
	var trail: Tween = create_tween()
	var steps: int = 6
	for i in range(steps):
		trail.tween_callback(_spawn_swing_ghost)
		trail.tween_interval(swing_time / float(steps))


## Duración total de la animación del tajo actual (swing_duration * length del perfil).
func swing_time_total(duration: float) -> float:
	return maxf(duration, 0.05) * float(_current_swing.get("length", 1.0))


## Tajo animado con los fotogramas del perfil del arma: posición y rotación relativas al reposo.
func _play_keyed_swing(keys: Array, total: float) -> void:
	var first: Dictionary = keys[0] as Dictionary
	_weapon_sprite.position = _sprite_rest_position + (first.get("pos", Vector2.ZERO) as Vector2)
	_weapon_sprite.rotation = _sprite_rest_rotation + deg_to_rad(float(first.get("rot", 0.0)))
	_hand_tween = create_tween()
	var prev_t: float = float(first.get("t", 0.0))
	for i in range(1, keys.size()):
		var key: Dictionary = keys[i] as Dictionary
		var t: float = float(key.get("t", 1.0))
		var seg: float = maxf((t - prev_t) * total, 0.001)
		prev_t = t
		var trans: Tween.TransitionType = Tween.TRANS_LINEAR
		var ease_mode: Tween.EaseType = Tween.EASE_IN_OUT
		match str(key.get("ease", "")):
			"out":
				trans = Tween.TRANS_QUAD
				ease_mode = Tween.EASE_OUT
			"in":
				trans = Tween.TRANS_QUAD
				ease_mode = Tween.EASE_IN
			"inout":
				trans = Tween.TRANS_SINE
				ease_mode = Tween.EASE_IN_OUT
		var target_pos: Vector2 = _sprite_rest_position + (key.get("pos", Vector2.ZERO) as Vector2)
		var target_rot: float = _sprite_rest_rotation + deg_to_rad(float(key.get("rot", 0.0)))
		_hand_tween.tween_property(_weapon_sprite, "position", target_pos, seg).set_trans(trans).set_ease(ease_mode)
		_hand_tween.parallel().tween_property(_weapon_sprite, "rotation", target_rot, seg).set_trans(trans).set_ease(ease_mode)

	# Estela durante la primera mitad de la animación (la parte del golpe)
	var trail: Tween = create_tween()
	var steps: int = 6
	for i in range(steps):
		trail.tween_callback(_spawn_swing_ghost)
		trail.tween_interval(total * 0.5 / float(steps))


## Deja una copia translúcida del arma en su pose actual que se desvanece (estela del tajo).
func _spawn_swing_ghost() -> void:
	if not _has_weapon_sprite() or weapon_pivot == null:
		return
	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = _weapon_sprite.texture
	ghost.centered = false
	ghost.offset = _weapon_sprite.offset
	ghost.texture_filter = _weapon_sprite.texture_filter
	ghost.position = _weapon_sprite.position
	ghost.rotation = _weapon_sprite.rotation
	ghost.scale = _weapon_sprite.scale
	ghost.modulate = Color(0.75, 0.92, 1.0, 0.55)
	weapon_pivot.add_child(ghost)
	weapon_pivot.move_child(ghost, _weapon_sprite.get_index())
	var fade: Tween = ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, 0.2)
	fade.tween_callback(ghost.queue_free)


## Recarga propia del arma (ver `RELOADS` en weapon_motion.gd): cargador, tambor de revólver bala a bala,
## cartuchos de escopeta con bombeo, cerrojo o bidón. Dura lo mismo que `reload_time`; cada fotograma puede
## disparar un sonido de mecanismo (`reload_in`, `reload_shell`, `reload_rack`, `reload_vent`).
func _play_reload_animation(duration: float) -> void:
	if not _has_weapon_sprite():
		return
	_cancel_hand_tween()
	var keys: Array = WeaponMotion.reload_keys(current_weapon)
	if keys.size() < 2:
		return
	var total: float = maxf(duration, 0.2)
	_hand_tween = create_tween()
	var prev_t: float = float((keys[0] as Dictionary).get("t", 0.0))
	for i in range(1, keys.size()):
		var key: Dictionary = keys[i] as Dictionary
		var t: float = float(key.get("t", 1.0))
		var seg: float = maxf((t - prev_t) * total, 0.001)
		prev_t = t
		var trans: Tween.TransitionType = Tween.TRANS_SINE
		var ease_mode: Tween.EaseType = Tween.EASE_IN_OUT
		if str(key.get("ease", "")) == "back":
			trans = Tween.TRANS_BACK
			ease_mode = Tween.EASE_OUT
		var target_pos: Vector2 = _sprite_rest_position + (key.get("pos", Vector2.ZERO) as Vector2) * WEAPON_SCALE
		var target_rot: float = _sprite_rest_rotation + deg_to_rad(float(key.get("rot", 0.0)))
		_hand_tween.tween_property(_weapon_sprite, "position", target_pos, seg).set_trans(trans).set_ease(ease_mode)
		_hand_tween.parallel().tween_property(_weapon_sprite, "rotation", target_rot, seg).set_trans(trans).set_ease(ease_mode)
		if key.has("sound"):
			_hand_tween.tween_callback(_play_reload_sound.bind(key["sound"] as StringName))


func _play_reload_sound(sound: StringName) -> void:
	GameFeel.sfx(self, sound, Vector2.INF, -5.0, randf_range(0.95, 1.05))



## Cicla hacia adelante o hacia atrás en el inventario de armas.
func cycle_weapon(offset: int) -> void:
	if weapons.is_empty():
		return
	var new_index: int = posmod(current_weapon_index + offset, weapons.size())
	select_weapon(new_index)


## Alterna entre las dos primeras armas (útil para el botón Y / Triángulo).
func toggle_weapon() -> void:
	cycle_weapon(1)


## Activa o desactiva el modo de depuración de munición infinita / sin cooldowns.
func set_infinite_ammo(enabled: bool) -> void:
	infinite_ammo = enabled
	infinite_ammo_toggled.emit(infinite_ammo)
	var state_text: String = "ACTIVADA" if infinite_ammo else "DESACTIVADA"
	print("[Debug] Munición infinita y sin enfriamiento: %s" % state_text)


## Retorna el DPS sostenido del arma activa actualmente equipada teniendo en cuenta multiplicadores del jugador.
func get_current_sustained_dps() -> float:
	if current_weapon == null:
		return 0.0
	var raw_dps: float = current_weapon.get_current_sustained_dps()
	var dmg_mult: float = 1.0
	if player != null and player.stats_manager != null:
		dmg_mult = player.stats_manager.get_damage_multiplier()
	return raw_dps * dmg_mult


## Retorna el daño efectivo por perdigón/impacto del arma activa considerando runas y stats del jugador.
func get_current_effective_impact_damage() -> float:
	if current_weapon == null:
		return 0.0
	var dmg_mult: float = 1.0
	if player != null and player.stats_manager != null:
		dmg_mult = player.stats_manager.get_damage_multiplier()
	return current_weapon.get_effective_damage() * dmg_mult


## Retorna la cadencia efectiva en disparos por segundo.
func get_current_fire_rate() -> float:
	if current_weapon == null:
		return 0.0
	return current_weapon.fire_rate


## Retorna la penetración de armadura porcentual del arma activa (0% a 100%).
func get_current_armor_penetration_percentage() -> float:
	if current_weapon == null:
		return 0.0
	return current_weapon.armor_penetration * 100.0
