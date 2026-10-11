class_name BasicRunner
extends CharacterBody2D
## Enemigo bípedo básico que persigue horizontalmente al jugador.
## Posee HealthComponent, Hurtbox, animación de parpadeo blanco (Hit Flash)
## y genera números de daño flotantes (DamageNumber) al recibir impactos.

const EnemyArtScript = preload("res://entities/enemies/enemy_art.gd")
signal died

const GearLootScript = preload("res://core/loot/gear_loot.gd")
const DeathFxQueueScript = preload("res://combat/death_fx_queue.gd")

## Aceleración hacia la velocidad de persecución (px/s²). Permite que el knockback se note antes de retomar la marcha.
const CHASE_ACCEL: float = 900.0

@export var entity_name: String = "Ladrón"
@export var move_speed: float = 65.0
@export var aggro_range: float = 280.0
@export var gravity: float = 980.0
@export var damage_number_scene: PackedScene = preload("res://combat/damage_number.tscn")
@export var exp_orb_scene: PackedScene = preload("res://entities/items/exp_orb.tscn")
@export var loot_table: LootTable
@export var loot_drop_scene: PackedScene = preload("res://entities/items/loot_drop.tscn")
@export var drop_rune_on_death: RuneData = null
## Tipo de arte de `EnemyArt` (ver enemy_art.gd): "runner", "zombie", "ghost", etc.
@export var art_kind: String = "runner"
## Daño por contacto con el jugador.
@export var contact_damage: float = 12.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var visual_rect: ColorRect = get_node_or_null("Visuals/ColorRect") as ColorRect
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("Visuals/AnimatedSprite2D") as AnimatedSprite2D
@onready var visuals: Node2D = $Visuals
@onready var hurtbox: Area2D = $Hurtbox
@onready var status_receiver: StatusReceiverComponent = get_node_or_null("StatusReceiverComponent")
@onready var overhead_bar: Node2D = get_node_or_null("OverheadHealthBar") as Node2D

var target_player: Player = null
var original_color: Color = Color(0.46, 0.16, 0.52, 1.0) # Violeta oscuro
var _flash_tween: Tween = null
var contact_cooldown: float = 0.0
var is_aggroed: bool = false


func _ready() -> void:
	EnemyArtScript.attach(self, art_kind)
	_ensure_components()
	if visual_rect != null:
		original_color = visual_rect.color
	
	if is_inside_tree() and get_tree() != null:
		target_player = get_tree().get_first_node_in_group(&"player") as Player




func _physics_process(delta: float) -> void:
	# 1. Aplicar gravedad vertical
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# 2. Perseguir al jugador en el eje horizontal con rango de detección y modificador dinámico
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group(&"player") as Player
	
	var effective_speed: float = move_speed
	if status_receiver != null:
		effective_speed *= status_receiver.get_speed_multiplier()
	effective_speed *= ZoneModifierManager.get_world_mult("enemy_speed_mult", 1.0)
	
	if target_player != null and is_instance_valid(target_player):
		var dist: float = global_position.distance_to(target_player.global_position)
		if dist <= aggro_range:
			is_aggroed = true
		
		if is_aggroed:
			var diff_x: float = target_player.global_position.x - global_position.x
			if absf(diff_x) > 12.0:
				var move_dir: float = signf(diff_x)
				velocity.x = move_toward(velocity.x, move_dir * effective_speed, CHASE_ACCEL * delta)
				if visuals != null:
					visuals.scale.x = move_dir
			else:
				velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	
	if contact_cooldown > 0.0:
		contact_cooldown = maxf(0.0, contact_cooldown - delta)
	
	move_and_slide()
	
	# Daño por contacto si colisiona con el cuerpo del jugador (inhibido si el enemigo está aturdido)
	var is_currently_stunned: bool = status_receiver != null and status_receiver.is_stunned
	if contact_cooldown <= 0.0 and not is_currently_stunned:
		for i in get_slide_collision_count():
			var col: KinematicCollision2D = get_slide_collision(i)
			var collider: Object = col.get_collider()
			if collider is Player:
				var player_ref: Player = collider as Player
				player_ref.take_damage(contact_damage)
				contact_cooldown = 0.8
				break


func _ensure_components() -> void:
	if health_component == null:
		health_component = get_node_or_null("HealthComponent") as HealthComponent
	if status_receiver == null:
		status_receiver = get_node_or_null("StatusReceiverComponent") as StatusReceiverComponent
	if health_component != null:
		if not health_component.damage_taken.is_connected(_on_damage_taken):
			health_component.damage_taken.connect(_on_damage_taken)
		if not health_component.died.is_connected(_on_died):
			health_component.died.connect(_on_died)
	
	if overhead_bar == null:
		overhead_bar = get_node_or_null("OverheadHealthBar") as Node2D
	if overhead_bar == null:
		var bar_scene: PackedScene = load("res://entities/ui/overhead_health_bar.tscn")
		if bar_scene != null:
			overhead_bar = bar_scene.instantiate() as Node2D
			overhead_bar.name = "OverheadHealthBar"
			overhead_bar.set("vertical_offset_y", -58.0)
			add_child(overhead_bar)
	if overhead_bar != null and health_component != null and overhead_bar.has_method("setup"):
		overhead_bar.call("setup", health_component, entity_name)


## Punto de entrada para impactos de combate.
func take_hit(payload: HitPayload) -> void:
	_ensure_components()
	is_aggroed = true
	if status_receiver != null and payload != null:
		status_receiver.apply_payload(payload)
	
	if health_component != null:
		health_component.take_hit(payload)
	
	# Aplicar retroceso físico (knockback)
	if payload != null and payload.knockback_force > 0.0:
		velocity.x = payload.knockback_direction.x * payload.knockback_force * 0.75
		velocity.y = -90.0 # Impulso ascendente ligero de aturdimiento


func _on_damage_taken(amount: float, is_critical: bool, damage_type: String) -> void:
	_play_hit_flash()
	# Si no es DoT periódico (que ya fue generado por StatusReceiverComponent), spawnear número flotante
	if damage_type != "FIRE_DOT":
		_spawn_damage_number(amount, is_critical, damage_type)


func _play_hit_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	
	if anim_sprite != null:
		anim_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0) # Flash blanco brillante
		_flash_tween = create_tween()
		_flash_tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.08)
		if status_receiver != null:
			_flash_tween.finished.connect(status_receiver._update_visual_tint)
		return

	if visual_rect == null:
		return
	visual_rect.color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual_rect, "color", original_color, 0.08)
	if status_receiver != null:
		_flash_tween.finished.connect(status_receiver._update_visual_tint)



func _spawn_damage_number(amount: float, is_critical: bool, damage_type: String) -> void:
	if damage_number_scene == null or not is_inside_tree():
		return
	
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	
	var dmg_instance: Node = damage_number_scene.instantiate()
	if dmg_instance is DamageNumber:
		var dmg_num: DamageNumber = dmg_instance as DamageNumber
		dmg_num.global_position = global_position + Vector2(0, -52.0)
		var container: Node = tree.current_scene
		if container == null:
			container = owner if owner != null else get_parent()
		if container == null:
			container = tree.root
		if container != null:
			container.add_child(dmg_num)
			dmg_num.setup(amount, is_critical, damage_type)


func _on_died() -> void:
	# Ocultar y deshabilitar colisiones inmediatamente para no procesar más impactos
	visible = false
	set_physics_process(false)
	if hurtbox != null:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	# Diferir la instanciación de drops al final del frame para no mutar el árbol durante el flush de física
	_deferred_death_routine.call_deferred()


func _deferred_death_routine() -> void:
	_spawn_loot()
	GearLootScript.try_drop(self, loot_table)
	_spawn_exp_orb()
	_spawn_rune_drop()
	var metrics_mgr: MetricsManager = MetricsManager.get_instance()
	if metrics_mgr != null:
		metrics_mgr.record_kill("BasicRunner")
	died.emit()
	queue_free()


func _spawn_rune_drop() -> void:
	if drop_rune_on_death == null or not is_inside_tree():
		return
	var rune_scene: PackedScene = load("res://entities/items/rune_pickup.tscn") as PackedScene
	if rune_scene == null:
		return
	var pickup_node: Node = rune_scene.instantiate()
	if pickup_node is RunePickup:
		var pickup: RunePickup = pickup_node as RunePickup
		pickup.rune_data = drop_rune_on_death
		pickup.global_position = global_position + Vector2(0, -16.0)
		var container: Node = get_tree().current_scene
		if container == null:
			container = owner if owner != null else get_parent()
		if container != null:
			container.add_child(pickup)
			print("[BasicRunner] ¡Runa '%s' dropeada al morir!" % drop_rune_on_death.rune_name)


func _spawn_loot() -> void:
	if loot_table == null or loot_drop_scene == null or not is_inside_tree():
		return
	
	var drops: Array[Dictionary] = loot_table.roll_drops()
	if drops.is_empty():
		return
	
	var coin_mult: float = ZoneModifierManager.get_world_mult("coin_drop_mult", 1.0)
	
	for drop in drops:
		var type_str: String = drop.get("type", "COIN")
		var count: int = drop.get("amount", 1)
		
		# Multiplicador de botín por contratos de zona de riesgo (ej: +150% = 2.5x)
		if type_str.to_upper() == "COIN" and coin_mult > 1.0:
			count = maxi(1, int(roundf(float(count) * coin_mult)))
		
		# Dispersión en abanico (efecto piñata) de cada elemento individual
		# Se crean de a poco en los cuadros siguientes (combat/death_fx_queue.gd): muchas muertes juntas no congelan
		for i in range(count):
			DeathFxQueueScript.loot(self, loot_drop_scene, type_str, 1, global_position)



func _spawn_exp_orb() -> void:
	if exp_orb_scene == null or not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	# -1: el orbe da la experiencia que trae su escena
	DeathFxQueueScript.exp_orb(self, exp_orb_scene, -1.0, global_position)

