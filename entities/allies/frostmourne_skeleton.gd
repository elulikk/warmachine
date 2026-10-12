extends AllyBase
## Esqueleto aliado invocado por la espada Frostmourne (ver frostmourne_summoner.gd).
## Nace contratado: sigue al jugador y ataca al enemigo más cercano que detecta.
## No tiene fin de duración: pelea hasta morir. Sus golpes salen con source_node = él mismo y se aplican
## directo al enemigo (sin hitbox), así que nunca lastiman al Player ni a otros aliados.
## Al invocarse se arma desde el suelo (hoja de spawn, 6 cuadros) y mientras tanto no se mueve ni recibe golpes.

const ArtScript = preload("res://core/art/art.gd")
const SPAWN_SHEET_PATH: String = "res://assets/art/skeleton/frostmoon_spawn_sheet.png"
const SPAWN_FRAMES: int = 6
const SPAWN_FPS: float = 9.0

enum SkeletonState { FOLLOW, COMBAT }

const SLASH_DAMAGE: float = 30.0
const SLASH_RATE: float = 1.2 ## Golpes por segundo.
const SLASH_REACH: float = 48.0 ## Distancia de golpe (píxeles).
const SLASH_KNOCKBACK: float = 120.0
const FOLLOW_STOP_DISTANCE: float = 60.0
const JUMP_VELOCITY: float = -380.0

## Hoja de 4 cuadros: 0 a 2 caminando, 3 golpeando.
const FRAME_ATTACK: int = 3
const WALK_FPS: float = 9.0
const ATTACK_SHOW_TIME: float = 0.18

var current_state: SkeletonState = SkeletonState.FOLLOW
var _slash_timer: float = 0.0
var _attack_show: float = 0.0
var _walk_t: float = 0.0
var _spawning: bool = false
var _spawn_t: float = 0.0
var _walk_texture: Texture2D = null
@onready var sprite: Sprite2D = get_node_or_null("Visuals/Sprite") as Sprite2D


func _ready() -> void:
	# Antes de super._ready: AllyBase activa la hurtbox según is_hired.
	is_hired = true
	super._ready()
	_start_spawn()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	if _spawning:
		_process_spawn(delta)
		move_and_slide()
		super._physics_process(delta)
		return
	if _slash_timer > 0.0:
		_slash_timer = maxf(0.0, _slash_timer - delta)

	match current_state:
		SkeletonState.FOLLOW:
			_process_follow_state(delta)
		SkeletonState.COMBAT:
			_process_combat_state(delta)

	move_and_slide()
	_animate(delta)
	# Rescate por Leash heredado de AllyBase.
	super._physics_process(delta)


func _animate(delta: float) -> void:
	if sprite == null:
		return
	_attack_show = maxf(0.0, _attack_show - delta)
	if _attack_show > 0.0:
		sprite.frame = FRAME_ATTACK
	elif is_on_floor() and absf(velocity.x) > 10.0:
		_walk_t += delta * WALK_FPS
		sprite.frame = int(_walk_t) % 3
	else:
		sprite.frame = 0


## Arranca la animación de armado: cambia a la hoja de 6 cuadros y bloquea movimiento y golpes.
func _start_spawn() -> void:
	var spawn_tex: Texture2D = ArtScript.tex(SPAWN_SHEET_PATH)
	if sprite == null or spawn_tex == null:
		return
	_walk_texture = sprite.texture
	sprite.texture = spawn_tex
	sprite.hframes = SPAWN_FRAMES
	sprite.frame = 0
	_spawning = true
	_spawn_t = 0.0


func _process_spawn(delta: float) -> void:
	velocity.x = 0.0
	_spawn_t += delta
	var step: int = int(_spawn_t * SPAWN_FPS)
	if step >= SPAWN_FRAMES:
		_end_spawn()
		return
	if sprite != null:
		sprite.frame = step


func _end_spawn() -> void:
	_spawning = false
	if sprite != null and _walk_texture != null:
		sprite.texture = _walk_texture
		sprite.hframes = 4
		sprite.frame = 0


## Mientras se arma no recibe golpes.
func take_hit(payload: HitPayload) -> void:
	if _spawning:
		return
	super.take_hit(payload)


func _process_follow_state(delta: float) -> void:
	if target_scanner != null and target_scanner.has_target():
		current_state = SkeletonState.COMBAT
		return

	var player: Player = get_player()
	if player == null or not is_instance_valid(player):
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		return

	var dx: float = player.global_position.x - global_position.x
	if absf(dx) > FOLLOW_STOP_DISTANCE:
		var dir: float = signf(dx)
		velocity.x = dir * move_speed
		_face(dir)
		if is_on_floor():
			var player_higher: bool = (player.global_position.y < global_position.y - 28.0) and (absf(dx) < 130.0)
			if is_on_wall() or player_higher:
				velocity.y = JUMP_VELOCITY
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)


func _process_combat_state(delta: float) -> void:
	var target: Node2D = target_scanner.get_current_target() if target_scanner != null else null
	if target == null or not is_instance_valid(target):
		current_state = SkeletonState.FOLLOW
		return

	var target_pos: Vector2 = target.global_position + Vector2(0.0, -24.0)
	var dx: float = target_pos.x - global_position.x
	var dist: float = global_position.distance_to(target_pos)
	var dir: float = signf(dx) if absf(dx) > 4.0 else (visuals.scale.x if visuals != null else 1.0)
	_face(dir)

	if dist <= SLASH_REACH:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		if _slash_timer <= 0.0:
			_strike(target, dir)
			_slash_timer = 1.0 / SLASH_RATE
	else:
		velocity.x = dir * move_speed * 1.1
		if is_on_floor():
			var target_higher: bool = (target_pos.y < global_position.y - 22.0) and (absf(dx) < 100.0)
			if is_on_wall() or target_higher:
				velocity.y = JUMP_VELOCITY


## Golpe directo al enemigo. El receptor es el propio objetivo o su padre si el objetivo es un hijo (hurtbox).
func _strike(target: Node2D, dir: float) -> void:
	var receiver: Node = target
	if not receiver.has_method("take_hit"):
		receiver = target.get_parent()
	if receiver == null or not receiver.has_method("take_hit"):
		return
	var aim: Vector2 = Vector2(dir, 0.0)
	var payload: HitPayload = HitPayload.new(SLASH_DAMAGE, SLASH_KNOCKBACK, aim, self, [])
	receiver.call("take_hit", payload)
	velocity.x = dir * 110.0
	_attack_show = ATTACK_SHOW_TIME


func _face(dir: float) -> void:
	if visuals != null and dir != 0.0:
		visuals.scale.x = dir
