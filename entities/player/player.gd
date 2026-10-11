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
## Disposición de la barra de acceso rápido ({"w": índice en el arsenal} | {"c": consumable_id} | null por casillero).
## La mantiene ui/hotbar.gd y la guarda SaveManager.
var hotbar_layout: Array = []


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
var has_wings: bool = false
var max_flaps: int = 5
var current_flaps: int = 0
var has_magic_flight: bool = false
var jetpack_particles: CPUParticles2D = null

var hurt_cooldown: float = 0.0
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
		_sync_armor_to_health_component()

	_setup_jetpack_particles()

	consumable_manager = ConsumableManagerScript.new()
	consumable_manager.name = "ConsumableManager"
	add_child(consumable_manager)

	reset_jumps()


func _setup_jetpack_particles() -> void:
	jetpack_particles = CPUParticles2D.new()
	jetpack_particles.name = "JetpackParticles"
	jetpack_particles.emitting = false
	jetpack_particles.amount = 36
	jetpack_particles.lifetime = 0.35
	jetpack_particles.speed_scale = 1.2
	jetpack_particles.direction = Vector2(-0.15, 1.0).normalized()
	jetpack_particles.spread = 22.0
	jetpack_particles.gravity = Vector2(0, 160)
	jetpack_particles.initial_velocity_min = 100.0
	jetpack_particles.initial_velocity_max = 190.0
	jetpack_particles.scale_amount_min = 2.5
	jetpack_particles.scale_amount_max = 5.5
	jetpack_particles.z_index = 1
	jetpack_particles.z_as_relative = true
	
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.7, 1.0))       # Núcleo blanco-amarillo incandescente
	grad.add_point(0.25, Color(1.0, 0.55, 0.1, 0.95))   # Llamarada propulsora naranja
	grad.add_point(0.6, Color(0.85, 0.2, 0.05, 0.7))    # Rescoldo rojizo
	grad.add_point(0.85, Color(0.35, 0.35, 0.35, 0.4))  # Humo denso
	grad.set_color(1, Color(0.2, 0.2, 0.2, 0.0))       # Humo disipado
	jetpack_particles.color_ramp = grad
	
	jetpack_particles.position = Vector2(-5, -24)
	add_child(jetpack_particles)


func _physics_process(delta: float) -> void:
	if hurt_cooldown > 0.0:
		hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	if phase_timer > 0.0:
		phase_timer = maxf(0.0, phase_timer - delta)
	
	if is_on_floor():
		jetpack_fuel = max_jetpack_fuel
		current_flaps = max_flaps
		is_using_jetpack = false
	
	if jetpack_particles != null:
		jetpack_particles.emitting = is_using_jetpack
		if is_using_jetpack:
			var back_x: float = -5.0 if facing_direction > 0 else 5.0
			jetpack_particles.position = Vector2(back_x, -24)
	
	# Verificación continua de daño por contacto con enemigos superpuestos en la hurtbox
	if hurtbox != null and hurt_cooldown <= 0.0 and phase_timer <= 0.0:
		for body in hurtbox.get_overlapping_bodies():
			if body == self:
				continue
			if body.is_in_group(&"enemies") or body is BasicRunner:
				var dmg: float = 12.0
				if "contact_damage" in body:
					dmg = float(body.contact_damage)
				take_damage(dmg)
				break
	
	if is_on_floor():
		jetpack_fuel = max_jetpack_fuel
		current_flaps = max_flaps
	
	_update_animation()
	_update_precision_timers(delta)


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
	if stats_manager != null:
		return stats_manager.get_move_speed()
	return movement_data.move_speed if movement_data != null else 240.0


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
	if hurt_cooldown > 0.0:
		return
	hurt_cooldown = 0.6
	GameFeel.sfx(self, &"hurt")
	# Dificultad elegida en Opciones (Recluta 0.6x ... Pesadilla 1.75x)
	amount *= float((load("res://core/settings.gd") as GDScript).call("enemy_damage_mult"))
	# Mitigación por armadura: 100 / (100 + armadura), igual que HealthComponent.
	var final_amount: float = amount
	if stats_manager != null:
		final_amount = amount * 100.0 / (100.0 + stats_manager.get_armor())
		stats_manager.take_damage(final_amount)
	if health_component != null:
		health_component.current_health = stats_manager.current_health if stats_manager != null else maxf(0.0, health_component.current_health - final_amount)
		health_component.damage_taken.emit(final_amount, false, "PHYSICAL")
		health_component.health_changed.emit(health_component.current_health, health_component.max_health)
	_play_hit_flash()

	var is_dead: bool = false
	if stats_manager != null and stats_manager.current_health <= 0.0:
		is_dead = true
	elif health_component != null and health_component.current_health <= 0.0:
		is_dead = true

	if is_dead:
		_handle_player_death()


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


## Restaura la vitalidad y reubica al jugador en la posición de reaparición indicada.
func respawn(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	velocity = Vector2.ZERO
	hurt_cooldown = 0.0
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


## Recibe un impacto transportado por un HitPayload.
func take_hit(payload: HitPayload) -> void:
	if payload == null:
		return
	take_damage(payload.base_damage)
	if payload.knockback_force > 0.0:
		velocity += payload.get_knockback_velocity() * 0.6


## Activa una ventana de fase temporal para atravesar enemigos ligeros sin recibir daño por contacto.
func activate_melee_phase(duration: float = 0.15) -> void:
	phase_timer = maxf(phase_timer, duration)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if phase_timer > 0.0:
		return
	if body.is_in_group(&"enemies") or body is BasicRunner:
		var dmg: float = 12.0
		if "contact_damage" in body:
			dmg = float(body.contact_damage)
		take_damage(dmg)


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
	if direction_sign > 0.0:
		facing_direction = 1
		if anim_sprite != null:
			anim_sprite.flip_h = false
		elif visuals != null:
			visuals.scale.x = 1.0
		elif sprite != null and "flip_h" in sprite:
			sprite.flip_h = false
		if jetpack_particles != null:
			jetpack_particles.position = Vector2(-14, -20)
			jetpack_particles.direction = Vector2(-0.2, 1.0).normalized()
	elif direction_sign < 0.0:
		facing_direction = -1
		if anim_sprite != null:
			anim_sprite.flip_h = true
		elif visuals != null:
			visuals.scale.x = -1.0
		elif sprite != null and "flip_h" in sprite:
			sprite.flip_h = true
		if jetpack_particles != null:
			jetpack_particles.position = Vector2(14, -20)
			jetpack_particles.direction = Vector2(0.2, 1.0).normalized()


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
func is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed("jump")


## Detecta si el botón de salto se mantiene presionado actualmente.
func is_jump_pressed() -> bool:
	return Input.is_action_pressed("jump")


## Detecta si se acaba de soltar el botón de salto (para corte de salto variable).
func is_jump_just_released() -> bool:
	return Input.is_action_just_released("jump")
