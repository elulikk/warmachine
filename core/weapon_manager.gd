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
## La mano secundaria cambió de arma (o quedó libre). Lo emite el administrador de la mano principal.
signal offhand_changed(weapon: WeaponData)

const ChainLightning = preload("res://combat/chain_lightning.gd")
const ItemIconsScript = preload("res://ui/components/item_icons.gd")
const WeaponMotion = preload("res://core/art/weapon_motion.gd")
const ShotFx = preload("res://combat/shot_fx.gd")
const FireVfx = preload("res://combat/fire_vfx.gd")
const ReloadDebris = preload("res://combat/reload_debris.gd")
const SettingsScript = preload("res://core/settings.gd")
## Segundos que tarda la reserva en recuperar un cargador completo del arma.
## Las recargas duran esto por el `reload_time` de cada arma (más lentas que lo que dice el recurso).
const RELOAD_TIME_MULT: float = 1.5
## Segundos que tarda la reserva en recuperar un cargador completo del arma (era 10).
const RESERVE_SECONDS_PER_MAGAZINE: float = 30.0

## Mano que maneja este nodo. El `WeaponManager` del jugador es la mano principal (clic izquierdo) y crea por código
## un segundo `WeaponManager` hijo, `offhand`, para la mano secundaria (clic derecho, acción `attack_secondary`).
## Comparten el diccionario de cargadores: un arma conserva su munición al cambiar de mano.
enum Hand { MAIN, OFF }

## Estado de la mano secundaria (ver `get_offhand_state()`).
enum OffhandState { EMPTY, READY, BLOCKED_TWO_HANDS, BLOCKED_SAME_WEAPON }

## Posición del arma secundaria respecto de la principal (espacio del pivote: +x al apuntado, +y hacia abajo).
## Arte provisional: queda más atrás y un poco más abajo, sostenida por el brazo de atrás.
const OFFHAND_SPRITE_OFFSET: Vector2 = Vector2(-2.0, 4.0)
## Escudo levantado (clic derecho mantenido): desplazamiento del sprite desde la mano, en el pivote (+x = hacia la puntería).
const SHIELD_RAISE_OFFSET: Vector2 = Vector2(14.0, -4.0)
const SHIELD_RAISE_SPEED: float = 10.0

## Cuándo (fracción de `reload_time`) cae lo que suelta el arma al recargar, según qué suelta.
const RELOAD_DROP_TIMING: Dictionary = {
	WeaponData.ReloadDrop.CYLINDER: 0.16,
	WeaponData.ReloadDrop.MAGAZINE: 0.2,
	WeaponData.ReloadDrop.SHELLS: 0.14,
	WeaponData.ReloadDrop.CANISTER: 0.28,
}

## Escala del cuerpo del jugador respecto del sprite original de 32x32 (ver `Visuals.scale` en player.tscn).
## Mueve donde está la mano y el centro del cuerpo.
const BODY_SCALE: float = 2.0

## Cuánto se amplía el arma en mano sobre su tamaño base (`ItemIcons.WEAPON_POSES`).
## Es menor que BODY_SCALE a propósito: las armas no necesitan crecer tanto como el cuerpo.
const WEAPON_SCALE: float = 1.5

## Martillo en el aire: velocidad de caída forzada (px/s) y tiempo máximo esperando el aterrizaje (s).
const SLAM_FALL_SPEED: float = 1100.0
const SLAM_MAX_WAIT: float = 1.5

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
## Munición de reserva por arma (balas fuera del cargador). Las recargas la consumen y se rellena sola con el
## tiempo (`RESERVE_SECONDS_PER_MAGAZINE`): es "infinita" pero con tope, así no se puede abusar del arma.
var weapon_reserves: Dictionary[WeaponData, int] = {}
var _reserve_progress: Dictionary[WeaponData, float] = {}
## Tope de reserva = tantos cargadores completos del arma (más adelante se puede mejorar).
var reserve_magazines: int = 6
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
## Desvío real de la bala hacia arriba al mantener el disparo (id del arma -> grados por disparo seguido y tope).
## Se reinicia al pausar más que la ventana de `PATTERNS`, así que obliga a disparar en ráfagas.
const SUSTAINED_CLIMB: Dictionary = {
	"m4": {"step": 1.4, "max": 10.0},
	"smg": {"step": 1.0, "max": 10.0},
	"mp5": {"step": 1.0, "max": 9.0},
}
var _swing_index: int = 0
var _current_swing: Dictionary = {}

## Qué mano maneja este nodo. Lo fija quien lo crea antes de agregarlo al árbol.
var hand: Hand = Hand.MAIN
## Mano principal: el administrador de la mano secundaria (hijo creado en `_ready`).
var offhand: WeaponManager = null
## Mano principal: arma elegida para la mano secundaria (siempre una del arsenal). Puede estar bloqueada
## por un arma a dos manos en la principal; en ese caso `offhand.current_weapon` es null.
var offhand_weapon: WeaponData = null
## Mano secundaria: el administrador de la mano principal.
var main_manager: WeaponManager = null

var _off_pressed: bool = false
var _off_held: bool = false
## 0 = escudo bajado, 1 = escudo levantado enfrente del personaje (ver `_update_shield_pose`).
var _shield_raise: float = 0.0
var _debris_tween: Tween = null
var _offhand_sprite_name: String = "WeaponSprite"


func _ready() -> void:
	if hand == Hand.OFF:
		_ready_offhand()
		return
	player = owner as Player
	GameFeel.sfx_prewarm(self)
	_ensure_weapons()
	if not weapons.is_empty():
		select_weapon(clampi(current_weapon_index, 0, weapons.size() - 1))
	else:
		current_weapon = null
		_update_weapon_visual()
		weapon_changed.emit(null, -1)
	_create_offhand_manager()


# ==============================================================================
# Mano secundaria
# ==============================================================================

## Mano principal: crea el administrador de la mano secundaria (otro WeaponManager que comparte pivote y cargadores).
func _create_offhand_manager() -> void:
	if offhand != null or weapon_pivot == null:
		return
	var off: WeaponManager = WeaponManager.new()
	off.hand = Hand.OFF
	off.name = "OffhandManager"
	off.main_manager = self
	off.player = player
	off.weapon_pivot = weapon_pivot
	off.weapon_magazines = weapon_magazines
	off.weapon_reserves = weapon_reserves
	off.infinite_ammo = infinite_ammo
	off.free_ammo_active = free_ammo_active
	offhand = off
	add_child(off)


## Mano secundaria: prepara muzzle propio y sprite (oculto hasta que haya arma).
func _ready_offhand() -> void:
	_offhand_sprite_name = "OffhandSprite"
	if weapon_pivot != null:
		var marker: Marker2D = Marker2D.new()
		marker.name = "OffhandMuzzle"
		weapon_pivot.add_child(marker)
		muzzle = marker
	current_weapon = null
	_update_weapon_visual()


## Estado de la mano secundaria (para la barra de acceso rápido).
func get_offhand_state() -> OffhandState:
	if hand == Hand.OFF:
		return main_manager.get_offhand_state() if main_manager != null else OffhandState.EMPTY
	if offhand_weapon == null:
		return OffhandState.EMPTY
	if current_weapon != null and current_weapon.is_two_handed():
		return OffhandState.BLOCKED_TWO_HANDS
	if current_weapon == offhand_weapon:
		return OffhandState.BLOCKED_SAME_WEAPON
	return OffhandState.READY


## true si el arma puede ir en la mano secundaria: está en el arsenal, es de una mano o escudo
## y no es la que sostiene la mano principal.
func can_equip_offhand(weapon: WeaponData) -> bool:
	return weapon != null and weapons.has(weapon) and weapon.can_be_offhand()


## Mano principal: elige el arma de la mano secundaria (null la deja libre). Devuelve false si no es válida.
func set_offhand_weapon(weapon: WeaponData) -> bool:
	if hand == Hand.OFF:
		return main_manager.set_offhand_weapon(weapon) if main_manager != null else false
	if weapon != null and not can_equip_offhand(weapon):
		return false
	if weapon == offhand_weapon:
		return true
	offhand_weapon = weapon
	_refresh_offhand()
	offhand_changed.emit(offhand_weapon)
	return true


## Mano principal: acomoda la mano secundaria según el arma de la principal. Un arma a dos manos (o la misma
## arma) deja la secundaria vacía sin olvidar la elección: vuelve sola al cambiar a un arma de una mano.
func _refresh_offhand() -> void:
	if hand == Hand.OFF or offhand == null:
		return
	var active: WeaponData = null
	if offhand_weapon != null and get_offhand_state() == OffhandState.READY:
		active = offhand_weapon
	offhand._equip_offhand(active)


## Mano secundaria: pone o saca el arma. Cancela la recarga y vuelve a dibujar.
func _equip_offhand(weapon: WeaponData) -> void:
	if current_weapon == weapon:
		return
	cancel_reload()
	current_weapon = weapon
	fire_cooldown_timer = 0.0
	_off_pressed = false
	if weapon != null:
		# La munición ya está en el diccionario compartido; solo se avisa para refrescar el HUD si hace falta
		ammo_changed.emit(get_weapon_ammo(weapon), weapon.magazine_size)
	_update_weapon_visual()


## Mano principal: si el arma elegida para la secundaria salió del arsenal (vendida, guardada), se suelta.
func _validate_offhand() -> void:
	if offhand_weapon != null and not weapons.has(offhand_weapon):
		set_offhand_weapon(null)


## Mano secundaria: clic derecho (o su equivalente). Se lee de `_unhandled_input` y no por sondeo, así un clic
## sobre la interfaz (quitar un casillero, cerrar una ventana) no dispara.
func _unhandled_input(event: InputEvent) -> void:
	if hand != Hand.OFF:
		return
	if event.is_action_pressed("attack_secondary"):
		# Prioridad: la función secundaria del arma principal gana sobre el arma de la mano 2
		if main_manager != null and main_manager.current_weapon != null and main_manager.current_weapon.has_secondary_function():
			return
		_off_pressed = true
		_off_held = true


## Lectura del gatillo de esta mano: semiautomática por pulsación, automática mientras se mantiene.
func _read_trigger() -> bool:
	if hand == Hand.OFF:
		var edge: bool = _off_pressed
		_off_pressed = false
		return _off_held if current_weapon.is_automatic else edge
	if current_weapon.is_automatic:
		return Input.is_action_pressed("attack")
	return Input.is_action_just_pressed("attack")


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
	
	if hand == Hand.MAIN:
		_regen_reserves(delta)
		_handle_debug_input()
		_validate_offhand()
	else:
		# Si el botón se soltó (o la liberó la interfaz) deja de ser un gatillo mantenido
		_off_held = _off_held and Input.is_action_pressed("attack_secondary")
		if current_weapon == null:
			_off_pressed = false
		_update_shield_pose(delta)
	_handle_firing_input()


## true si la mano secundaria sostiene un escudo y el clic derecho está mantenido: bloquea daño.
func is_shield_raised() -> bool:
	if hand != Hand.OFF or current_weapon == null or current_weapon.grip != WeaponData.Grip.SHIELD:
		return false
	return Input.is_action_pressed("attack_secondary")


## Sube o baja el escudo según el clic derecho: levantado queda enfrente del personaje, en la dirección de la puntería.
func _update_shield_pose(delta: float) -> void:
	_shield_raise = move_toward(_shield_raise, 1.0 if is_shield_raised() else 0.0, delta * SHIELD_RAISE_SPEED)
	if current_weapon == null or current_weapon.grip != WeaponData.Grip.SHIELD:
		_shield_raise = 0.0
		return
	if _weapon_sprite == null or not is_instance_valid(_weapon_sprite):
		return
	_weapon_sprite.position = _sprite_rest_position + SHIELD_RAISE_OFFSET * _shield_raise
	_weapon_sprite.rotation = lerp_angle(_sprite_rest_rotation, 0.0, _shield_raise)


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


## Tope de la reserva de un arma con cargador (0 si no usa munición).
func get_reserve_max(weapon: WeaponData) -> int:
	if weapon == null or weapon.weapon_type == WeaponData.WeaponType.MELEE or weapon.magazine_size <= 0:
		return 0
	return weapon.magazine_size * reserve_magazines


## Balas de reserva del arma (la primera vez arranca llena).
func get_reserve(weapon: WeaponData) -> int:
	if weapon == null:
		return 0
	if not weapon_reserves.has(weapon):
		weapon_reserves[weapon] = get_reserve_max(weapon)
	return weapon_reserves[weapon]


func set_reserve(weapon: WeaponData, amount: int) -> void:
	if weapon == null:
		return
	weapon_reserves[weapon] = clampi(amount, 0, get_reserve_max(weapon))
	if weapon == current_weapon:
		ammo_changed.emit(get_weapon_ammo(weapon), weapon.magazine_size)


## Cargador y reserva de todas las armas al máximo (al subir de nivel).
func refill_all_ammo() -> void:
	for weapon: WeaponData in weapons:
		if weapon == null or weapon.magazine_size <= 0 or weapon.weapon_type == WeaponData.WeaponType.MELEE:
			continue
		weapon_magazines[weapon] = weapon.magazine_size
		weapon_reserves[weapon] = get_reserve_max(weapon)
		_reserve_progress[weapon] = 0.0
	if current_weapon != null and current_weapon.magazine_size > 0:
		ammo_changed.emit(get_weapon_ammo(current_weapon), current_weapon.magazine_size)
	if offhand != null and offhand.current_weapon != null:
		offhand.ammo_changed.emit(get_weapon_ammo(offhand.current_weapon), offhand.current_weapon.magazine_size)


## La reserva de cada arma sube sola con el tiempo hasta su tope.
func _regen_reserves(delta: float) -> void:
	for weapon: WeaponData in weapons:
		var cap: int = get_reserve_max(weapon)
		if cap <= 0:
			continue
		var reserve: int = get_reserve(weapon)
		if reserve >= cap:
			_reserve_progress[weapon] = 0.0
			continue
		var progress: float = float(_reserve_progress.get(weapon, 0.0)) + delta * float(weapon.magazine_size) / RESERVE_SECONDS_PER_MAGAZINE
		var gained: int = int(progress)
		_reserve_progress[weapon] = progress - float(gained)
		if gained > 0:
			weapon_reserves[weapon] = mini(cap, reserve + gained)
			if weapon == current_weapon:
				ammo_changed.emit(get_weapon_ammo(weapon), weapon.magazine_size)


## Inicia el proceso de recarga si el arma tiene cargador y no está llena.
func start_reload() -> void:
	if current_weapon == null or is_reloading or free_ammo_active:
		return
	if current_weapon.weapon_type == WeaponData.WeaponType.MELEE or current_weapon.magazine_size <= 0:
		return
	
	var cur_ammo: int = get_weapon_ammo(current_weapon)
	if cur_ammo >= current_weapon.magazine_size:
		return
	# Sin balas de reserva no hay recarga (infinite_ammo es el atajo de depuración)
	if not infinite_ammo and get_reserve(current_weapon) <= 0:
		return
	
	is_reloading = true
	var reload_secs: float = current_weapon.reload_time * RELOAD_TIME_MULT
	reload_timer = reload_secs
	reload_started.emit(reload_secs)
	GameFeel.sfx(self, &"reload_out", Vector2.INF, -4.0)
	_play_reload_animation(reload_secs)
	_schedule_reload_debris(current_weapon, current_weapon.magazine_size - cur_ammo)
	weapon_changed.emit(current_weapon, current_weapon_index)


## Cancela la recarga en curso (por ejemplo al cambiar de arma).
func cancel_reload() -> void:
	if is_reloading:
		is_reloading = false
		reload_timer = 0.0
		_cancel_hand_tween()
	_kill_debris_tween()


## Activa o desactiva el modo sin recarga. Al activarlo cancela la recarga en curso y llena el cargador.
func set_free_ammo(enabled: bool) -> void:
	free_ammo_active = enabled
	if hand == Hand.MAIN and offhand != null:
		offhand.set_free_ammo(enabled)
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
		var missing: int = current_weapon.magazine_size - get_weapon_ammo(current_weapon)
		var taken: int = missing if infinite_ammo else mini(missing, get_reserve(current_weapon))
		if not infinite_ammo:
			weapon_reserves[current_weapon] = get_reserve(current_weapon) - taken
		set_weapon_ammo(current_weapon, get_weapon_ammo(current_weapon) + taken)
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
	if current_weapon == null or (hand == Hand.MAIN and hand_locked):
		return
	# El escudo se sostiene, no ataca
	if current_weapon.grip == WeaponData.Grip.SHIELD:
		return

	# Recarga manual con tecla R o acción 'reload'
	# Solo por acción (R por defecto): así respeta la reasignación de Opciones > Controles
	if Input.is_action_just_pressed("reload"):
		start_reload()
		return
	
	# Durante la recarga, bloquear la ejecución de fire()
	if is_reloading:
		return
	
	var wants_to_fire: bool = _read_trigger()
	
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
	var armor_pen: float = current_weapon.get_armor_penetration()
	
	# Consultar modificadores de runas acumulados
	var bounces: int = current_weapon.get_total_bounces()
	var pierces: int = current_weapon.get_total_pierce()
	var forks: int = current_weapon.get_total_forks()
	
	# 2. Disparar proyectil(es) (soporta disparo único o perdigones en abanico)
	var pool: ProjectilePool = _get_projectile_pool()
	var pellets: int = maxi(1, current_weapon.pellets_per_shot)
	var spread_deg: float = current_weapon.spread_angle_degrees
	var base_angle: float = aim_dir.angle()
	_register_burst_shot()
	var climb_rot: float = _sustained_climb_radians(aim_dir)

	for i in range(pellets):
		var pellet_dir: Vector2 = aim_dir
		if pellets > 1 and spread_deg > 0.0:
			var step: float = deg_to_rad(spread_deg) / float(pellets - 1)
			var angle_offset: float = -deg_to_rad(spread_deg) * 0.5 + float(i) * step
			pellet_dir = Vector2.from_angle(base_angle + angle_offset)
		elif pellets == 1 and spread_deg > 0.0:
			# Disparo único: desvío aleatorio dentro del cono (spread_deg es el ángulo total)
			pellet_dir = aim_dir.rotated(deg_to_rad(randf_range(-0.5, 0.5) * spread_deg))

		pellet_dir = pellet_dir.rotated(climb_rot)

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
		
		# El pool solo reutiliza el proyectil estándar; las escenas propias (gotas) van por fuera.
		if pool != null and current_weapon.projectile_scene.resource_path == "res://combat/projectile.tscn":
			var pooled: Projectile = pool.get_projectile(spawn_pos, pellet_dir, payload, current_weapon.projectile_speed, bounces, pierces, forks, current_weapon.projectile_sprite) as Projectile
			if pooled != null:
				pooled.impact_scene = current_weapon.impact_scene
		else:
			# Fallback de reserva si no existe pool en la escena
			var fallback_node: Node = current_weapon.projectile_scene.instantiate()
			if fallback_node is Projectile:
				var proj: Projectile = fallback_node as Projectile
				proj.global_position = spawn_pos
				proj.rotation = pellet_dir.angle()
				proj.setup(current_weapon.projectile_speed, payload, bounces, pierces, forks, current_weapon.projectile_sprite)
				proj.impact_scene = current_weapon.impact_scene
				var container: Node = get_tree().current_scene
				if container == null:
					container = owner.get_parent() if owner != null else get_parent()
				if container == null:
					container = get_tree().root
				container.add_child(fallback_node)
	
	_play_weapon_kick()
	# Los lanzallamas (combustible y plasma) tienen su propio chorro: sin destello ni humo de bala encima.
	if current_weapon.family == WeaponData.WeaponFamily.FLAMETHROWER or current_weapon.projectile_scene.resource_path == "res://combat/fuel_droplet.tscn":
		FireVfx.spawn_jet(get_tree().current_scene, spawn_pos, aim_dir)
	else:
		ShotFx.muzzle_flash(self, spawn_pos, aim_dir)
		ShotFx.muzzle_smoke(self, spawn_pos, aim_dir)
	GameFeel.sfx_weapon_fire(self, current_weapon)

	# 3. Aplicar fuerza de retroceso sobre el jugador
	if player != null and current_weapon.recoil_force > 0.0 and not player.knockback_immune:
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
	if swung.creates_ground_shockwave and player != null and not player.is_on_floor():
		await _wait_for_landing(swung)
	else:
		await get_tree().create_timer(delay).timeout
	if current_weapon != swung or player == null or not is_instance_valid(player):
		return
	_melee_strike(true)


## Martillo en el aire: fuerza la caída hasta tocar el piso (o hasta SLAM_MAX_WAIT) para que el golpe caiga al aterrizar.
func _wait_for_landing(weapon: WeaponData) -> void:
	var waited: float = 0.0
	while current_weapon == weapon and player != null and is_instance_valid(player) and not player.is_on_floor() and waited < SLAM_MAX_WAIT:
		# Se fija antes de que corra la física del jugador, así su desaceleración hacia la caída máxima no lo frena
		player.velocity.y = SLAM_FALL_SPEED
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()


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
		3.0,
		current_weapon.get_armor_penetration()
	)
	payload.ice_duration = current_weapon.ice_duration
	payload.ice_speed_multiplier = current_weapon.ice_speed_multiplier

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
	# Rayo en cadena (Mjolnir): el primer enemigo golpeado del tajo lanza el rayo que rebota entre los cercanos
	if current_weapon.chain_lightning_bounces > 0:
		melee_instance.target_hit.connect(_on_chain_strike.bind(current_weapon, final_damage), CONNECT_ONE_SHOT)

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
		_spawn_ground_shockwave(spawn_pos, aim_dir, _impact_world_position())
		GameFeel.shake(self, 9.0, 0.3)
		GameFeel.hit_stop(self, 0.07)

	# Si tiene recoil force, empujar al jugador
	if player != null and current_weapon.recoil_force > 0.0 and not player.knockback_immune:
		player.velocity -= aim_dir * current_weapon.recoil_force
	


## Golpe melee conectado con un arma de rayo en cadena: dispara la cadena desde el enemigo alcanzado.
func _on_chain_strike(target: Node, weapon: WeaponData, hit_damage: float) -> void:
	if not (target is Node2D) or not is_instance_valid(target) or player == null:
		return
	ChainLightning.spawn(self, target as Node2D, player, hit_damage * weapon.chain_lightning_damage_mult,
			weapon.chain_lightning_bounces, weapon.chain_lightning_range)


## Genera una onda de expansión física proyectada sobre el suelo más cercano.
## Con `head_pos` (cabeza del arma en el mundo) la onda nace justo debajo de ella, sobre el suelo.
func _spawn_ground_shockwave(from_pos: Vector2, aim_dir: Vector2, head_pos: Vector2 = Vector2.INF) -> void:
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
	var ray_lift: float = 16.0
	if head_pos != Vector2.INF:
		ground_pos = head_pos
		ray_lift = 40.0
	if player != null and player.is_inside_tree():
		var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			ground_pos + Vector2(0.0, -ray_lift),
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





## Punto de la cabeza del arma (`impact` del perfil, en px de la textura) en coordenadas del mundo; INF si no lo define.
func _impact_world_position() -> Vector2:
	var impact: Variant = WeaponMotion.profile_for(current_weapon).get("impact", null)
	if impact == null or not _has_weapon_sprite():
		return Vector2.INF
	var pose: Dictionary = ItemIconsScript.get_weapon_pose(current_weapon)
	var grip: Vector2 = pose.get("grip", Vector2.ZERO) as Vector2
	return _weapon_sprite.to_global((impact as Vector2) * ItemIconsScript.held_ratio(current_weapon) - grip)


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
## Caja de munición (engranaje del botín): recarga al instante el arma en mano, aunque esté a mitad de recarga.
## Con el cargador lleno no hace nada (el juego no tiene munición de reserva).
func add_ammo(_amount: int = 1) -> void:
	if current_weapon == null or current_weapon.weapon_type == WeaponData.WeaponType.MELEE or current_weapon.magazine_size <= 0:
		return
	if not is_reloading and get_weapon_ammo(current_weapon) >= current_weapon.magazine_size:
		return
	cancel_reload()
	finish_reload()



## Selecciona un arma por índice directo en el array.
func select_weapon(index: int) -> void:
	if weapons.is_empty():
		cancel_reload()
		current_weapon = null
		_update_weapon_visual()
		_refresh_offhand()
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
	_refresh_offhand()
	
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
	_refresh_offhand()
	weapon_changed.emit(null, -1)


## Dibuja el arma en mano con el mismo ícono pixel art del inventario (ver ItemIcons.WEAPON_POSES).
## Si el arma no tiene ícono ni pose, cae al rectángulo de color de siempre.
func _update_weapon_visual() -> void:
	if weapon_pivot == null:
		return
	var visual: ColorRect = weapon_pivot.get_node_or_null("WeaponVisual") as ColorRect if hand == Hand.MAIN else null
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
	var icon: Texture2D = ItemIconsScript.get_held_texture(current_weapon)
	if pose.is_empty() or icon == null:
		return false

	if _weapon_sprite == null or not is_instance_valid(_weapon_sprite):
		_weapon_sprite = Sprite2D.new()
		_weapon_sprite.name = _offhand_sprite_name
		_weapon_sprite.centered = false
		weapon_pivot.add_child(_weapon_sprite)
		if hand == Hand.OFF and main_manager != null and main_manager._has_weapon_sprite_node():
			# La secundaria se dibuja detrás de la principal
			weapon_pivot.move_child(_weapon_sprite, main_manager._weapon_sprite.get_index())

	var grip: Vector2 = pose.get("grip", Vector2(8.0, 8.0)) as Vector2
	var scale_factor: float = float(pose.get("scale", 1.5)) * WEAPON_SCALE
	scale_factor *= float(WeaponMotion.profile_for(current_weapon).get("scale", 1.0))
	var tip_x: float = float(pose.get("tip_x", 15.0))

	_weapon_sprite.texture = icon
	# Arte HD (pose con "file"): filtro lineal; los íconos pixel art 16x16 conservan el filtro de vecino más cercano
	_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if pose.has("file") else CanvasItem.TEXTURE_FILTER_NEAREST
	_weapon_sprite.offset = -grip
	_weapon_sprite.scale = Vector2(scale_factor, -scale_factor if bool(pose.get("flip_v", false)) else scale_factor)
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
	if hand == Hand.OFF:
		_sprite_rest_position += OFFHAND_SPRITE_OFFSET
	_weapon_sprite.rotation = _sprite_rest_rotation
	_weapon_sprite.position = _sprite_rest_position
	_weapon_sprite.visible = true

	if fallback_rect != null:
		fallback_rect.visible = false

	# La boca del cañón queda en la punta del arma dibujada
	if current_weapon.weapon_type == WeaponData.WeaponType.RANGED and muzzle != null:
		muzzle.position = Vector2(_sprite_rest_position.x + (tip_x - grip.x) * scale_factor, _sprite_rest_position.y)
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


func _has_weapon_sprite_node() -> bool:
	return _weapon_sprite != null and is_instance_valid(_weapon_sprite)


## Cuenta el disparo en la ráfaga actual: si pasó más de `window` s desde el anterior, la ráfaga empieza de cero.
func _register_burst_shot() -> void:
	var pattern: Dictionary = WeaponMotion.pattern_for(current_weapon)
	if pattern.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_shot_msec <= int(float(pattern.get("window", 0.2)) * 1000.0):
		_burst_count += 1
	else:
		_burst_count = 0
	_last_shot_msec = now


## Ángulo (rad) con que se desvía la bala por la ráfaga sostenida: hacia arriba de la pantalla, sea cual sea el lado al que apunta.
func _sustained_climb_radians(aim_dir: Vector2) -> float:
	var climb: Dictionary = SUSTAINED_CLIMB.get(WeaponMotion.id_of(current_weapon), {}) as Dictionary
	if climb.is_empty():
		return 0.0
	var deg: float = minf(float(_burst_count) * float(climb.get("step", 1.0)), float(climb.get("max", 8.0)))
	# Apuntando a la derecha, "arriba" es girar en sentido negativo; a la izquierda, en positivo
	var side: float = -1.0 if aim_dir.x >= 0.0 else 1.0
	return deg_to_rad(deg) * side


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


## Programa lo que suelta el arma al recargar (casquillos, cargador, cartuchos, bidón), según su familia.
## Cae cuando la animación de recarga llega a ese punto; si se cancela la recarga antes, no cae.
func _schedule_reload_debris(weapon: WeaponData, spent: int) -> void:
	_kill_debris_tween()
	var drop: int = weapon.get_reload_drop()
	if drop == WeaponData.ReloadDrop.NONE or SettingsScript.particle_scale() < ReloadDebris.MIN_DENSITY:
		return
	var delay: float = maxf(weapon.reload_time * RELOAD_TIME_MULT, 0.2) * float(RELOAD_DROP_TIMING.get(drop, 0.2))
	_debris_tween = create_tween()
	_debris_tween.tween_interval(delay)
	_debris_tween.tween_callback(_spawn_reload_debris.bind(weapon, drop, spent))


func _kill_debris_tween() -> void:
	if _debris_tween != null and _debris_tween.is_valid():
		_debris_tween.kill()
	_debris_tween = null


func _spawn_reload_debris(weapon: WeaponData, drop: int, spent: int) -> void:
	_debris_tween = null
	if not is_reloading or current_weapon != weapon or weapon_pivot == null:
		return
	var origin: Vector2 = _weapon_sprite.global_position if _has_weapon_sprite() else weapon_pivot.global_position
	var aim: Vector2 = weapon_pivot.get_aim_direction()
	var tint: Color = Color(1.0, 0.55, 0.2, 1.0) if weapon.family == WeaponData.WeaponFamily.FLAMETHROWER else Color(0.45, 0.95, 0.85, 1.0)
	ReloadDebris.spawn(self, drop, origin + Vector2(0.0, 4.0), aim, spent, tint)


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
	if hand == Hand.MAIN and offhand != null:
		offhand.infinite_ammo = enabled
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
	return current_weapon.get_armor_penetration() * 100.0
