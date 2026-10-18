class_name ShieldedSentinel
extends EnemyBase
## Enemigo de tipo Centinela con Escudo.
## 60 HP, 0 armadura, 130 de escudo de energía recargable.
## Escudo de energía: elipse celeste que reacciona al daño absorbido (ver entities/shield/energy_shield.gd).

## Aceleración hacia la velocidad de persecución (px/s²). Permite que el knockback se note antes de retomar la marcha.
const AggroLeash = preload("res://entities/enemies/aggro_leash.gd")
const FarStepScript = preload("res://core/far_step.gd")
const EnemyArtScript = preload("res://entities/enemies/enemy_art.gd")
const HopScript = preload("res://entities/enemies/obstacle_hop.gd")
const MobScaleScript = preload("res://entities/enemies/mob_scale.gd")
const EnergyShieldScript = preload("res://entities/shield/energy_shield.gd")
const CHASE_ACCEL: float = 900.0

@export var contact_damage: float = 14.0
@export var aggro_range: float = 320.0
@export var gravity: float = 980.0
@export var damage_number_scene: PackedScene = preload("res://combat/damage_number.tscn")

@onready var health_component: HealthComponent = $HealthComponent
@onready var visual_rect: ColorRect = $Visuals/ColorRect
@onready var visuals: Node2D = $Visuals

var target_player: Player = null
var original_color: Color = Color(0.2, 0.45, 0.75, 1.0)
var _flash_tween: Tween = null
var contact_cooldown: float = 0.0
var is_aggroed: bool = false


func _ready() -> void:
	var art: Node2D = EnemyArtScript.attach(self, "sentinel")
	entity_name = "Centinela de Escudo"
	max_health = 70.0
	move_speed = 70.0
	super._ready()
	MobScaleScript.apply(self, art)
	
	if visual_rect != null:
		original_color = visual_rect.color
	
	if health_component != null:
		health_component.max_health = 70.0
		health_component.current_health = 60.0
		health_component.armor = 0.0
		health_component.max_shield = 130.0
		health_component.current_shield = 130.0
		health_component.shield_recharge_delay = 3.0
		health_component.shield_recharge_rate = 30.0
		
		if not health_component.damage_taken.is_connected(_on_damage_taken):
			health_component.damage_taken.connect(_on_damage_taken)
		if not health_component.shield_absorbed.is_connected(_on_shield_absorbed):
			health_component.shield_absorbed.connect(_on_shield_absorbed)
		if not health_component.died.is_connected(die):
			health_component.died.connect(die)
		if overhead_bar != null and overhead_bar.has_method("setup"):
			overhead_bar.call("setup", health_component, entity_name)
	
	if visuals != null and health_component != null:
		var energy_shield: Node2D = EnergyShieldScript.new()
		energy_shield.name = "EnergyShield"
		visuals.add_child(energy_shield)
		energy_shield.setup(health_component, Vector2(0, -24) * MobScaleScript.MOB_SCALE, Vector2(24, 32) * MobScaleScript.MOB_SCALE)

	target_player = get_tree().get_first_node_in_group(&"player") as Player


func _physics_process(delta: float) -> void:
	delta = FarStepScript.delta_for(self, delta)
	if delta <= 0.0:
		return
	if is_dead:
		return
	
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group(&"player") as Player
	
	var effective_speed: float = get_effective_move_speed()
	
	if target_player != null and is_instance_valid(target_player):
		var dist: float = global_position.distance_to(target_player.global_position)
		if target_player.is_invisible:
			is_aggroed = false
		elif dist <= aggro_range:
			is_aggroed = true
		elif is_aggroed and AggroLeash.should_drop(self, dist, aggro_range):
			is_aggroed = false
		
		if is_aggroed:
			var diff_x: float = target_player.global_position.x - global_position.x
			if absf(diff_x) > 14.0:
				var move_dir: float = signf(diff_x)
				velocity.x = move_toward(velocity.x, move_dir * effective_speed, CHASE_ACCEL * delta)
				if visuals != null:
					visuals.scale.x = move_dir
			else:
				velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
	
	if contact_cooldown > 0.0:
		contact_cooldown = maxf(0.0, contact_cooldown - delta)
	
	HopScript.try_hop(self, signf(velocity.x))
	move_and_slide()
	
	if contact_cooldown <= 0.0:
		for i in get_slide_collision_count():
			var col: KinematicCollision2D = get_slide_collision(i)
			var collider: Object = col.get_collider()
			if collider is Player:
				var player_ref: Player = collider as Player
				player_ref.take_damage(contact_damage)
				contact_cooldown = 0.8
				break


func _on_damage_taken(amount: float, is_critical: bool, damage_type: String) -> void:
	_play_hit_flash()
	if damage_type != "FIRE_DOT" and amount > 0.0:
		_spawn_damage_number(amount, is_critical, damage_type)


## Cuánto escudo se le sacó: número celeste (no usa el "!" de crítico para no pisar el color).
func _on_shield_absorbed(amount: float, _is_critical: bool, _damage_type: String) -> void:
	_spawn_damage_number(amount, false, "SHIELD")


func _play_hit_flash() -> void:
	if visual_rect == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	
	visual_rect.color = Color(0.6, 0.9, 1.0, 1.0) # Destello celeste eléctrico
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
		dmg_num.global_position = global_position + Vector2(0, -56.0 * MobScaleScript.MOB_SCALE)
		var container: Node = tree.current_scene
		if container == null:
			container = owner if owner != null else get_parent()
		if container == null:
			container = tree.root
		if container != null:
			container.add_child(dmg_num)
			dmg_num.setup(amount, is_critical, damage_type)
