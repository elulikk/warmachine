class_name AllyBase
extends CharacterBody2D
## Clase base para entidades aliadas en WARMACHINE.
## Gestiona la integración con grupos de aliados, vitalidad (HealthComponent 250 HP),
## receptor de estados alterados, escáner de blancos hostiles, expresiones de voz,
## y el sistema de rescate por Leash (distancia excesiva respecto al jugador).

signal health_changed(current: float, max: float)
signal hit_received(payload: HitPayload)
signal died
signal hired

@export_group("Configuración Aliado")
@export var is_hired: bool = false
@export var hire_cost: int = 15
@export var leash_distance: float = 650.0

@export_group("Movimiento y Físicas")
@export var move_speed: float = 160.0
@export var gravity: float = 980.0

@export_group("Invocación (zona de descanso)")
## Las invocaciones se reparten alrededor del jugador, se separan entre sí y vagabundean (Fase J).
## Una invocación nueva solo tiene que activar esto y usar rest_goal_x() / apply_separation().
@export var is_summon: bool = false

## Separación entre invocaciones: radio de empuje y aceleración (px/s²).
const SEPARATION_RADIUS: float = 56.0
const SEPARATION_ACCEL: float = 1400.0
## Zona de descanso: primer casillero, distancia entre casilleros y vagabundeo alrededor del casillero.
const SLOT_FIRST: float = 70.0
const SLOT_SPACING: float = 48.0
const WANDER_RANGE: float = 26.0
const WANDER_PAUSE_MIN: float = 1.2
const WANDER_PAUSE_MAX: float = 3.5
const SLOT_REFRESH: float = 0.25

@export_group("Efectos y Escenas")
@export var damage_number_scene: PackedScene = preload("res://combat/damage_number.tscn")

@onready var health_component: HealthComponent = get_node_or_null("HealthComponent")
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox")
@onready var voice_component: VoiceComponent = get_node_or_null("VoiceComponent")
@onready var status_receiver: StatusReceiverComponent = get_node_or_null("StatusReceiverComponent")
@onready var target_scanner: TargetScannerComponent = get_node_or_null("TargetScannerComponent")
@onready var visuals: Node2D = get_node_or_null("Visuals")
@onready var visual_rect: ColorRect = get_node_or_null("Visuals/ColorRect")

var target_player: Player = null
var is_dead: bool = false
var leash_timer: float = 0.0
var original_visual_color: Color = Color.WHITE
var _flash_tween: Tween = null
var _slot_offset: float = 0.0
var _slot_timer: float = 0.0
var _wander_offset: float = 0.0
var _wander_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"allies")
	if is_summon:
		add_to_group(&"summons")
		_wander_timer = randf_range(0.0, WANDER_PAUSE_MAX)
	_ensure_components()
	_configure_hurtbox()
	if visual_rect != null:
		original_visual_color = visual_rect.color


func _physics_process(delta: float) -> void:
	if is_hired:
		_process_leash_rescue(delta)


## Tiempo de vida de una invocación: lo dicta el ítem que la invoca. Al vencer, la invocación muere.
func set_lifetime(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	timer.timeout.connect(_on_lifetime_expired)
	add_child(timer)
	timer.start()


func _on_lifetime_expired() -> void:
	if not is_dead and is_inside_tree():
		_on_died()


func _ensure_components() -> void:
	# 1. HealthComponent (Vida alta por defecto: 250 HP)
	if health_component == null:
		health_component = get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		health_component.max_health = 250.0
		add_child(health_component)
	
	if not health_component.damage_taken.is_connected(_on_damage_taken):
		health_component.damage_taken.connect(_on_damage_taken)
	if not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)
	if not health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.connect(_on_health_changed)
	
	# 2. VoiceComponent
	if voice_component == null:
		voice_component = get_node_or_null("VoiceComponent") as VoiceComponent
	if voice_component == null:
		voice_component = VoiceComponent.new()
		voice_component.name = "VoiceComponent"
		add_child(voice_component)
	
	# 3. StatusReceiverComponent
	if status_receiver == null:
		status_receiver = get_node_or_null("StatusReceiverComponent") as StatusReceiverComponent
	if status_receiver == null:
		status_receiver = StatusReceiverComponent.new()
		status_receiver.name = "StatusReceiverComponent"
		add_child(status_receiver)
	
	# 4. TargetScannerComponent (configurado para "enemies")
	if target_scanner == null:
		target_scanner = get_node_or_null("TargetScannerComponent") as TargetScannerComponent
	if target_scanner == null:
		target_scanner = TargetScannerComponent.new()
		target_scanner.name = "TargetScannerComponent"
		target_scanner.target_groups = ["enemies"]
		target_scanner.detection_radius = 320.0
		target_scanner.scan_interval = 0.2
		add_child(target_scanner)


func _configure_hurtbox() -> void:
	if hurtbox == null:
		hurtbox = get_node_or_null("Hurtbox") as Area2D
	
	if hurtbox != null:
		# Hurtbox activa solo cuando el aliado ha sido contratado
		hurtbox.monitoring = is_hired
		hurtbox.monitorable = is_hired


## Empuje horizontal (-1 a 1) lejos de las demás invocaciones que están demasiado cerca.
func get_separation_push() -> float:
	var push: float = 0.0
	for other: Node in get_tree().get_nodes_in_group(&"summons"):
		if other == self or not other is Node2D:
			continue
		var offset: Vector2 = global_position - (other as Node2D).global_position
		if absf(offset.y) > 48.0 or absf(offset.x) >= SEPARATION_RADIUS:
			continue
		var side: float = signf(offset.x)
		if side == 0.0:
			# Mismo punto exacto: el de menor id va a la izquierda, el otro a la derecha (siempre opuestos).
			side = -1.0 if get_instance_id() < other.get_instance_id() else 1.0
		push += side * (1.0 - absf(offset.x) / SEPARATION_RADIUS)
	return clampf(push, -1.0, 1.0)


## Suma el empuje de separación a la velocidad horizontal; se llama después de decidir el movimiento.
func apply_separation(delta: float) -> void:
	if not is_summon:
		return
	var push: float = get_separation_push()
	if push != 0.0:
		var limit: float = move_speed * 1.5
		velocity.x = clampf(velocity.x + push * SEPARATION_ACCEL * delta, -limit, limit)


## Posición X a la que la invocación quiere estar cuando no hay enemigos: el casillero que le toca
## alrededor del jugador más un desvío que cambia cada tanto (se mueve y se detiene a ratos).
func rest_goal_x(delta: float) -> float:
	var player: Player = get_player()
	if player == null or not is_instance_valid(player):
		return global_position.x
	_slot_timer -= delta
	if _slot_timer <= 0.0:
		_slot_timer = SLOT_REFRESH
		_slot_offset = _compute_slot_offset()
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)
		_wander_offset = randf_range(-WANDER_RANGE, WANDER_RANGE)
	return player.global_position.x + _slot_offset + _wander_offset


## Casilleros alternados izquierda / derecha del jugador, cada vez más lejos. El orden sale del id de instancia.
func _compute_slot_offset() -> float:
	var rank: int = 0
	var mine: int = get_instance_id()
	for other: Node in get_tree().get_nodes_in_group(&"summons"):
		if other != self and other.get_instance_id() < mine:
			rank += 1
	var side: float = -1.0 if rank % 2 == 0 else 1.0
	return side * (SLOT_FIRST + floorf(rank / 2.0) * SLOT_SPACING)


## Rescate por Leash: si la distancia horizontal supera leash_distance por más de 1.5s,
## se reposiciona automáticamente cayendo junto al jugador.
func _process_leash_rescue(delta: float) -> void:
	var player: Player = get_player()
	if player == null or not is_instance_valid(player):
		leash_timer = 0.0
		return
	
	var horizontal_dist: float = absf(global_position.x - player.global_position.x)
	if horizontal_dist > leash_distance:
		leash_timer += delta
		if leash_timer >= 1.5:
			rescue_leash(player)
			leash_timer = 0.0
	else:
		leash_timer = 0.0


func rescue_leash(player: Player) -> void:
	var face_dir: float = float(player.facing_direction if "facing_direction" in player else 1)
	global_position = player.global_position + Vector2(-32.0 * face_dir, -40.0)
	velocity = Vector2.ZERO
	if voice_component != null:
		voice_component.speak("¡Reagrupándome con el líder!", 1.8, Color(0.4, 0.9, 1.0))
	print("[%s] Rescate por Leash activado: aliado reposicionado junto al Jugador." % name)


## Procesa un impacto entrante transportado por un HitPayload.
func take_hit(payload: HitPayload) -> void:
	if not is_hired or is_dead or payload == null:
		return
	
	# Evitar fuego amigo proveniente del jugador o de otros aliados
	if payload.source_node != null:
		if payload.source_node.is_in_group(&"player") or payload.source_node.is_in_group(&"allies"):
			return
	
	if status_receiver != null:
		status_receiver.apply_payload(payload)
	
	if health_component != null:
		health_component.take_hit(payload)
	
	if payload.knockback_force > 0.0:
		velocity.x = payload.knockback_direction.x * payload.knockback_force * 0.5
		velocity.y = -60.0
	
	hit_received.emit(payload)


func _on_damage_taken(amount: float, is_critical: bool, damage_type: String) -> void:
	_play_hit_flash()
	if damage_type != "FIRE_DOT":
		_spawn_damage_number(amount, is_critical, damage_type)


func _on_health_changed(current: float, max_h: float) -> void:
	health_changed.emit(current, max_h)


func _play_hit_flash() -> void:
	if visual_rect == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	
	visual_rect.color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual_rect, "color", original_visual_color, 0.08)


func _spawn_damage_number(amount: float, is_critical: bool, damage_type: String) -> void:
	if damage_number_scene == null or not is_inside_tree():
		return
	
	var dmg_instance: Node = damage_number_scene.instantiate()
	if dmg_instance is DamageNumber:
		var dmg_num: DamageNumber = dmg_instance as DamageNumber
		dmg_num.global_position = global_position + Vector2(0, -48.0)
		var container: Node = get_tree().current_scene
		if container == null:
			container = get_parent()
		if container != null:
			container.add_child(dmg_num)
			dmg_num.setup(amount, is_critical, damage_type)


## Muerte definitiva del aliado: emite died y libera el nodo de la escena.
func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	if voice_component != null:
		voice_component.speak("¡He caído en batalla...!", 1.5, Color(1.0, 0.3, 0.3))
	died.emit()
	print("[%s] Aliado caído en combate. Liberando nodo." % name)
	queue_free()


func get_player() -> Player:
	if target_player == null or not is_instance_valid(target_player):
		if is_inside_tree() and get_tree() != null:
			target_player = get_tree().get_first_node_in_group(&"player") as Player
	return target_player
