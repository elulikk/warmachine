extends Node
## Hechizo de los Dardos de Hechizo: mientras dura, el enemigo deja de perseguir al jugador y pelea contra los suyos.
## Lo crea `StatusReceiverComponent.apply_charm` como hijo del enemigo. Apaga la IA propia del anfitrión
## (`set_physics_process(false)`), lo mueve hacia el enemigo más cercano y le pega con su `contact_damage`.
## Los golpes salen a nombre del jugador, así las bajas cuentan para él. Al terminar devuelve la IA.
## Sin class_name: lo carga por preload el StatusReceiverComponent (ver class-cycle-gotcha).

const SEARCH_RANGE: float = 700.0
const ATTACK_RANGE: float = 46.0
const ATTACK_COOLDOWN: float = 0.8
const SPEED_MULT: float = 1.25
const MIN_SPEED: float = 90.0
const GRAVITY: float = 980.0

var _host: CharacterBody2D = null
var _time_left: float = 0.0
var _attack_left: float = 0.0
var _target: Node2D = null
var _retarget_left: float = 0.0


func start(duration: float) -> void:
	_host = get_parent() as CharacterBody2D
	if _host == null:
		queue_free()
		return
	_time_left = maxf(_time_left, duration)
	_host.set_physics_process(false)
	_host.add_to_group(&"charmed")
	_set_charmed(true)


func _physics_process(delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		queue_free()
		return
	if (_host.get("is_dead") == true):
		_end()
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end()
		return
	# Que no le pegue al jugador ni se ponga a perseguirlo por su cuenta
	if "is_aggroed" in _host:
		_host.is_aggroed = false

	if not _host.is_on_floor():
		_host.velocity.y += GRAVITY * delta

	_retarget_left -= delta
	if _target == null or not is_instance_valid(_target) or (_target.get("is_dead") == true) or _retarget_left <= 0.0:
		_target = _find_target()
		_retarget_left = 0.5

	_attack_left = maxf(0.0, _attack_left - delta)
	var stunned: bool = false
	var status: Object = _host.get("status_receiver") as Object
	if status != null:
		stunned = status.get("is_stunned") == true
	if _target != null and not stunned:
		var dx: float = _target.global_position.x - _host.global_position.x
		var dir: float = signf(dx) if dx != 0.0 else 1.0
		var visuals: Node2D = _host.get_node_or_null("Visuals") as Node2D
		if visuals != null:
			visuals.scale.x = dir
		if absf(dx) > ATTACK_RANGE:
			var speed: float = maxf(MIN_SPEED, float(_host.get("move_speed")) if "move_speed" in _host else MIN_SPEED)
			_host.velocity.x = move_toward(_host.velocity.x, dir * speed * SPEED_MULT, 900.0 * delta)
		else:
			_host.velocity.x = move_toward(_host.velocity.x, 0.0, 900.0 * delta)
			if _attack_left <= 0.0:
				_attack(dir)
	else:
		_host.velocity.x = move_toward(_host.velocity.x, 0.0, 600.0 * delta)
	_host.move_and_slide()


func _attack(dir: float) -> void:
	_attack_left = ATTACK_COOLDOWN
	if _target == null or not _target.has_method("take_hit"):
		return
	var damage: float = maxf(12.0, float(_host.get("contact_damage")) * 1.5) if "contact_damage" in _host else 15.0
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	var payload: HitPayload = HitPayload.new(damage, 220.0, Vector2(dir, -0.2), player, [], 1, 0.0, 0.2)
	_target.take_hit(payload)
	var art: Node = _host.get_node_or_null("Visuals/EnemyArt")
	if art != null and art.has_method("play_attack_for"):
		art.call("play_attack_for", 0.3)
	GameFeel.sfx(_host, &"hit_flesh", _host.global_position, -6.0)


## Enemigo más cercano que no esté hechizado ni muerto.
func _find_target() -> Node2D:
	var best: Node2D = null
	var best_dist: float = SEARCH_RANGE
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or enemy == _host or enemy.is_in_group(&"charmed") or (enemy.get("is_dead") == true):
			continue
		var dist: float = enemy.global_position.distance_to(_host.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _set_charmed(value: bool) -> void:
	var status: Object = _host.get("status_receiver") as Object
	if status != null:
		status.set("is_charmed", value)
		if status.has_method("_update_visual_tint"):
			status.call("_update_visual_tint")


func _end() -> void:
	if _host != null and is_instance_valid(_host):
		_host.remove_from_group(&"charmed")
		_set_charmed(false)
		if not (_host.get("is_dead") == true):
			_host.set_physics_process(true)
	queue_free()
