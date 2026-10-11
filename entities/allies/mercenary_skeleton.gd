class_name MercenarySkeleton
extends AllyBase
## Mercenario Terrestre Contratable.
## Inicia en estado NEUTRAL esperando interacción del Jugador con la tecla 'E'.
## Al pagar el costo (15 monedas), pasa a estado SEGUIDOR/COMBATE,
## acompañando al jugador, saltando desniveles y ejecutando tajos cuerpo a cuerpo
## con MeleeHitbox sobre los enemigos detectados por su TargetScannerComponent.

const EnemyArtScript = preload("res://entities/enemies/enemy_art.gd")
enum MercenaryState { NEUTRAL, FOLLOW, COMBAT }

@export_group("Combate Mercenario")
@export var melee_damage: float = 35.0
@export var slash_rate: float = 1.2 # Tajos por segundo
@export var melee_hitbox_scene: PackedScene = preload("res://combat/melee_hitbox.tscn")
@export var jump_velocity: float = -380.0

@onready var hire_prompt: Node2D = get_node_or_null("HirePrompt")
@onready var prompt_label: Label = get_node_or_null("HirePrompt/Label")
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")

var current_state: MercenaryState = MercenaryState.NEUTRAL
var _slash_timer: float = 0.0
var _player_in_range: bool = false
var _prompt_tween: Tween = null


func _ready() -> void:
	EnemyArtScript.attach(self, "skeleton")
	super._ready()
	
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
	
	if is_hired:
		current_state = MercenaryState.FOLLOW
		if hire_prompt != null:
			hire_prompt.visible = false
		if interaction_area != null:
			interaction_area.monitoring = false
			interaction_area.monitorable = false
	else:
		current_state = MercenaryState.NEUTRAL
		if hire_prompt != null:
			hire_prompt.visible = true
			_pulse_prompt(false)


func _physics_process(delta: float) -> void:
	# 1. Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# 2. Cooldown de tajos cuerpo a cuerpo
	if _slash_timer > 0.0:
		_slash_timer = maxf(0.0, _slash_timer - delta)
	
	# 3. Lógica según estado
	match current_state:
		MercenaryState.NEUTRAL:
			_process_neutral_state(delta)
		MercenaryState.FOLLOW:
			_process_follow_state(delta)
		MercenaryState.COMBAT:
			_process_combat_state(delta)
	
	move_and_slide()
	
	# 4. Procesar rescate por Leash heredado de AllyBase si está contratado
	super._physics_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_hired or not _player_in_range:
		return
	
	var is_interact_action: bool = false
	if event.is_action_pressed("interact"):
		is_interact_action = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E or event.keycode == KEY_E:
			is_interact_action = true
	
	if is_interact_action:
		get_viewport().set_input_as_handled()
		_try_hire()


func _process_neutral_state(delta: float) -> void:
	# Fricción horizontal cuando está en reposo neutral
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)


func _process_follow_state(delta: float) -> void:
	# Evaluar si el escáner detectó un blanco hostil
	if target_scanner != null and target_scanner.has_target():
		current_state = MercenaryState.COMBAT
		return
	
	var player: Player = get_player()
	if player == null or not is_instance_valid(player):
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		return
	
	var dx: float = player.global_position.x - global_position.x
	var follow_stop_distance: float = 60.0
	
	if absf(dx) > follow_stop_distance:
		var dir: float = signf(dx)
		velocity.x = dir * move_speed
		if visuals != null:
			visuals.scale.x = dir
		
		# Salto de desniveles y plataformas
		if is_on_floor():
			var player_higher: bool = (player.global_position.y < global_position.y - 28.0) and (absf(dx) < 130.0)
			if is_on_wall() or player_higher:
				velocity.y = jump_velocity
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)


func _process_combat_state(delta: float) -> void:
	if target_scanner == null:
		current_state = MercenaryState.FOLLOW
		return
	
	var target: Node2D = target_scanner.get_current_target()
	if target == null or not is_instance_valid(target):
		current_state = MercenaryState.FOLLOW
		return
	
	var target_pos: Vector2 = target.global_position
	var col_shape: CollisionShape2D = target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_shape != null:
		target_pos = col_shape.global_position
	elif target is CharacterBody2D:
		target_pos += Vector2(0.0, -18.0)
	
	var dx: float = target_pos.x - global_position.x
	var dist: float = global_position.distance_to(target_pos)
	var dir: float = signf(dx) if absf(dx) > 4.0 else (visuals.scale.x if visuals != null else 1.0)
	
	if visuals != null and dir != 0.0:
		visuals.scale.x = dir
	
	# Distancia de tajo cuerpo a cuerpo (~46px)
	if dist <= 48.0:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		if _slash_timer <= 0.0:
			_execute_melee_attack(target, target_pos)
			_slash_timer = 1.0 / maxf(0.1, slash_rate)
	else:
		# Acercarse al enemigo al trote de combate
		velocity.x = dir * (move_speed * 1.1)
		if is_on_floor():
			var target_higher: bool = (target_pos.y < global_position.y - 22.0) and (absf(dx) < 100.0)
			if is_on_wall() or target_higher:
				velocity.y = jump_velocity


func _execute_melee_attack(target_node: Node2D, target_pos: Vector2) -> void:
	if melee_hitbox_scene == null or not is_inside_tree():
		return
	
	var attack_origin: Vector2 = global_position + Vector2(0.0, -18.0)
	var aim_dir: Vector2 = (target_pos - attack_origin).normalized()
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2(visuals.scale.x if visuals != null else 1.0, 0.0)
	
	var slash_instance: Node = melee_hitbox_scene.instantiate()
	if slash_instance is MeleeHitbox:
		var slash: MeleeHitbox = slash_instance as MeleeHitbox
		slash.global_position = attack_origin
		
		var container: Node = get_tree().current_scene
		if container == null:
			container = get_parent()
		if container != null:
			container.add_child(slash)
		
		var payload: HitPayload = HitPayload.new(
			melee_damage,
			170.0,
			aim_dir,
			self,
			["mercenary_slash"]
		)
		
		slash.execute_swing(self, payload, 85.0, 0.16, aim_dir)
		
		# Impulso ligero de embestida hacia adelante
		velocity.x = aim_dir.x * 110.0


func _try_hire() -> void:
	var player: Player = get_player()
	if player == null or not is_instance_valid(player):
		return
	
	if player.stats_manager == null:
		return
	
	if player.stats_manager.spend_coins(hire_cost):
		hire()
	else:
		if voice_component != null:
			voice_component.speak("¡Necesito %d monedas! (Tienes: %d)" % [hire_cost, player.stats_manager.coins], 2.2, Color(1.0, 0.35, 0.35))


## Activa al mercenario como aliado contratado.
func hire() -> void:
	is_hired = true
	current_state = MercenaryState.FOLLOW
	_configure_hurtbox()
	
	if hire_prompt != null:
		hire_prompt.visible = false
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", false)
		interaction_area.set_deferred("monitorable", false)
	
	if voice_component != null:
		voice_component.speak("¡Espada lista! ¡A sus órdenes!", 2.2, Color(0.3, 1.0, 0.55))
	
	hired.emit()
	print("[MercenarySkeleton] ¡Contratado por %d monedas! Pasando a FollowState." % hire_cost)


func _on_interaction_body_entered(body: Node2D) -> void:
	if body is Player and not is_hired:
		_player_in_range = true
		_pulse_prompt(true)


func _on_interaction_body_exited(body: Node2D) -> void:
	if body is Player and not is_hired:
		_player_in_range = false
		_pulse_prompt(false)


func _pulse_prompt(highlight: bool) -> void:
	if prompt_label == null:
		return
	
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	
	_prompt_tween = create_tween()
	if highlight:
		prompt_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.45, 1.0))
		_prompt_tween.tween_property(hire_prompt, "scale", Vector2(1.15, 1.15), 0.15)
	else:
		prompt_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
		_prompt_tween.tween_property(hire_prompt, "scale", Vector2.ONE, 0.15)
