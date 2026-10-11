class_name TrainingTurret
extends CharacterBody2D
## Torreta de entrenamiento hostil para pruebas de combate y Parry Balístico en el Sandbox.
## Dispara proyectiles lentos hostiles (rojos) hacia el jugador de forma periódica.
## Los proyectiles pueden ser cortados y desviados con el arma Melee (espada).

const EnemyArtScript = preload("res://entities/enemies/enemy_art.gd")
signal health_changed(current: float, max_health: float)
signal died

@export var max_health: float = 80.0
@export var fire_interval: float = 2.4
@export var projectile_speed: float = 280.0
@export var is_turret_active: bool = true

@onready var visual_rect: ColorRect = $Visuals/ColorRect
@onready var muzzle: Marker2D = $Visuals/Muzzle
@onready var status_receiver: StatusReceiverComponent = get_node_or_null("StatusReceiverComponent")

var current_health: float = 0.0
var fire_timer: float = 1.0
var target_player: Player = null
var original_color: Color = Color(0.85, 0.2, 0.2, 1.0)
var _flash_tween: Tween = null


func _ready() -> void:
	EnemyArtScript.attach(self, "training_turret")
	current_health = max_health
	if visual_rect != null:
		original_color = visual_rect.color
	
	target_player = get_tree().get_first_node_in_group(&"player") as Player


func _physics_process(delta: float) -> void:
	if not is_turret_active:
		return
	
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group(&"player") as Player
	
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = fire_interval
		_shoot_hostile_projectile()


func _shoot_hostile_projectile() -> void:
	if target_player == null or not is_instance_valid(target_player):
		return
	
	var spawn_pos: Vector2 = muzzle.global_position if muzzle != null else global_position
	var aim_dir: Vector2 = (target_player.global_position - spawn_pos).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.LEFT
	
	# Crear payload hostil
	var payload: HitPayload = HitPayload.new(
		15.0, # Daño moderado
		80.0,
		aim_dir,
		self,
		[],
		1,
		3.0
	)
	
	# Usar ProjectilePool o instanciar proyectil
	var proj_scene: PackedScene = preload("res://combat/projectile.tscn")
	var proj: Projectile = proj_scene.instantiate() as Projectile
	proj.global_position = spawn_pos
	proj.rotation = aim_dir.angle()
	proj.setup(projectile_speed, payload)
	
	# Marcar explícitamente como proyectil hostil
	proj.is_hostile = true
	proj.modulate = Color(1.0, 0.28, 0.28, 1.0) # Rojo hostil
	
	var container: Node = get_tree().current_scene
	if container == null:
		container = get_parent()
	if container == null:
		container = get_tree().root
	
	container.add_child(proj)
	GameFeel.sfx(self, &"shot_enemy", spawn_pos, -4.0)
	
	# Pequeño parpadeo del cañón de la torreta
	if visual_rect != null:
		visual_rect.color = Color(1.0, 0.9, 0.4, 1.0)
		var tw: Tween = create_tween()
		tw.tween_property(visual_rect, "color", original_color, 0.15)


## Receptor de impactos (incluyendo proyectiles desviados por parry balístico).
func take_hit(payload: HitPayload) -> void:
	if payload == null:
		return
	
	if status_receiver != null:
		status_receiver.apply_payload(payload)
	
	current_health = maxf(0.0, current_health - payload.base_damage)
	health_changed.emit(current_health, max_health)
	
	print("[Torreta de Entrenamiento] ¡Impacto recibido! Daño: %.1f | Vida restante: %.1f" % [payload.base_damage, current_health])
	_trigger_hit_flash()
	
	# Mostrar número de daño
	var dmg_scene: PackedScene = preload("res://combat/damage_number.tscn")
	if dmg_scene != null and is_inside_tree():
		var dmg_inst: DamageNumber = dmg_scene.instantiate() as DamageNumber
		var container: Node = get_tree().current_scene
		if container != null:
			dmg_inst.global_position = global_position + Vector2(0, -38.0)
			container.add_child(dmg_inst)
			var is_crit: bool = payload.base_damage > 20.0
			dmg_inst.setup(payload.base_damage, is_crit, "CRITICAL" if is_crit else "PHYSICAL")
	
	if current_health <= 0.0:
		# Respawn de salud para permitir entrenamiento continuo
		current_health = max_health


func _trigger_hit_flash() -> void:
	if visual_rect == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	visual_rect.color = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual_rect, "color", original_color, 0.08)
