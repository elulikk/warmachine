class_name EnemyBase
extends CharacterBody2D
## Clase base para enemigos en el juego de acción y plataformas 2D.
## Provee la interfaz para recibir impactos mediante HitPayload,
## gestionar puntos de vida, aplicar fuerzas de retroceso (knockback)
## y procesar estados alterados a través de StatusReceiverComponent.

signal health_changed(current_health: float, max_health: float)
signal hit_received(payload: HitPayload)
signal died

@export_group("Identificación y UI")
@export var entity_name: String = "Enemigo"

@export_group("Estadísticas")
@export var max_health: float = 50.0
@export var move_speed: float = 100.0
@export var exp_reward: float = 15.0

const GearLootScript = preload("res://core/loot/gear_loot.gd")
const DeathFxQueueScript = preload("res://combat/death_fx_queue.gd")

@export_group("Botín (Loot)")
@export var loot_table: LootTable
@export var loot_drop_scene: PackedScene = preload("res://entities/items/loot_drop.tscn")
@export var exp_orb_scene: PackedScene = preload("res://entities/items/exp_orb.tscn")

@onready var status_receiver: StatusReceiverComponent = get_node_or_null("StatusReceiverComponent")
@onready var status_display: StatusDisplayComponent = get_node_or_null("StatusDisplayComponent")
@onready var overhead_bar: Node2D = get_node_or_null("OverheadHealthBar") as Node2D

var current_health: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health
	_ensure_status_receiver()
	_ensure_status_display()
	_ensure_overhead_bar()


func _ensure_overhead_bar() -> void:
	if overhead_bar == null:
		overhead_bar = get_node_or_null("OverheadHealthBar") as Node2D
	if overhead_bar == null:
		var bar_scene: PackedScene = load("res://entities/ui/overhead_health_bar.tscn")
		if bar_scene != null:
			overhead_bar = bar_scene.instantiate() as Node2D
			overhead_bar.name = "OverheadHealthBar"
			# Posicionar flotando holgadamente por encima de la entidad
			overhead_bar.set("vertical_offset_y", -60.0)
			add_child(overhead_bar)
	
	if overhead_bar != null and overhead_bar.has_method("setup"):
		var hc: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
		if hc != null:
			overhead_bar.call("setup", hc, entity_name)


func _ensure_status_receiver() -> void:
	if status_receiver == null:
		status_receiver = get_node_or_null("StatusReceiverComponent") as StatusReceiverComponent
	if status_receiver == null:
		status_receiver = StatusReceiverComponent.new()
		status_receiver.name = "StatusReceiverComponent"
		add_child(status_receiver)


func _ensure_status_display() -> void:
	if status_display == null:
		status_display = get_node_or_null("StatusDisplayComponent") as StatusDisplayComponent
	if status_display == null:
		var display_scene: PackedScene = load("res://ui/status_display_component.tscn")
		if display_scene != null:
			status_display = display_scene.instantiate() as StatusDisplayComponent
			status_display.name = "StatusDisplayComponent"
			status_display.offset_y = -56.0
			add_child(status_display)



## Procesa un impacto entrante transportado por un HitPayload.
func take_hit(payload: HitPayload) -> void:
	if is_dead or payload == null:
		return
	
	_ensure_status_receiver()
	if status_receiver != null:
		status_receiver.apply_payload(payload)
	
	var hc: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
	if hc != null:
		hc.take_hit(payload)
		current_health = hc.current_health
		max_health = hc.max_health
	else:
		# Fallback directo si la subclase no usa HealthComponent
		current_health = maxf(0.0, current_health - payload.base_damage)
		health_changed.emit(current_health, max_health)
	
	hit_received.emit(payload)
	
	# Aplicar retroceso (knockback)
	if payload.knockback_force > 0.0:
		velocity = payload.get_knockback_velocity()
	
	if current_health <= 0.0:
		die()


## Retorna la velocidad horizontal efectiva teniendo en cuenta ralentizaciones activas y mutadores de zona.
func get_effective_move_speed() -> float:
	var mult: float = status_receiver.get_speed_multiplier() if status_receiver != null else 1.0
	var speed_mult: float = ZoneModifierManager.get_world_mult("enemy_speed_mult", 1.0)
	return move_speed * mult * speed_mult


## Maneja la muerte de la entidad arrojando el botín configurado antes de eliminarse.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	visible = false
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	var hurt: Area2D = get_node_or_null("Hurtbox") as Area2D
	if hurt != null:
		hurt.set_deferred("monitoring", false)
		hurt.set_deferred("monitorable", false)
	_deferred_die.call_deferred()


func _deferred_die() -> void:
	_spawn_loot()
	GearLootScript.try_drop(self, loot_table)
	_spawn_exp()
	var metrics_mgr: MetricsManager = MetricsManager.get_instance()
	if metrics_mgr != null:
		var type_name: String = get_script().get_global_name()
		if type_name.is_empty():
			type_name = "EnemyBase"
		metrics_mgr.record_kill(type_name)
	died.emit()
	queue_free()


func _spawn_exp() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	
	if exp_orb_scene != null:
		DeathFxQueueScript.exp_orb(self, exp_orb_scene, exp_reward, global_position)
	else:
		var player_node: Player = tree.get_first_node_in_group(&"player") as Player
		if player_node != null and player_node.stats_manager != null:
			player_node.stats_manager.add_experience(exp_reward)


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

