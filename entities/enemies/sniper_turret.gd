class_name SniperTurret
extends EnemyBase
## Torreta de precisión hostil.
## Utiliza TargetScannerComponent con radio de 550 px.
## Proyecta una línea guía tenue (Line2D) durante 1.2s antes de disparar
## un proyectil veloz de alto daño.

const EnemyArtScript = preload("res://entities/enemies/enemy_art.gd")
const MobScaleScript = preload("res://entities/enemies/mob_scale.gd")
@export var scan_radius: float = 550.0
@export var aim_duration: float = 1.2
@export var attack_cooldown: float = 2.0
@export var projectile_speed: float = 900.0
@export var sniper_damage: float = 40.0
@export var damage_number_scene: PackedScene = preload("res://combat/damage_number.tscn")

@onready var health_component: HealthComponent = $HealthComponent
@onready var visual_rect: ColorRect = $Visuals/ColorRect
@onready var muzzle: Marker2D = $Visuals/Muzzle
@onready var aim_line: Line2D = $AimLine
@onready var target_scanner: TargetScannerComponent = $TargetScannerComponent

var original_color: Color = Color(0.2, 0.22, 0.28, 1.0)
var _flash_tween: Tween = null
var current_target: Node2D = null
var aim_timer: float = 0.0
var cooldown_timer: float = 0.5
var is_aiming: bool = false
var locked_aim_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	var art: Node2D = EnemyArtScript.attach(self, "turret")
	entity_name = "Torreta Francotiradora"
	max_health = 100.0
	move_speed = 0.0
	super._ready()
	MobScaleScript.apply(self, art)
	
	if visual_rect != null:
		original_color = visual_rect.color
	
	if health_component != null:
		health_component.max_health = 100.0
		health_component.current_health = 100.0
		health_component.armor = 20.0
		if not health_component.damage_taken.is_connected(_on_damage_taken):
			health_component.damage_taken.connect(_on_damage_taken)
		if not health_component.died.is_connected(die):
			health_component.died.connect(die)
		if overhead_bar != null and overhead_bar.has_method("setup"):
			overhead_bar.call("setup", health_component, entity_name)
	
	if target_scanner != null:
		target_scanner.detection_radius = scan_radius
		target_scanner.target_groups = ["player"]
		if not target_scanner.target_found.is_connected(_on_target_found):
			target_scanner.target_found.connect(_on_target_found)
		if not target_scanner.target_lost.is_connected(_on_target_lost):
			target_scanner.target_lost.connect(_on_target_lost)
	
	if aim_line != null:
		aim_line.visible = false


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	
	if is_aiming:
		aim_timer += delta
		var spawn_pos: Vector2 = muzzle.global_position if muzzle != null else global_position
		
		# Mantener apuntado hacia el objetivo si sigue activo
		if current_target != null and is_instance_valid(current_target):
			var target_center: Vector2 = current_target.global_position + Vector2(0, -32)
			locked_aim_direction = (target_center - spawn_pos).normalized()
		
		# Actualizar línea de mira
		if aim_line != null:
			aim_line.visible = true
			aim_line.clear_points()
			aim_line.add_point(to_local(spawn_pos))
			aim_line.add_point(to_local(spawn_pos + locked_aim_direction * scan_radius))
			
			# Efecto de carga: la línea se vuelve más brillante y opaca conforme avanza aim_timer
			var progress: float = clampf(aim_timer / aim_duration, 0.0, 1.0)
			aim_line.default_color = Color(1.0, 0.1, 0.1, 0.2 + progress * 0.7)
			aim_line.width = 1.0 + progress * 2.0
		
		if aim_timer >= aim_duration:
			_fire_sniper_shot()
	else:
		if aim_line != null:
			aim_line.visible = false
		
		# Iniciar apuntado si tenemos objetivo y pasó el cooldown
		if cooldown_timer <= 0.0 and current_target != null and is_instance_valid(current_target):
			_start_aiming()


func _on_target_found(new_target: Node2D) -> void:
	current_target = new_target


func _on_target_lost() -> void:
	current_target = null
	if is_aiming:
		_cancel_aiming()


func _start_aiming() -> void:
	is_aiming = true
	aim_timer = 0.0
	var spawn_pos: Vector2 = muzzle.global_position if muzzle != null else global_position
	if current_target != null:
		locked_aim_direction = (current_target.global_position - spawn_pos).normalized()


func _cancel_aiming() -> void:
	is_aiming = false
	aim_timer = 0.0
	if aim_line != null:
		aim_line.visible = false


func _fire_sniper_shot() -> void:
	is_aiming = false
	aim_timer = 0.0
	cooldown_timer = attack_cooldown
	if aim_line != null:
		aim_line.visible = false
	
	var spawn_pos: Vector2 = muzzle.global_position if muzzle != null else global_position
	var aim_dir: Vector2 = locked_aim_direction if locked_aim_direction != Vector2.ZERO else Vector2.LEFT
	
	var payload: HitPayload = HitPayload.new(
		sniper_damage,
		140.0,
		aim_dir,
		self,
		[],
		1,
		3.0,
		0.40
	)
	
	var proj_scene: PackedScene = preload("res://combat/projectile.tscn")
	var proj: Projectile = proj_scene.instantiate() as Projectile
	proj.global_position = spawn_pos
	proj.rotation = aim_dir.angle()
	proj.setup(projectile_speed, payload)
	proj.is_hostile = true
	proj.modulate = Color(1.0, 0.2, 0.2, 1.0)
	
	var container: Node = get_tree().current_scene
	if container == null:
		container = get_parent()
	if container == null:
		container = get_tree().root
	container.add_child(proj)
	GameFeel.sfx(self, &"shot_rifle", spawn_pos, -2.0, 0.75)
	
	# Parpadeo de disparo en el cañón
	if visual_rect != null:
		visual_rect.color = Color(1.0, 0.95, 0.5, 1.0)
		var tw: Tween = create_tween()
		tw.tween_property(visual_rect, "color", original_color, 0.12)


func _on_damage_taken(amount: float, is_critical: bool, damage_type: String) -> void:
	_play_hit_flash()
	if damage_type != "FIRE_DOT" and amount > 0.0:
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
		dmg_num.global_position = global_position + Vector2(0, -42.0)
		var container: Node = tree.current_scene
		if container == null:
			container = owner if owner != null else get_parent()
		if container == null:
			container = tree.root
		if container != null:
			container.add_child(dmg_num)
			dmg_num.setup(amount, is_critical, damage_type)
