class_name Player
extends CharacterBody2D
## Controlador principal del Jugador (2D Action Platformer).
## Administra la configuración de movimiento, timers de mecánicas de precisión
## (Coyote Time, Jump Buffer, Variable Jump), orientación y delega su comportamiento
## a una Máquina de Estados Finita (FSM).

signal facing_direction_changed(new_direction: int)
signal died

@export_group("Configuración")
## Recurso que contiene los parámetros físicos ajustables del movimiento.
@export var movement_data: PlayerMovementData

@onready var state_machine: StateMachine = $StateMachine
@onready var visuals: Node2D = get_node_or_null("Visuals")
@onready var sprite: CanvasItem = get_node_or_null("Sprite2D")
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("Visuals/AnimatedSprite2D") as AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var weapon_pivot: WeaponPivot = get_node_or_null("WeaponPivot")
@onready var weapon_manager: WeaponManager = get_node_or_null("WeaponManager")
@onready var stats_manager: StatsManager = get_node_or_null("StatsManager")
@onready var equipment_manager: EquipmentManager = get_node_or_null("EquipmentManager")
@onready var inventory_manager: InventoryManager = get_node_or_null("InventoryManager")
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox")

## Gestor de consumibles; se crea por código en _ready (no forma parte de player.tscn).
## Se carga por preload y no por class_name: run.bat no refresca el registro de clases globales.
const ConsumableManagerScript = preload("res://core/consumables/consumable_manager.gd")
var consumable_manager: ConsumableManagerScript = null
## Invocador de esqueletos de la espada Frostmourne (se crea en _ready).
const FrostmourneSummonerScript = preload("res://entities/allies/frostmourne_summoner.gd")
## Despide a mercenarios y drones con la tecla T (se crea en _ready).
const AllyDismisserScript = preload("res://entities/allies/ally_dismisser.gd")
## Aura visual de subida de nivel (estilo MU Online / WoW)
const LevelUpAuraScript = preload("res://entities/player/level_up_aura.gd")
const LowHealthFeedbackScript = preload("res://entities/player/low_health_feedback.gd")
const MirrorReflectorScript = preload("res://entities/shield/mirror_reflector.gd")
const EyeLaserScript = preload("res://entities/player/eye_laser.gd")
const CloakControllerScript = preload("res://entities/player/cloak_controller.gd")
const HamelinFluteScript = preload("res://entities/player/hamelin_flute_controller.gd")
const EnergyShieldScript = preload("res://entities/shield/energy_shield.gd")
const JetpackFxScript = preload("res://entities/player/jetpack_fx.gd")
## Capa de dibujo del jugador. Las piezas del esqueleto van de -3 (mochila) a +3 (mano): con base 4 todo el personaje
## queda delante del decorado del nivel (edificios, fondos y terreno en -1/0) sin cambiar su orden interno.
const PLAYER_Z: int = 4
const DamageNumberScene = preload("res://combat/damage_number.tscn")
var _level_up_aura: Node2D = null
## Destello al juntar experiencia: brillo actual (0..XP_GLOW_CAP) y cuándo se calculó (ms).
var _xp_glow: float = 0.0
var _xp_glow_msec: int = 0
var _xp_glow_tween: Tween = null
var _xp_halo: Node2D = null
## Disposición de la barra de acceso rápido ({"w": índice en el arsenal} | {"c": consumable_id} | null por casillero).
## La mantiene ui/hotbar.gd y la guarda SaveManager.
var hotbar_layout: Array = []
## Chaleco antibalas con el que arranca el personaje: fracción del daño de proyectiles que no pasa (0.30 = -30%).
var vest_projectile_reduction: float = 0.30
## Inmortal (nivel de pruebas): no recibe daño.
var invulnerable: bool = false


## Dirección hacia la que mira el personaje (1 = derecha, -1 = izquierda).
var facing_direction: int = 1:
	set(value):
		if value != 0 and value != facing_direction:
			facing_direction = value
			facing_direction_changed.emit(facing_direction)

## Timer para la mecánica 'Coyote Time' (0.15s por defecto).
## Permite saltar brevemente luego de caer o dejar una plataforma sin haber saltado.
var coyote_timer: float = 0.0

## Timer para la mecánica 'Jump Buffer' (0.10s por defecto).
## Registra la pulsación de salto anticipada antes de tocar el suelo.
var jump_buffer_timer: float = 0.0

## Contador dinámico de saltos restantes (permite doble salto y saltos múltiples).
var jumps_left: int = 1

## Habilidades de movilidad aumentada otorgadas por equipamiento
var can_wall_jump: bool = false
var has_jetpack: bool = false
var is_using_jetpack: bool = false
var jetpack_fuel: float = 100.0
@export var max_jetpack_fuel: float = 100.0
## Combustible por segundo con el jetpack encendido. Los sectores a cielo abierto bajan `jetpack_drain_mult` para
## poder subir muy alto (ver LevelBase.OPEN_SKY_TOP).
const JETPACK_DRAIN: float = 45.0
var jetpack_drain_mult: float = 1.0
var has_wings: bool = false
var max_flaps: int = 5
var current_flaps: int = 0
var has_magic_flight: bool = false
## Dash (Fase D): lo habilita el ítem `dash_module`. Un impulso horizontal corto sin gravedad; uno por salto en el aire.
const DASH_SPEED: float = 560.0
const DASH_TIME: float = 0.16
const DASH_COOLDOWN: float = 0.7
var can_dash: bool = false
## Casco Láser equipado: habilita la acción `eye_laser` (ver eye_laser.gd).
var has_eye_laser: bool = false
## Pechera de Hierro: el rayo sale del pecho y es azul (unirrayo) en vez de los ojos.
var laser_from_chest: bool = false
## Capa de Invisibilidad equipada y estado de invisibilidad (ver cloak_controller.gd). Los enemigos leen `is_invisible`.
var has_cloak: bool = false
## Flauta de Hamelin equipada: las ratas cercanas pasan a ser aliadas (ver hamelin_flute_controller.gd).
var has_hamelin_flute: bool = false
var is_invisible: bool = false
var cloak_controller: Node = null
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_dir: float = 1.0
var _air_dash_used: bool = false
## Llama del jetpack (la apagan los estados al aterrizar); el resto del fuego vive en `_jetpack_fx`.
var jetpack_particles: CPUParticles2D = null
var _jetpack_fx: Node2D = null
var dash_trail: CPUParticles2D = null

## Tres posturas con tres alturas de disparo claras (pivote del arma, px sobre los pies):
##   de pie            64 px de alto, el arma a la altura del hombro (la de la escena, -54)
##   agachado          rodilla en tierra (tecla abajo mantenida): 40 px, el arma a la altura del pecho
##   cuerpo a tierra   doble toque de abajo o la acción `prone`: 18 px, el arma pegada al piso
## Los tiros enemigos apuntan al centro del cuerpo en la postura actual (get_body_center): cambiar de postura
## esquiva los que ya vienen en vuelo. Siempre disponible (sin ítem).
const STAND_HEIGHT: float = 64.0
const CROUCH_HEIGHT: float = 40.0
const PRONE_HEIGHT: float = 18.0
const CROUCH_PIVOT_Y: float = -35.0
const PRONE_PIVOT_Y: float = -10.0
## Cuerpo a tierra el arma va adelante de la cabeza (px hacia donde mira).
const PRONE_PIVOT_X: float = 32.0
## Cuerpo a tierra se puede apuntar poco hacia arriba o abajo (rad desde la horizontal).
const PRONE_AIM_LIMIT: float = 0.38
const CROUCH_SPEED_MULT: float = 0.5
const PRONE_SPEED_MULT: float = 0.3
## Ancho de la hurtbox acostado (el cuerpo queda horizontal).
const PRONE_HURT_WIDTH: float = 66.0
## Ventana del doble toque de abajo para tirarse cuerpo a tierra (s).
const PRONE_DOUBLE_TAP: float = 0.28
## Velocidad vertical ascendente (px/s) por debajo de la cual, agachado en el suelo, se descarta (retroceso de armas).
const CROUCH_HOP_CANCEL: float = -150.0
enum Stance { STAND, CROUCH, PRONE }
var stance: int = Stance.STAND
## Agachado (rodilla en tierra). Cuerpo a tierra es `is_prone`; las dos son excluyentes.
var is_crouching: bool = false
var is_prone: bool = false
var _stand_pivot_y: float = -54.0
var _stand_radius: float = 18.0
var _stand_hurt_width: float = 36.0
var _hurtbox_shape: RectangleShape2D = null
var _hurtbox_shape_node: CollisionShape2D = null
var _down_tap_t: float = 99.0
## Cuadro físico en el que el salto se usó para levantarse (no salta en ese mismo cuadro).
var _jump_eaten_frame: int = -1

var hurt_cooldown: float = 0.0
var _unstuck_cooldown: float = 0.0
## Empujón al tocar a un enemigo: el jugador pierde el control horizontal unos instantes (ver is_knocked_back).
const CONTACT_KNOCK_SPEED: float = 260.0
const CONTACT_KNOCK_UP: float = -120.0
const CONTACT_KNOCK_TIME: float = 0.18
## Escudo de madera en la mano secundaria: multiplica el daño que entra (0.75 = 25 % menos).
const SHIELD_BLOCK_MULT: float = 0.75
var _knock_time_left: float = 0.0
## Sin empujones: ni el retroceso de las propias armas ni el de los golpes recibidos (Sala de Estrés en modo inmortal).
var knockback_immune: bool = false
var _hit_flash_tween: Tween = null
var phase_timer: float = 0.0


## Al perder el foco de la ventana se sueltan las acciones de movimiento: una tecla cuyo "soltar" se pierde
## dejaba al personaje deslizando solo hacia un costado.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		for action_name: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
			Input.action_release(action_name)


func _ready() -> void:
	# Asegurar configuración simultánea de Teclado y Gamepad en el InputMap
	InputSetup.setup_inputs()
	
	# Asegurar que existan datos de movimiento por defecto si no se asignaron en el Inspector
	if movement_data == null:
		movement_data = PlayerMovementData.new()
	
	if hurtbox != null:
		if not hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
			hurtbox.body_entered.connect(_on_hurtbox_body_entered)
		if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	if health_component != null and stats_manager != null:
		health_component.max_health = stats_manager.get_max_health()
		health_component.current_health = stats_manager.current_health
		if not stats_manager.health_changed.is_connected(_on_stats_health_changed):
			stats_manager.health_changed.connect(_on_stats_health_changed)

	if stats_manager != null:
		if not stats_manager.stats_recalculated.is_connected(_sync_armor_to_health_component):
			stats_manager.stats_recalculated.connect(_sync_armor_to_health_component)
		if not stats_manager.level_gained.is_connected(_on_level_gained):
			stats_manager.level_gained.connect(_on_level_gained)
		_sync_armor_to_health_component()

	_setup_crouch()
	_setup_jetpack_particles()
	_setup_dash_trail()

	consumable_manager = ConsumableManagerScript.new()
	consumable_manager.name = "ConsumableManager"
	add_child(consumable_manager)

	var frostmourne_summoner: Node = FrostmourneSummonerScript.new()
	frostmourne_summoner.name = "FrostmourneSummoner"
	add_child(frostmourne_summoner)

	var ally_dismisser: Node = AllyDismisserScript.new()
	ally_dismisser.name = "AllyDismisser"
	add_child(ally_dismisser)

	var low_health: Node = LowHealthFeedbackScript.new()
	low_health.name = "LowHealthFeedback"
	add_child(low_health)

	var mirror_reflector: Node = MirrorReflectorScript.new()
	mirror_reflector.name = "MirrorReflector"
	add_child(mirror_reflector)

	var eye_laser: Node = EyeLaserScript.new()
	eye_laser.name = "EyeLaser"
	add_child(eye_laser)

	cloak_controller = CloakControllerScript.new()
	cloak_controller.name = "CloakController"
	add_child(cloak_controller)

	var hamelin_flute: Node = HamelinFluteScript.new()
	hamelin_flute.name = "HamelinFluteController"
	add_child(hamelin_flute)

	# Escudo de energía: hoy el jugador no tiene escudo, así que no se ve hasta que tenga
	var energy_shield: Node2D = EnergyShieldScript.new()
	energy_shield.name = "EnergyShield"
	add_child(energy_shield)
	energy_shield.setup(health_component, Vector2(0, -32), Vector2(28, 40))

	reset_jumps()


func _setup_jetpack_particles() -> void:
	z_index = PLAYER_Z
	_jetpack_fx = JetpackFxScript.new() as Node2D
	_jetpack_fx.name = "JetpackFX"
	add_child(_jetpack_fx)
	jetpack_particles = _jetpack_fx.get("flame") as CPUParticles2D
	_mount_jetpack_fx.call_deferred()


## Cuelga el fuego de la boca de la mochila del esqueleto (se inclina y gira con él). Sin esqueleto queda en el jugador.
func _mount_jetpack_fx() -> void:
	var rig: Node = get_node_or_null("Visuals/CharacterRig")
	var mount: Node2D = rig.call("jet_mount") as Node2D if rig != null and rig.has_method("jet_mount") else null
	if mount != null and _jetpack_fx.get_parent() != mount:
		_jetpack_fx.reparent(mount, false)
		_jetpack_fx.position = Vector2.ZERO
	elif mount == null:
		_jetpack_fx.position = Vector2(-5, -24)


## Estela del dash: partículas que quedan fijas en el mundo (local_coords = false) en el camino recorrido.
func _setup_dash_trail() -> void:
	dash_trail = CPUParticles2D.new()
	dash_trail.name = "DashTrail"
	dash_trail.emitting = false
	dash_trail.local_coords = false
	dash_trail.amount = 70
	dash_trail.lifetime = 0.4
	dash_trail.direction = Vector2.LEFT
	dash_trail.spread = 6.0
	dash_trail.initial_velocity_min = 10.0
	dash_trail.initial_velocity_max = 30.0
	dash_trail.gravity = Vector2.ZERO
	dash_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dash_trail.emission_rect_extents = Vector2(4, STAND_HEIGHT * 0.5)
	dash_trail.scale_amount_min = 3.0
	dash_trail.scale_amount_max = 6.0
	dash_trail.z_index = -1
	dash_trail.z_as_relative = true

	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))       # Núcleo blanco
	grad.add_point(0.4, Color(0.5, 0.95, 1.0, 0.9))    # Cian brillante
	grad.set_color(1, Color(0.4, 0.9, 1.0, 0.0))       # Se disipa
	dash_trail.color_ramp = grad

	dash_trail.position = Vector2(0, -STAND_HEIGHT * 0.5)
	add_child(dash_trail)


## Duplica las formas de colisión para que agacharse no modifique el recurso compartido de la escena.
func _setup_crouch() -> void:
	if weapon_pivot != null:
		_stand_pivot_y = weapon_pivot.position.y
	if collision_shape != null and collision_shape.shape is CapsuleShape2D:
		collision_shape.shape = collision_shape.shape.duplicate()
		_stand_radius = (collision_shape.shape as CapsuleShape2D).radius
	if hurtbox != null:
		_hurtbox_shape_node = hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if _hurtbox_shape_node != null and _hurtbox_shape_node.shape is RectangleShape2D:
			_hurtbox_shape = (_hurtbox_shape_node.shape as RectangleShape2D).duplicate() as RectangleShape2D
			_hurtbox_shape_node.shape = _hurtbox_shape
			_stand_hurt_width = _hurtbox_shape.size.x


## Posturas: mantener abajo agacha (rodilla en tierra) y al soltar se levanta; doble toque de abajo (o `prone`)
## tira cuerpo a tierra, que se mantiene sin apretar nada. Arriba, salto o `prone` de nuevo levantan.
## Solo en el suelo, y solo se sube de postura si hay lugar encima.
func _update_crouch() -> void:
	_down_tap_t += get_physics_process_delta_time()
	# El retroceso del arma empuja hacia arriba si se apunta hacia abajo: agachado en el suelo no despega
	if stance != Stance.STAND and is_on_floor() and velocity.y < 0.0 and velocity.y > CROUCH_HOP_CANCEL:
		velocity.y = 0.0
	# Se mantiene agachado un instante (coyote) tras perder el suelo, para no "ponerse de pie" con un rebote
	var grounded: bool = is_on_floor() or (stance != Stance.STAND and coyote_timer > 0.0 and velocity.y > CROUCH_HOP_CANCEL)
	var can_lower: bool = grounded and not has_magic_flight
	var down_held: bool = Input.is_action_pressed("move_down")
	var down_tap: bool = Input.is_action_just_pressed("move_down")
	var prone_key: bool = InputMap.has_action(&"prone") and Input.is_action_just_pressed(&"prone")
	var double_tap: bool = down_tap and _down_tap_t < PRONE_DOUBLE_TAP
	if down_tap:
		_down_tap_t = 0.0

	if stance == Stance.PRONE:
		var jump_tap: bool = Input.is_action_just_pressed("jump")
		var get_up: bool = prone_key or jump_tap or Input.is_action_just_pressed("move_up") or not can_lower
		if get_up:
			if jump_tap:
				_jump_eaten_frame = Engine.get_physics_frames()
			if down_held and can_lower and _fits_height(CROUCH_HEIGHT):
				_set_stance(Stance.CROUCH)
			elif _fits_height(STAND_HEIGHT):
				_set_stance(Stance.STAND)
			elif _fits_height(CROUCH_HEIGHT):
				_set_stance(Stance.CROUCH)
		return

	if can_lower and (prone_key or double_tap):
		_set_stance(Stance.PRONE)
		_down_tap_t = 99.0
		return
	if stance == Stance.CROUCH:
		if not (down_held and can_lower) and _fits_height(STAND_HEIGHT):
			_set_stance(Stance.STAND)
	elif down_held and can_lower:
		_set_stance(Stance.CROUCH)


## true si la cápsula de pie (ancho completo) entra con esa altura donde está el jugador, sin chocar con nada.
func _fits_height(height: float) -> bool:
	if stance == Stance.STAND:
		return true
	var shape: CapsuleShape2D = CapsuleShape2D.new()
	shape.radius = _stand_radius
	shape.height = maxf(height, _stand_radius * 2.0)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + Vector2(0.0, -shape.height * 0.5 - 1.0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## true si hay lugar para volver a la altura de pie sin chocar con el techo.
func _has_headroom() -> bool:
	return _fits_height(STAND_HEIGHT)


## Agacharse / levantarse (lo usa respawn).
func _set_crouching(value: bool) -> void:
	_set_stance(Stance.CROUCH if value else Stance.STAND)


func _set_stance(value: int) -> void:
	stance = value
	is_crouching = value == Stance.CROUCH
	is_prone = value == Stance.PRONE
	var height: float = STAND_HEIGHT
	var pivot_y: float = _stand_pivot_y
	match value:
		Stance.CROUCH:
			height = CROUCH_HEIGHT
			pivot_y = CROUCH_PIVOT_Y
		Stance.PRONE:
			height = PRONE_HEIGHT
			pivot_y = PRONE_PIVOT_Y
	var capsule: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
	if capsule != null:
		# Acostado la cápsula se angosta para que los tiros pasen por encima
		capsule.radius = minf(_stand_radius, height * 0.5)
		capsule.height = height
	collision_shape.position.y = -height * 0.5
	if _hurtbox_shape != null:
		_hurtbox_shape.size = Vector2(PRONE_HURT_WIDTH if is_prone else _stand_hurt_width, height)
		_hurtbox_shape_node.position.y = -height * 0.5
	if weapon_pivot != null:
		weapon_pivot.position = Vector2(PRONE_PIVOT_X * float(facing_direction) if is_prone else 0.0, pivot_y)


## Centro del cuerpo en la postura actual: ahí apuntan los enemigos.
func get_body_center() -> Vector2:
	var height: float = STAND_HEIGHT
	if is_crouching:
		height = CROUCH_HEIGHT
	elif is_prone:
		height = PRONE_HEIGHT
	return global_position + Vector2(0.0, -height * 0.5)


func _physics_process(delta: float) -> void:
	_unstuck_cooldown = maxf(0.0, _unstuck_cooldown - delta)
	if Input.is_action_just_pressed("unstuck"):
		try_unstuck()
	_update_crouch()
	_update_dash(delta)
	if hurt_cooldown > 0.0:
		hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	if _knock_time_left > 0.0:
		_knock_time_left = maxf(0.0, _knock_time_left - delta)
	if phase_timer > 0.0:
		phase_timer = maxf(0.0, phase_timer - delta)
	
	if is_on_floor():
		jetpack_fuel = max_jetpack_fuel
		current_flaps = max_flaps
		is_using_jetpack = false
	
	if _jetpack_fx != null:
		_jetpack_fx.call("set_active", is_using_jetpack)
	
	# Verificación continua de daño por contacto con enemigos superpuestos en la hurtbox
	if hurtbox != null and hurt_cooldown <= 0.0 and phase_timer <= 0.0:
		for body in hurtbox.get_overlapping_bodies():
			if body == self:
				continue
			if body.get("no_touch_damage") == true:
				continue
			if body.is_in_group(&"enemies") or body is BasicRunner:
				var dmg: float = 12.0
				if "contact_damage" in body:
					dmg = float(body.contact_damage)
				take_contact_damage(dmg, body)
				break
	
	if is_on_floor():
		jetpack_fuel = max_jetpack_fuel
		current_flaps = max_flaps
	
	_update_animation()
	_update_precision_timers(delta)


## Dash: arranca con la acción "dash" si el ítem está equipado. Los estados leen `is_dashing()`.
func _update_dash(delta: float) -> void:
	if _dash_time_left > 0.0:
		_dash_time_left = maxf(0.0, _dash_time_left - delta)
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	if dash_trail != null:
		dash_trail.emitting = is_dashing()
	if is_on_floor():
		_air_dash_used = false
	if not can_dash or _dash_cooldown_left > 0.0 or stance != Stance.STAND or has_magic_flight:
		return
	if not InputMap.has_action(&"dash") or not Input.is_action_just_pressed(&"dash"):
		return
	if not is_on_floor():
		if _air_dash_used:
			return
		_air_dash_used = true
	var input_dir: float = get_horizontal_input()
	_dash_dir = signf(input_dir) if absf(input_dir) > 0.05 else float(facing_direction)
	if dash_trail != null:
		dash_trail.direction = Vector2(-_dash_dir, 0.0)
	_dash_time_left = DASH_TIME
	_dash_cooldown_left = DASH_COOLDOWN
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	GameFeel.sfx(self, &"throw", Vector2.INF, -4.0)


func is_dashing() -> bool:
	return _dash_time_left > 0.0


func get_dash_velocity() -> float:
	return _dash_dir * DASH_SPEED


## Actualiza de forma continua los temporizadores de Coyote Time y Jump Buffer en cada tick.
func _update_precision_timers(delta: float) -> void:
	# 1. Jump Buffer: registrar y decrementar intención de salto
	if is_jump_just_pressed():
		jump_buffer_timer = movement_data.jump_buffer_time
	elif jump_buffer_timer > 0.0:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	
	# 2. Coyote Time y reset de saltos en el suelo
	if is_on_floor():
		coyote_timer = movement_data.coyote_time
		reset_jumps()
	else:
		if coyote_timer > 0.0:
			coyote_timer = maxf(0.0, coyote_timer - delta)
			if coyote_timer == 0.0:
				var max_j: int = stats_manager.get_max_jumps() if stats_manager != null else 1
				if jumps_left == max_j:
					consume_air_jump()



# ==============================================================================
# Helpers de Mecánicas de Salto y Movimiento
# ==============================================================================

## Obtiene la velocidad horizontal efectiva leyendo dinámicamente el StatsManager.
func get_current_move_speed() -> float:
	var speed: float = movement_data.move_speed if movement_data != null else 240.0
	if stats_manager != null:
		speed = stats_manager.get_move_speed()
	if is_prone:
		return speed * PRONE_SPEED_MULT
	return speed * (CROUCH_SPEED_MULT if is_crouching else 1.0)


## Retorna la gravedad efectiva teniendo en cuenta modificadores de contratos activos.
func get_effective_gravity(is_falling: bool = false) -> float:
	if movement_data == null:
		return 980.0
	var grav: float = movement_data.gravity
	if is_falling:
		grav *= movement_data.fall_gravity_multiplier
	
	var mod_mgr: ZoneModifierManager = ZoneModifierManager.get_instance()
	if mod_mgr != null and mod_mgr.active_contract != null:
		var mult: float = float(mod_mgr.active_contract.player_modifiers.get("gravity_mult", 1.0))
		grav *= mult
	
	return grav


## Ejecuta el salto aplicando impulso vertical ascendente, resetea buffers y consume un salto.
func execute_jump() -> void:
	velocity.y = -movement_data.jump_force
	GameFeel.sfx(self, &"jump", Vector2.INF, -6.0)
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	consume_air_jump()


## Mecánica de 'Altura de salto variable':
## Corta la velocidad vertical a la mitad si el jugador suelta el botón mientras asciende.
func cut_jump() -> void:
	if velocity.y < 0.0:
		velocity.y *= movement_data.jump_cut_multiplier


## Consulta si el jugador está dentro de la ventana activa de Coyote Time.
func can_coyote_jump() -> bool:
	return coyote_timer > 0.0


## Consulta si el jugador aún tiene saltos restantes disponibles en el aire.
func can_air_jump() -> bool:
	return jumps_left > 0


## Consume un salto disponible.
func consume_air_jump() -> void:
	jumps_left = maxi(0, jumps_left - 1)


## Restablece los saltos disponibles al valor máximo otorgado por el StatsManager.
func reset_jumps() -> void:
	jumps_left = stats_manager.get_max_jumps() if stats_manager != null else 1


## Consulta si existe un salto en cola almacenado en el Jump Buffer.
func has_buffered_jump() -> bool:
	return jump_buffer_timer > 0.0


## Consume y limpia el Jump Buffer activo.
func consume_jump_buffer() -> void:
	jump_buffer_timer = 0.0


# ==============================================================================
# Recepción de Daño e Impactos
# ==============================================================================

## Aplica daño directo sobre el jugador delegándolo en StatsManager y HealthComponent.
func take_damage(amount: float) -> void:
	if invulnerable:
		return
	if hurt_cooldown > 0.0:
		return
	hurt_cooldown = 0.6
	GameFeel.sfx(self, &"hurt")
	# Invisible: quien lo toca o le pega le roba la capa
	if is_invisible and cloak_controller != null:
		cloak_controller.on_player_hit()
	# Dificultad elegida en Opciones (Recluta 0.6x ... Pesadilla 1.75x)
	amount *= float((load("res://core/settings.gd") as GDScript).call("enemy_damage_mult"))
	if _is_shield_blocking():
		amount *= SHIELD_BLOCK_MULT
	# Armadura: cada punto resta 1 de daño por golpe (con piso; ver StatsManager.reduce_damage_by_armor).
	var final_amount: float = amount
	if stats_manager != null:
		final_amount = stats_manager.reduce_damage_by_armor(amount)
		stats_manager.take_damage(final_amount)
	if health_component != null:
		health_component.current_health = stats_manager.current_health if stats_manager != null else maxf(0.0, health_component.current_health - final_amount)
		health_component.damage_taken.emit(final_amount, false, "PHYSICAL")
		health_component.health_changed.emit(health_component.current_health, health_component.max_health)
	_play_hit_flash()
	_spawn_taken_damage_number(final_amount)

	var is_dead: bool = false
	if stats_manager != null and stats_manager.current_health <= 0.0:
		is_dead = true
	elif health_component != null and health_component.current_health <= 0.0:
		is_dead = true

	if is_dead:
		_handle_player_death()


## true si el escudo de la mano secundaria está levantado (clic derecho mantenido). Ver SHIELD_BLOCK_MULT.
func _is_shield_blocking() -> bool:
	return weapon_manager != null and weapon_manager.offhand != null and weapon_manager.offhand.is_shield_raised()


## Daño recibido como texto rojo grande y tembloroso sobre el jugador (ver DamageNumber, tipo "PLAYER_HIT").
func _spawn_taken_damage_number(amount: float) -> void:
	if roundi(amount) <= 0 or not is_inside_tree():
		return
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	var number: DamageNumber = DamageNumberScene.instantiate() as DamageNumber
	number.global_position = global_position + Vector2(randf_range(-10.0, 10.0), -78.0)
	host.add_child(number)
	number.setup(amount, false, "PLAYER_HIT")


func _handle_player_death() -> void:
	GameFeel.sfx(self, &"player_death")
	var metrics_mgr: MetricsManager = MetricsManager.get_instance()
	if metrics_mgr != null:
		metrics_mgr.record_player_death()
	died.emit()
	if health_component != null:
		health_component.die()
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("on_player_died"):
		gm.call("on_player_died", self)


const UNSTUCK_STEP: float = 6.0
const UNSTUCK_MAX_RISE: float = 720.0
const UNSTUCK_COOLDOWN: float = 1.0
const UNSTUCK_POP_SPEED: float = 520.0


## Destrabar (Ctrl+U): si el personaje quedó metido en geometría o un prop mal ubicado, lo escupe hacia arriba hasta el
## primer hueco libre; si ya está en espacio libre pero atascado, le da un impulso hacia arriba. Si no hay hueco
## arriba, lo devuelve al punto de inicio del sector.
func try_unstuck() -> void:
	if _unstuck_cooldown > 0.0 or (health_component != null and health_component.is_dead):
		return
	_unstuck_cooldown = UNSTUCK_COOLDOWN
	var base: Transform2D = global_transform
	if not test_move(base, Vector2.ZERO, null, 0.08, true):
		global_position.y -= 4.0
	else:
		var found: bool = false
		var steps: int = int(UNSTUCK_MAX_RISE / UNSTUCK_STEP)
		for i in range(1, steps + 1):
			var candidate: Transform2D = base.translated(Vector2(0.0, -UNSTUCK_STEP * i))
			if not test_move(candidate, Vector2.ZERO, null, 0.08, true):
				global_position = candidate.origin + Vector2(0.0, -UNSTUCK_STEP)
				found = true
				break
		if not found:
			var level: Node = get_tree().current_scene
			var spawn: Variant = level.get("initial_spawn_position") if level != null else null
			if spawn is Vector2:
				global_position = spawn
	velocity = Vector2(0.0, -UNSTUCK_POP_SPEED)
	reset_jumps()
	GameFeel.sfx(self, &"jump", Vector2.INF, -3.0)



## Restaura la vitalidad y reubica al jugador en la posición de reaparición indicada.
func respawn(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	velocity = Vector2.ZERO
	hurt_cooldown = 0.0
	if stance != Stance.STAND:
		_set_stance(Stance.STAND)
	if stats_manager != null:
		stats_manager.current_health = stats_manager.get_max_health()
		stats_manager.health_changed.emit(stats_manager.current_health, stats_manager.get_max_health())
	if health_component != null:
		health_component.is_dead = false
		health_component.current_health = health_component.max_health
		health_component.health_changed.emit(health_component.current_health, health_component.max_health)
	reset_jumps()


## Mantiene `health_component.armor` alineado con la armadura de los ítems equipados (la lee la ficha de personaje).
func _sync_armor_to_health_component() -> void:
	if health_component != null and stats_manager != null:
		health_component.armor = stats_manager.get_armor()


func _on_stats_health_changed(cur: float, max_hp: float) -> void:
	if health_component != null:
		health_component.max_health = max_hp
		health_component.current_health = cur


func _on_level_gained(_new_level: int) -> void:
	play_level_up_aura()
	# Subir de nivel recarga todas las armas (la vida ya la restaura StatsManager)
	if weapon_manager != null:
		weapon_manager.refill_all_ammo()


## Brillo extra del personaje al juntar experiencia (sobre `CharacterRig`, aparte del rojo de daño de Visuals).
## Cada orbe suma menos cuanto más brilla ya y el brillo se apaga solo: con una lluvia de orbes queda un
## resplandor parejo y suave en vez de un parpadeo constante.
const XP_GLOW_CAP: float = 0.32
const XP_GLOW_STEP: float = 0.16
const XP_GLOW_FADE: float = 0.35
const XP_GLOW_TINT: Color = Color(0.9, 0.85, 0.5, 0.0)


func flash_exp_pickup() -> void:
	var rig: CanvasItem = get_node_or_null("Visuals/CharacterRig") as CanvasItem
	if rig == null:
		rig = visuals
	if rig == null:
		return
	var now: int = Time.get_ticks_msec()
	var elapsed: float = float(now - _xp_glow_msec) / 1000.0
	var current: float = _xp_glow * clampf(1.0 - elapsed / XP_GLOW_FADE, 0.0, 1.0)
	_xp_glow = minf(XP_GLOW_CAP, current + XP_GLOW_STEP * (1.0 - current / XP_GLOW_CAP))
	_xp_glow_msec = now
	if _xp_glow_tween != null and _xp_glow_tween.is_valid():
		_xp_glow_tween.kill()
	rig.modulate = Color.WHITE + XP_GLOW_TINT * _xp_glow
	_xp_glow_tween = create_tween()
	_xp_glow_tween.tween_property(rig, "modulate", Color.WHITE, XP_GLOW_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Halo dorado aditivo: el tinte solo apenas se nota
	if _xp_halo == null or not is_instance_valid(_xp_halo):
		_xp_halo = (load("res://entities/player/xp_halo.gd") as GDScript).new() as Node2D
		_xp_halo.name = "XpHalo"
		add_child(_xp_halo)
	_xp_halo.call("pulse")


## Muestra un aura radiante alrededor del personaje (estilo MU Online / WoW) al subir de nivel.
## Si ya hay un aura activa (subidas seguidas de nivel), la reinicia sin dejar nodos colgados.
func play_level_up_aura() -> void:
	if _level_up_aura != null and is_instance_valid(_level_up_aura) and not _level_up_aura.is_queued_for_deletion():
		if _level_up_aura.has_method("restart"):
			_level_up_aura.restart()
			return
		_level_up_aura.queue_free()

	var aura: Node2D = LevelUpAuraScript.new() as Node2D
	aura.name = "LevelUpAura"
	_level_up_aura = aura
	add_child(aura)
	aura.tree_exited.connect(func() -> void:
		if _level_up_aura == aura:
			_level_up_aura = null
	)


## Recibe un impacto transportado por un HitPayload.
func take_hit(payload: HitPayload) -> void:
	if payload == null:
		return
	# Chaleco antibalas: reduce el daño de los proyectiles entrantes (el contacto no pasa por acá)
	take_damage(payload.base_damage * (1.0 - clampf(vest_projectile_reduction, 0.0, 0.9)))
	if payload.knockback_force > 0.0 and not knockback_immune:
		velocity += payload.get_knockback_velocity() * 0.6


## Activa una ventana de fase temporal para atravesar enemigos ligeros sin recibir daño por contacto.
func activate_melee_phase(duration: float = 0.15) -> void:
	phase_timer = maxf(phase_timer, duration)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if phase_timer > 0.0:
		return
	if body.get("no_touch_damage") == true:
		return
	if body.is_in_group(&"enemies") or body is BasicRunner:
		var dmg: float = 12.0
		if "contact_damage" in body:
			dmg = float(body.contact_damage)
		take_contact_damage(dmg, body)


## Daño por contacto con un enemigo: además del daño, empuja al jugador en sentido contrario al enemigo.
## Si el golpe no cuenta (cooldown de invulnerabilidad), no hay empujón ni sonido.
func take_contact_damage(amount: float, source: Node2D) -> void:
	if hurt_cooldown > 0.0:
		return
	take_damage(amount)
	if knockback_immune or source == null or not is_inside_tree():
		return
	var dir: float = signf(global_position.x - source.global_position.x)
	if dir == 0.0:
		dir = -float(facing_direction)
	velocity.x = dir * CONTACT_KNOCK_SPEED
	velocity.y = minf(velocity.y, CONTACT_KNOCK_UP)
	_knock_time_left = CONTACT_KNOCK_TIME
	GameFeel.sfx(self, &"hurt_thud")


## Verdadero mientras dura el empujón: los estados de movimiento no pisan la velocidad horizontal.
func is_knocked_back() -> bool:
	return _knock_time_left > 0.0


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area == hurtbox:
		return
	if area.is_in_group(&"enemy_hitbox"):
		take_damage(15.0)



## Parpadeo blanco / rojo provisional de impacto en el jugador.
func _play_hit_flash() -> void:
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	
	if anim_sprite != null:
		anim_sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
		_hit_flash_tween = create_tween()
		_hit_flash_tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.12)
		return
	# Esqueleto modular (CharacterRig): se tiñe todo el nodo Visuals
	if visuals != null and visuals.get_node_or_null("CharacterRig") != null:
		visuals.modulate = Color(1.0, 0.3, 0.3, 1.0)
		_hit_flash_tween = create_tween()
		_hit_flash_tween.tween_property(visuals, "modulate", Color.WHITE, 0.12)
		return

	var body_rect: ColorRect = get_node_or_null("Visuals/Body") as ColorRect
	if body_rect == null:
		return
	var default_color: Color = Color(0.18, 0.55, 0.95, 1.0)
	body_rect.color = Color(1.0, 0.3, 0.3, 1.0) # Rojo de daño
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(body_rect, "color", default_color, 0.12)


## Consume y limpia la ventana de Coyote Time.
func consume_coyote_time() -> void:
	coyote_timer = 0.0


## Actualiza la orientación del sprite y dirección de apuntado.
func update_facing_direction(direction_sign: float) -> void:
	# Cuerpo a tierra el pivote del arma va adelante de la cabeza, del lado al que mira
	if is_prone and weapon_pivot != null and direction_sign != 0.0:
		weapon_pivot.position.x = PRONE_PIVOT_X * signf(direction_sign)
	if direction_sign > 0.0:
		facing_direction = 1
		if anim_sprite != null:
			anim_sprite.flip_h = false
		elif visuals != null:
			visuals.scale.x = 1.0
		elif sprite != null and "flip_h" in sprite:
			sprite.flip_h = false
	elif direction_sign < 0.0:
		facing_direction = -1
		if anim_sprite != null:
			anim_sprite.flip_h = true
		elif visuals != null:
			visuals.scale.x = -1.0
		elif sprite != null and "flip_h" in sprite:
			sprite.flip_h = true


## Cicla las animaciones del AnimatedSprite2D según el movimiento horizontal y estado
func _update_animation() -> void:
	if anim_sprite == null:
		return
	
	if is_on_floor():
		if not anim_sprite.is_playing():
			anim_sprite.play()
		if absf(velocity.x) > 10.0:
			if anim_sprite.animation != &"run":
				anim_sprite.play(&"run")
		else:
			if anim_sprite.animation != &"idle":
				anim_sprite.play(&"idle")
	else:
		# En el aire (saltando, cayendo o con jetpack):
		# Jamás reproducir "run" (evita correr en el aire).
		if is_using_jetpack:
			# Postura fija y estable de vuelo con jetpack
			if anim_sprite.animation != &"idle":
				anim_sprite.play(&"idle")
			anim_sprite.frame = 1
			anim_sprite.pause()
		else:
			if anim_sprite.animation != &"idle":
				anim_sprite.play(&"idle")
			if not anim_sprite.is_playing():
				anim_sprite.play()


# ==============================================================================
# Abstracción de Input (Compatible con InputMap personalizado y fallbacks por defecto)
# ==============================================================================

## Obtiene el valor del eje horizontal (-1.0 a 1.0) utilizando Input.get_axis para
## aprovechar la sensibilidad analógica progresiva del stick del Gamepad o pulsaciones del teclado.
func get_horizontal_input() -> float:
	return Input.get_axis("move_left", "move_right")


## Obtiene el valor del eje vertical (-1.0 a 1.0) utilizando Input.get_axis para
## soportar vuelo omnidireccional y navegación 8 direcciones.
func get_vertical_input() -> float:
	return Input.get_axis("move_up", "move_down")


## Detecta si se acaba de presionar el botón de salto (estrictamente acción 'jump': Espacio / Botón A).
## Cuerpo a tierra el salto solo levanta (no salta en el mismo cuadro).
func is_jump_just_pressed() -> bool:
	if is_prone or _jump_eaten_frame == Engine.get_physics_frames():
		return false
	return Input.is_action_just_pressed("jump")


## Detecta si el botón de salto se mantiene presionado actualmente.
func is_jump_pressed() -> bool:
	return Input.is_action_pressed("jump")


## Detecta si se acaba de soltar el botón de salto (para corte de salto variable).
func is_jump_just_released() -> bool:
	return Input.is_action_just_released("jump")
