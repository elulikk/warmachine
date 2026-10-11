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


func _ready() -> void:
	add_to_group(&"allies")
	_ensure_components()
	_configure_hurtbox()
	if visual_rect != null:
		original_visual_color = visual_rect.color


func _physics_process(delta: float) -> void:
	if is_hired:
		_process_leash_rescue(delta)


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
