extends "res://entities/enemies/basic_runner.gd"
## Rata de techo (alcantarillas, 1-03): camina cabeza abajo por el techo hacia el jugador. Al quedar sobre él se frena
## un instante (aviso con un chillido) y se suelta; al caer pasa a ser una rata común (`BasicRunner`).
## Lleva el arte volteado en vertical y el cuerpo colgando del techo (origen = el punto del techo donde se agarra).
## Sin class_name a propósito: se carga por escena.

enum Phase { CRAWL, WARN, DROPPED }

const CRAWL_SPEED: float = 150.0
## Distancia horizontal al jugador (px) a la que se frena para soltarse, y duración del aviso.
const DROP_RANGE: float = 55.0
const WARN_TIME: float = 0.4
## Empuje constante hacia el techo para seguir pegada a él.
const STICK_SPEED: float = -80.0

## Lo lee `EnemyArt`: sobre el techo no deja cadáver (quedaría pegado al techo).
var on_ceiling: bool = true

var _phase: int = Phase.CRAWL
var _warn_left: float = 0.0
var _flipped_nodes: Array[CollisionShape2D] = []


func _ready() -> void:
	super._ready()
	up_direction = Vector2.DOWN
	if visuals != null:
		visuals.scale.y = -1.0
	# El cuerpo y la hurtbox cuelgan debajo del origen
	for path: String in ["CollisionShape2D", "Hurtbox/CollisionShape2D"]:
		var node: CollisionShape2D = get_node_or_null(path) as CollisionShape2D
		if node != null:
			node.position.y = -node.position.y
			_flipped_nodes.append(node)
	# La barra de vida no se muestra sobre el techo (quedaría fuera del pasillo); aparece al soltarse
	if overhead_bar != null:
		overhead_bar.visible = false


func _physics_process(delta: float) -> void:
	if _phase == Phase.DROPPED:
		super._physics_process(delta)
		return
	delta = FarStepScript.delta_for(self, delta)
	if delta <= 0.0:
		return
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group(&"player") as Player

	var speed: float = CRAWL_SPEED
	if status_receiver != null:
		speed *= status_receiver.get_speed_multiplier()
	var dx: float = 0.0
	if target_player != null and is_instance_valid(target_player):
		dx = target_player.global_position.x - global_position.x
		var dist: float = global_position.distance_to(target_player.global_position)
		if target_player.is_invisible:
			is_aggroed = false
		elif dist <= aggro_range:
			is_aggroed = true

	if _phase == Phase.WARN:
		_warn_left -= delta
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		if _warn_left <= 0.0:
			_drop()
			return
	elif is_aggroed and target_player != null:
		if absf(dx) > DROP_RANGE:
			velocity.x = move_toward(velocity.x, signf(dx) * speed, CHASE_ACCEL * delta)
			if visuals != null:
				visuals.scale.x = signf(dx)
		else:
			_phase = Phase.WARN
			_warn_left = WARN_TIME
			GameFeel.sfx(self, &"rat_screech", global_position, -12.0, 1.9)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)

	velocity.y = STICK_SPEED
	move_and_slide()


## Se suelta del techo: cuerpo y arte vuelven a su lugar y sigue como rata común.
func _drop() -> void:
	_phase = Phase.DROPPED
	on_ceiling = false
	up_direction = Vector2.UP
	if visuals != null:
		visuals.scale.y = 1.0
	for node: CollisionShape2D in _flipped_nodes:
		node.position.y = -node.position.y
	if overhead_bar != null:
		overhead_bar.visible = true
	# El origen pasa de ser el punto de agarre al de los pies: bajar lo que mide el cuerpo
	global_position.y += 28.0
	velocity = Vector2(0.0, 40.0)
	is_aggroed = true
