extends CharacterBody2D
## Rata aliada: una rata común que la Flauta de Hamelin (`HamelinFluteController`) pasó al bando del jugador.
## Va detrás del jugador, corre al enemigo más cercano y lo muerde. No tiene vida: los enemigos no atacan aliados.
## Lleva el mismo arte animado que la rata enemiga, con un tinte verdoso para distinguirla.
## Sin class_name a propósito: se crea por `preload` desde el controlador de la flauta.

const EnemyArtScript = preload("res://entities/enemies/enemy_art.gd")

const GROUP_ALLIES: StringName = &"allies"
const GROUP_RAT_ALLIES: StringName = &"rat_allies"
const GROUP_ENEMIES: StringName = &"enemies"

const SPEED: float = 210.0
const GRAVITY: float = 980.0
const JUMP_SPEED: float = 400.0
## Escala del arte y del cuerpo (igual que las ratas enemigas: MobScale.MOB_SCALE).
const BODY_SCALE: float = 1.5
const BODY_SIZE: Vector2 = Vector2(24.0, 16.0)

const BITE_DAMAGE: float = 14.0
const BITE_KNOCKBACK: float = 90.0
const BITE_RANGE: float = 40.0
const BITE_COOLDOWN: float = 0.55
## Alcance para elegir blanco (px) y desnivel máximo en vertical.
const TARGET_RADIUS: float = 420.0
const TARGET_MAX_DY: float = 150.0
const RETARGET_INTERVAL: float = 0.25
## Si se aleja tanto del jugador (px) vuelve a su lado.
const LEASH_DISTANCE: float = 900.0
const OFFMAP_Y: float = 1100.0
const TINT: Color = Color(0.7, 1.0, 0.78, 1.0)

## Lo lee `EnemyArt` para animar el mordisco (sube de golpe al atacar).
var contact_cooldown: float = 0.0

var _visuals: Node2D = null
var _target: Node2D = null
var _retarget_left: float = 0.0
var _slot: float = 0.0
var _player: Node2D = null
var _expires_at_ms: int = 0


func _init() -> void:
	collision_layer = 0
	collision_mask = 1


func _ready() -> void:
	add_to_group(GROUP_ALLIES)
	add_to_group(GROUP_RAT_ALLIES)
	_retarget_left = randf() * RETARGET_INTERVAL
	_slot = (1.0 if get_instance_id() % 2 == 0 else -1.0) * randf_range(50.0, 220.0)

	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = BODY_SIZE * BODY_SCALE
	shape_node.shape = rect
	shape_node.position = Vector2(0.0, -rect.size.y * 0.5)
	add_child(shape_node)

	_visuals = Node2D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	var art: Node2D = EnemyArtScript.attach(self, "rat")
	art.scale = Vector2(BODY_SCALE, BODY_SCALE)
	art.modulate = TINT


## Tiempo de vida que dicta la Flauta de Hamelin: al vencer, la rata desaparece. Llamarla de nuevo renueva el plazo
## (el canto de la flauta): los temporizadores viejos ven que el plazo cambió y no hacen nada.
func set_lifetime(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_expires_at_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
	get_tree().create_timer(seconds).timeout.connect(_on_lifetime_expired)


func _on_lifetime_expired() -> void:
	if Time.get_ticks_msec() + 50 < _expires_at_ms:
		return
	if is_inside_tree() and not is_queued_for_deletion():
		queue_free()


func _physics_process(delta: float) -> void:
	if global_position.y > OFFMAP_Y:
		_return_to_player()
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	contact_cooldown = maxf(0.0, contact_cooldown - delta)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D

	_retarget_left -= delta
	if _retarget_left <= 0.0:
		_retarget_left = RETARGET_INTERVAL
		_target = _find_target()

	var dir: float = 0.0
	if _target != null and is_instance_valid(_target) and _target.visible:
		var dx: float = _target.global_position.x - global_position.x
		if absf(dx) > BITE_RANGE * 0.6:
			dir = signf(dx)
		_face(signf(dx))
		if absf(dx) <= BITE_RANGE and absf(_target.global_position.y - global_position.y) <= TARGET_MAX_DY and contact_cooldown <= 0.0:
			_bite(_target)
	elif _player != null and is_instance_valid(_player):
		var goal: float = _player.global_position.x + _slot
		var gx: float = goal - global_position.x
		if absf(gx) > 24.0:
			dir = signf(gx)
		if absf(_player.global_position.x - global_position.x) > LEASH_DISTANCE:
			_return_to_player()
			return
		_face(signf(_player.global_position.x - global_position.x))

	velocity.x = move_toward(velocity.x, dir * SPEED, 1400.0 * delta)
	if dir != 0.0 and is_on_floor() and is_on_wall():
		velocity.y = -JUMP_SPEED
	move_and_slide()


## Enemigo vivo más cercano a la vista del grupo (no se cuenta a sí misma ni a los que ya se fueron).
func _find_target() -> Node2D:
	var best: Node2D = null
	var best_dist: float = TARGET_RADIUS
	for node: Node in get_tree().get_nodes_in_group(GROUP_ENEMIES):
		var enemy: Node2D = node as Node2D
		if enemy == null or not enemy.visible or enemy.is_queued_for_deletion():
			continue
		if absf(enemy.global_position.y - global_position.y) > TARGET_MAX_DY * 2.0:
			continue
		var dist: float = absf(enemy.global_position.x - global_position.x)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _bite(enemy: Node2D) -> void:
	contact_cooldown = BITE_COOLDOWN
	if not enemy.has_method("take_hit"):
		return
	var away: Vector2 = Vector2(signf(enemy.global_position.x - global_position.x), 0.0)
	enemy.call("take_hit", HitPayload.new(BITE_DAMAGE, BITE_KNOCKBACK, away, self))
	velocity.x = away.x * 90.0


func _face(side: float) -> void:
	if _visuals != null and side != 0.0:
		_visuals.scale.x = side


func _return_to_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	global_position = _player.global_position + Vector2(-30.0 * signf(_slot), -40.0)
	velocity = Vector2.ZERO
