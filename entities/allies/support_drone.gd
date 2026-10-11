class_name SupportDrone
extends Node2D
## Dron de Apoyo Orbital.
## Flota acompañando al jugador con interpolación suave (lerp) sobre su cabeza.
## Equipa un TargetScannerComponent para detectar enemigos automáticamente
## y abre fuego con ráfagas continuas solicitando proyectiles al ProjectilePool.

const EnemyArtScript = preload("res://entities/enemies/enemy_art.gd")
@export_group("Seguimiento")
@export var follow_offset: Vector2 = Vector2(-25.0, -35.0)
@export var lerp_weight: float = 7.0
@export var hover_amplitude: float = 2.5
@export var hover_frequency: float = 4.0

@export_group("Combate")
@export var fire_rate: float = 1.5 # Disparos por segundo
@export var base_damage: float = 12.0
@export var projectile_speed: float = 850.0

@onready var scanner: TargetScannerComponent = $TargetScannerComponent
@onready var visuals: Node2D = $Visuals
@onready var muzzle: Marker2D = $Muzzle

var target_player: Player = null
var _fire_timer: float = 0.0
var _hover_time: float = 0.0


func _ready() -> void:
	EnemyArtScript.attach(self, "drone")
	add_to_group(&"allies")
	_find_player()
	if target_player != null:
		global_position = target_player.global_position + follow_offset


func _physics_process(delta: float) -> void:
	_process_movement(delta)
	_process_combat(delta)


func _find_player() -> void:
	if target_player == null or not is_instance_valid(target_player):
		if is_inside_tree() and get_tree() != null:
			target_player = get_tree().get_first_node_in_group(&"player") as Player


func _process_movement(delta: float) -> void:
	_find_player()
	if target_player == null or not is_instance_valid(target_player):
		return
	
	_hover_time += delta * hover_frequency
	var hover_offset: Vector2 = Vector2(0.0, sin(_hover_time) * hover_amplitude)
	var target_dest: Vector2 = target_player.global_position + follow_offset + hover_offset
	
	global_position = global_position.lerp(target_dest, clampf(lerp_weight * delta, 0.0, 1.0))


func _process_combat(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer = maxf(0.0, _fire_timer - delta)
	
	if scanner == null:
		return
	
	var enemy: Node2D = scanner.get_current_target()
	if enemy == null or not is_instance_valid(enemy):
		return
	
	var target_pos: Vector2 = enemy.global_position
	var col_shape: CollisionShape2D = enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape != null:
		target_pos = col_shape.global_position
	elif enemy is CharacterBody2D:
		target_pos += Vector2(0.0, -18.0)
	
	var aim_dir: Vector2 = (target_pos - global_position).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT
	
	# Orientar visualmente el dron o el cañón
	if muzzle != null:
		muzzle.position = aim_dir * 8.0
	
	if _fire_timer <= 0.0:
		_fire_burst_shot(aim_dir)
		_fire_timer = 1.0 / maxf(0.1, fire_rate)


func _fire_burst_shot(dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	
	var pool: ProjectilePool = tree.get_first_node_in_group(&"projectile_pool") as ProjectilePool
	if pool == null:
		return
	
	var spawn_pos: Vector2 = muzzle.global_position if muzzle != null else global_position
	var payload: HitPayload = HitPayload.new(
		base_damage,
		45.0,
		dir,
		self,
		["drone_beam"]
	)
	
	var spawned_proj: Node2D = pool.get_projectile(spawn_pos, dir, payload, projectile_speed)
	if spawned_proj is Projectile:
		var p: Projectile = spawned_proj as Projectile
		p.modulate = Color(0.35, 0.88, 1.0, 1.0) # Brillo celeste de energía
	
	GameFeel.sfx(self, &"shot_drone", spawn_pos, -8.0)
	_trigger_muzzle_fx()


func _trigger_muzzle_fx() -> void:
	if visuals == null:
		return
	visuals.scale = Vector2(1.35, 1.35)
	var tw: Tween = create_tween()
	tw.tween_property(visuals, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
