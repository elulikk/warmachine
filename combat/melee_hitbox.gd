class_name MeleeHitbox
extends Area2D
## Sensor de corte cuerpo a cuerpo con barrido angular (Tween) y mecánica de Parry Balístico.
## Detecta enemigos y desvía proyectiles hostiles si colisionan en la ventana inicial de 0.06s.

signal parry_performed(projectile: Projectile)
signal target_hit(target: Node)

@export var parry_window: float = 0.06

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var slash_rect: ColorRect = $SlashVisual/ColorRect
@onready var slash_visual: Node2D = $SlashVisual

var hit_targets: Array[Node] = []
var elapsed_time: float = 0.0
var payload: HitPayload = null
var source_player: CharacterBody2D = null
var _swing_tween: Tween = null
var is_active: bool = false
var custom_crit_multiplier: float = 1.5


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	if is_active:
		elapsed_time += delta


## Inicia el barrido angular del tajo cuerpo a cuerpo orientado hacia la dirección de apuntado.
func execute_swing(
	p_player: CharacterBody2D,
	p_payload: HitPayload,
	arc_degrees: float,
	duration: float,
	aim_direction: Vector2
) -> void:
	source_player = p_player
	payload = p_payload
	hit_targets.clear()
	elapsed_time = 0.0
	is_active = true
	
	var base_angle: float = aim_direction.angle()
	var half_arc: float = deg_to_rad(arc_degrees * 0.5)
	# El tajo siempre cae de arriba hacia abajo: a la derecha el ángulo aumenta y a la izquierda
	# (donde el mismo sentido sería de abajo hacia arriba) se invierte el barrido.
	var sweep_sign: float = -1.0 if aim_direction.x < 0.0 else 1.0
	var start_angle: float = base_angle - half_arc * sweep_sign
	var end_angle: float = base_angle + half_arc * sweep_sign

	rotation = start_angle
	
	if slash_visual != null:
		slash_visual.modulate.a = 0.95
	
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	
	_swing_tween = create_tween()
	_swing_tween.set_parallel(true)
	
	# Barrido angular de la espada
	_swing_tween.tween_property(self, "rotation", end_angle, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Desvanecimiento de la estela semitransparente blanca
	if slash_visual != null:
		_swing_tween.tween_property(slash_visual, "modulate:a", 0.0, duration).set_delay(duration * 0.35)
	
	_swing_tween.chain().tween_callback(_on_swing_completed)


func _on_swing_completed() -> void:
	is_active = false
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	_handle_target_collision(body)


func _on_area_entered(area: Area2D) -> void:
	# 1. Comprobar si es un proyectil para la mecánica de Parry Balístico
	if area is Projectile:
		_check_projectile_parry(area as Projectile)
		return
	elif area.get_parent() is Projectile:
		_check_projectile_parry(area.get_parent() as Projectile)
		return
	
	# 2. Si no es proyectil, evaluar impacto de daño (ej: Hurtbox)
	_handle_target_collision(area)


## Evalúa y ejecuta el desvío balístico del proyectil si está dentro de la ventana de parry.
func _check_projectile_parry(proj: Projectile) -> void:
	if not is_active or proj == null or hit_targets.has(proj):
		return
	
	# Ventana de desvío estricta (primeros 0.06s del tajo)
	if elapsed_time <= parry_window:
		# Comprobar si el proyectil es hostil o ajeno al jugador
		var is_hostile_proj: bool = proj.is_hostile
		if not is_hostile_proj and proj.payload != null and proj.payload.source_node != source_player:
			is_hostile_proj = true
		
		# Incluso si se prueba contra cualquier proyectil activo no desviado:
		if is_hostile_proj or not proj.is_parried:
			hit_targets.append(proj)
			
			# Ejecutar deflexión balística
			proj.deflect(source_player, 1.5)
			
			# Generar destello de impacto blanco
			_spawn_hit_flash(proj.global_position)
			
			GameFeel.sfx(self, &"parry", Vector2.INF, -2.0)
			parry_performed.emit(proj)
			print("[MeleeHitbox] ¡PARRY BALÍSTICO EXITOSO! Proyectil desviado en t=%.3fs con daño x1.5." % elapsed_time)


## Evalúa impacto cuerpo a cuerpo sobre enemigos.
func _handle_target_collision(target: Node) -> void:
	if not is_active or payload == null or target == null:
		return
	
	# Evitar autogolpe con el propio jugador portador
	if target == source_player or (source_player != null and target.is_ancestor_of(source_player)):
		return
	
	var receiver: Node = target
	if not receiver.has_method("take_hit"):
		var parent: Node = target.get_parent()
		if parent != null and parent.has_method("take_hit"):
			receiver = parent
	
	# Fuego amigo: un tajo de aliado (mercenario) no lastima al Jugador ni a otros aliados
	var friendly: bool = source_player != null and source_player.is_in_group(&"allies") \
		and (receiver.is_in_group(&"player") or receiver.is_in_group(&"allies"))
	if receiver != null and receiver != source_player and not hit_targets.has(receiver) and not friendly:
		if receiver.has_method("take_hit"):
			hit_targets.append(receiver)
			var delivery_payload: HitPayload = payload
			if custom_crit_multiplier != 1.5 and payload.status_effects.has("critical"):
				delivery_payload = payload.duplicate_payload()
				# HealthComponent multiplica por 1.5 en crítico. Ajustamos para alcanzar custom_crit_multiplier exactamente:
				delivery_payload.base_damage = payload.base_damage * (custom_crit_multiplier / 1.5)
			receiver.take_hit(delivery_payload)
			# Game feel: todo golpe melee que conecta frena el tiempo y sacude la cámara
			GameFeel.hit_stop(self)
			GameFeel.shake(self, 3.0, 0.12)
			
			var impact_pos: Vector2 = target.global_position if target is Node2D else global_position
			_spawn_hit_flash(impact_pos)
			target_hit.emit(receiver)


## Genera un destello blanco fugaz (Hit Flash) en las coordenadas del impacto.
func _spawn_hit_flash(pos: Vector2) -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return

	
	var flash: Node2D = Node2D.new()
	flash.global_position = pos
	
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(1.0, 1.0, 1.0, 0.95)
	# Accesibilidad: "Reducir destellos" lo deja como una chispa tenue en vez de un fogonazo blanco
	if bool((load("res://core/settings.gd") as GDScript).call("reduce_flashes")):
		rect.color = Color(1.0, 0.8, 0.5, 0.3)
	rect.custom_minimum_size = Vector2(16, 16)
	rect.offset_left = -8.0
	rect.offset_top = -8.0
	rect.offset_right = 8.0
	rect.offset_bottom = 8.0
	flash.add_child(rect)
	
	var container: Node = tree.current_scene
	if container == null:
		container = get_parent()
	if container == null:
		container = tree.root
	
	container.add_child(flash)
	
	var tw: Tween = flash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector2(1.6, 1.6), 0.08)
	tw.tween_property(rect, "modulate:a", 0.0, 0.08)
	tw.finished.connect(flash.queue_free)
