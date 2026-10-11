class_name GrapplingHook
extends Node2D
## Herramienta de movilidad táctica: Gancho de anclaje de alta velocidad (1200 px/s).
## Despliega un cabezal conectado mediante un cable `Line2D` hacia el punto de mira.
## Al conectar con terreno sólido (Capa 1):
## - Entra en modo tracción aplicando 520 px/s al jugador hacia el anclaje.
## - Si el jugador presiona salto o llega a 30px del punto de impacto, se suelta
##   inyectando un impulso de salida conservando la inercia acumulada.

signal hooked(point: Vector2)
signal released()

enum HookState { IDLE, EXTENDING, PULLING, RETRACTING }

@export var hook_speed: float = 1200.0
@export var pull_speed: float = 520.0
@export var max_range: float = 520.0
@export var release_distance: float = 30.0
@export var exit_boost_multiplier: float = 1.15
@export var cable_color: Color = Color(0.3, 0.85, 0.95, 0.9)
@export var head_color: Color = Color(0.9, 0.95, 1.0, 1.0)

var current_state: HookState = HookState.IDLE
var player: Player = null
var hook_origin: Vector2 = Vector2.ZERO
var hook_tip: Vector2 = Vector2.ZERO
var hook_dir: Vector2 = Vector2.RIGHT
var anchor_point: Vector2 = Vector2.ZERO
var cable_length: float = 0.0

@onready var cable_line: Line2D = get_node_or_null("CableLine") as Line2D


func _ready() -> void:
	if cable_line == null:
		cable_line = Line2D.new()
		cable_line.width = 2.5
		cable_line.default_color = cable_color
		cable_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		cable_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(cable_line)
	cable_line.visible = false
	cable_line.top_level = true


func launch(origin: Vector2, direction_or_vel: Vector2, p_player: Player) -> void:
	player = p_player
	hook_origin = origin
	hook_tip = origin
	hook_dir = direction_or_vel.normalized()
	cable_length = 0.0
	current_state = HookState.EXTENDING
	
	if cable_line != null:
		cable_line.clear_points()
		cable_line.add_point(hook_origin)
		cable_line.add_point(hook_tip)
		cable_line.visible = true
	
	queue_redraw()


func _physics_process(delta: float) -> void:
	match current_state:
		HookState.IDLE:
			pass
		
		HookState.EXTENDING:
			_process_extending(delta)
		
		HookState.PULLING:
			_process_pulling(delta)
		
		HookState.RETRACTING:
			_process_retracting(delta)


func _process_extending(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_abort()
		return
	
	hook_origin = _get_player_attach_point()
	var step_distance: float = hook_speed * delta
	var next_tip: Vector2 = hook_tip + hook_dir * step_distance
	
	# Raycast contra capa 1 (terreno sólido)
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		hook_tip,
		next_tip,
		1 # Capa 1: Terreno
	)
	var result: Dictionary = space_state.intersect_ray(query)
	
	if not result.is_empty():
		# ¡Contacto con el terreno!
		anchor_point = result["position"]
		hook_tip = anchor_point
		current_state = HookState.PULLING
		hooked.emit(anchor_point)
		_update_cable()
		return
	
	hook_tip = next_tip
	cable_length = hook_origin.distance_to(hook_tip)
	
	if cable_length >= max_range:
		current_state = HookState.RETRACTING
	
	_update_cable()


func _process_pulling(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_abort()
		return
	
	hook_origin = _get_player_attach_point()
	var to_anchor: Vector2 = anchor_point - hook_origin
	var dist: float = to_anchor.length()
	
	# Condición de liberación 1: salto presionado para salir con inercia
	if player.is_jump_just_pressed():
		var exit_vel: Vector2 = to_anchor.normalized() * pull_speed * exit_boost_multiplier
		# Inyectar impulso vertical extra para sensación acrobática limpia
		if exit_vel.y > -240.0:
			exit_vel.y = -240.0
		player.velocity = exit_vel
		_release()
		return
	
	# Condición de liberación 2: a menos de release_distance píxeles del anclaje
	if dist <= release_distance:
		player.velocity = to_anchor.normalized() * (pull_speed * 0.9)
		_release()
		return
	
	# Aplicar fuerza vectorial constante hacia el punto de anclaje
	var pull_dir: Vector2 = to_anchor.normalized()
	player.velocity = pull_dir * pull_speed
	
	_update_cable()


func _process_retracting(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_abort()
		return
	
	hook_origin = _get_player_attach_point()
	var to_origin: Vector2 = hook_origin - hook_tip
	var step: float = hook_speed * delta * 1.5
	
	if to_origin.length() <= step:
		_finish()
		return
	
	hook_tip += to_origin.normalized() * step
	_update_cable()


func _update_cable() -> void:
	if cable_line != null:
		cable_line.clear_points()
		cable_line.add_point(hook_origin)
		cable_line.add_point(hook_tip)
	queue_redraw()


func _get_player_attach_point() -> Vector2:
	if player == null:
		return global_position
	if player.weapon_pivot != null:
		return player.weapon_pivot.global_position
	return player.global_position + Vector2(0.0, -32.0)


func _release() -> void:
	current_state = HookState.RETRACTING
	released.emit()


func _finish() -> void:
	current_state = HookState.IDLE
	if cable_line != null:
		cable_line.visible = false
	queue_free()


func _abort() -> void:
	current_state = HookState.IDLE
	if cable_line != null:
		cable_line.visible = false
	queue_free()


func _draw() -> void:
	if current_state != HookState.IDLE:
		# Dibujar punta del gancho en hook_tip (en coordenadas locales de este nodo)
		var local_tip: Vector2 = to_local(hook_tip)
		draw_circle(local_tip, 4.0, head_color)
		draw_circle(local_tip, 2.0, Color.BLACK)
