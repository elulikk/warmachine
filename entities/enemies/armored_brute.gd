class_name ArmoredBrute
extends EnemyBase
## Enemigo de tipo Tanque Pesado.
## 220 HP, 65 de armadura, alta resistencia al retroceso y velocidad lenta.
## Ataque melee contundente si entra en contacto físico con el jugador.

## Aceleración hacia la velocidad de persecución (px/s²). Permite que el knockback se note antes de retomar la marcha.
const AggroLeash = preload("res://entities/enemies/aggro_leash.gd")
const FarStepScript = preload("res://core/far_step.gd")
const EnemyArtScript = preload("res://entities/enemies/enemy_art.gd")
const HopScript = preload("res://entities/enemies/obstacle_hop.gd")
const MobScaleScript = preload("res://entities/enemies/mob_scale.gd")
const CHASE_ACCEL: float = 900.0

## Tipo de arte de `EnemyArt` (ver enemy_art.gd): "brute", "thug", "bouncer"...
@export var art_kind: String = "brute"
## Datos propios de cada variante (matón, patovica): nombre, vida, armadura y velocidad.
@export var brute_name: String = "Bruto Acorazado"
@export var brute_health: float = 250.0
@export var brute_armor: float = 65.0
@export var brute_speed: float = 38.0
@export var contact_damage: float = 24.0
@export var aggro_range: float = 350.0
@export var gravity: float = 980.0
@export var damage_number_scene: PackedScene = preload("res://combat/damage_number.tscn")

@onready var health_component: HealthComponent = $HealthComponent
@onready var visual_rect: ColorRect = $Visuals/ColorRect
@onready var visuals: Node2D = $Visuals

var target_player: Player = null
var original_color: Color = Color(0.35, 0.38, 0.44, 1.0)
var _flash_tween: Tween = null
var contact_cooldown: float = 0.0
var is_aggroed: bool = false


func _ready() -> void:
	var art: Node2D = EnemyArtScript.attach(self, art_kind)
	entity_name = brute_name
	max_health = brute_health
	move_speed = brute_speed
	super._ready()
	if overhead_bar != null:
		overhead_bar.set("vertical_offset_y", -80.0)
	MobScaleScript.apply(self, art)
	
	if visual_rect != null:
		original_color = visual_rect.color
	
	if health_component != null:
		health_component.max_health = brute_health
		health_component.current_health = minf(brute_health, brute_health * 0.88)
		health_component.armor = brute_armor
		if not health_component.damage_taken.is_connected(_on_damage_taken):
			health_component.damage_taken.connect(_on_damage_taken)
		if not health_component.died.is_connected(die):
			health_component.died.connect(die)
		if overhead_bar != null and overhead_bar.has_method("setup"):
			overhead_bar.call("setup", health_component, entity_name)
	
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
			if absf(diff_x) > 16.0:
				var move_dir: float = signf(diff_x)
				velocity.x = move_toward(velocity.x, move_dir * effective_speed, CHASE_ACCEL * delta)
				if visuals != null:
					visuals.scale.x = move_dir
			else:
				velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	
	if contact_cooldown > 0.0:
		contact_cooldown = maxf(0.0, contact_cooldown - delta)
	
	HopScript.try_hop(self, signf(velocity.x))
	move_and_slide()
	
	# Ataque melee contundente por contacto físico
	if contact_cooldown <= 0.0:
		for i in get_slide_collision_count():
			var col: KinematicCollision2D = get_slide_collision(i)
			var collider: Object = col.get_collider()
			if collider is Player:
				var player_ref: Player = collider as Player
				player_ref.take_damage(contact_damage)
				contact_cooldown = 1.0
				# Retroceso ligero al jugador
				var push_dir: Vector2 = (player_ref.global_position - global_position).normalized()
				player_ref.velocity += push_dir * 180.0
				break


func take_hit(payload: HitPayload) -> void:
	if is_dead or payload == null:
		return
	is_aggroed = true
	
	# Alta resistencia al retroceso (reduce a 20%)
	var dampened_payload: HitPayload = payload.duplicate_payload()
	dampened_payload.knockback_force *= 0.20
	super.take_hit(dampened_payload)


func _on_damage_taken(amount: float, is_critical: bool, damage_type: String) -> void:
	_play_hit_flash()
	if damage_type != "FIRE_DOT":
		_spawn_damage_number(amount, is_critical, damage_type)


func _play_hit_flash() -> void:
	if visual_rect == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	
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
		dmg_num.global_position = global_position + Vector2(0, -64.0 * MobScaleScript.MOB_SCALE)
		var container: Node = tree.current_scene
		if container == null:
			container = owner if owner != null else get_parent()
		if container == null:
			container = tree.root
		if container != null:
			container.add_child(dmg_num)
			dmg_num.setup(amount, is_critical, damage_type)
