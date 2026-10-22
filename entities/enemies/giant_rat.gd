extends "res://entities/enemies/basic_runner.gd"
## Rata Gigante: jefe de las alcantarillas (1-03). Al morir deja la Flauta de Hamelin (`dropped_item`, ver la escena).
## Mecánicas:
##  - Embestida: a media distancia se agacha temblando y chilla (aviso), y sale disparada en línea recta hacia donde
##    estaba el jugador. Pega fuerte y empuja; se esquiva saltando por encima. Al terminar queda aturdida un momento
##    (ventana para pegarle).
##  - Llamado de la plaga: cada tanto chilla y salen crías (ratas comunes) a sus costados, con tope de vivas.
##  - Furia: bajo el 40 % de vida se pone roja, corre más, embiste más seguido y llama más crías.
## Va al grupo `boss` (música de jefe). Sin class_name a propósito: se carga por escena.

const MINION_SCENE: PackedScene = preload("res://entities/enemies/city_rat.tscn")

const BOSS_HEALTH: float = 1100.0
const BOSS_SPEED: float = 100.0
const BOSS_CONTACT_DAMAGE: float = 18.0
## Escala extra del arte sobre el 1.5x común de los mobs (la rata común mide ~45 px; esta ~135).
const ART_EXTRA_SCALE: float = 3.0
## Colisión del cuerpo y de la hurtbox (px, con los pies en el origen).
const BODY_SIZE: Vector2 = Vector2(120.0, 80.0)
const HURTBOX_SIZE: Vector2 = Vector2(150.0, 120.0)

const ENRAGE_FRACTION: float = 0.4
const ENRAGED_SPEED: float = 135.0

## Embestida: se dispara con el jugador entre MIN y MAX px en horizontal y a una altura parecida.
const CHARGE_MIN_RANGE: float = 180.0
const CHARGE_MAX_RANGE: float = 650.0
const CHARGE_MAX_DY: float = 120.0
const CHARGE_WINDUP: float = 0.75
const ENRAGED_CHARGE_WINDUP: float = 0.55
const CHARGE_SPEED: float = 560.0
const ENRAGED_CHARGE_SPEED: float = 660.0
const CHARGE_TIME: float = 1.0
const CHARGE_COOLDOWN: float = 4.0
const ENRAGED_CHARGE_COOLDOWN: float = 2.6
const CHARGE_DAMAGE: float = 26.0
const CHARGE_PUSH: float = 420.0
## Distancia (px) entre centros para que la embestida alcance al jugador.
const CHARGE_HIT_RADIUS: float = 80.0
const STUN_TIME: float = 0.9

## Llamado de la plaga.
const SUMMON_COOLDOWN: float = 11.0
const ENRAGED_SUMMON_COOLDOWN: float = 7.5
const SUMMON_COUNT: int = 3
const ENRAGED_SUMMON_COUNT: int = 4
const MAX_MINIONS: int = 7

enum Mode { CHASE, WINDUP, CHARGE, STUN }

var _mode: int = Mode.CHASE
var _mode_left: float = 0.0
var _charge_dir: float = 1.0
var _charge_hit: bool = false
var _charge_cooldown_left: float = 2.0
var _summon_cooldown_left: float = 6.0
var _enraged: bool = false
var _minions: Array[Node] = []
## BasicRunner no tiene `is_dead`: la barra del jefe y este script lo leen de acá.
var is_dead: bool = false


func _ready() -> void:
	super._ready()
	entity_name = "Rata Gigante"
	move_speed = BOSS_SPEED
	contact_damage = BOSS_CONTACT_DAMAGE
	aggro_range = 4000.0
	add_to_group(&"boss")
	if health_component != null:
		health_component.max_health = BOSS_HEALTH
		health_component.current_health = BOSS_HEALTH
		health_component.health_changed.connect(_on_boss_health_changed)
	var art: Node2D = get_node_or_null("Visuals/EnemyArt") as Node2D
	if art != null:
		art.scale *= ART_EXTRA_SCALE
	_resize("CollisionShape2D", BODY_SIZE)
	_resize("Hurtbox/CollisionShape2D", HURTBOX_SIZE)
	if overhead_bar != null:
		overhead_bar.set("vertical_offset_y", -150.0)
		if overhead_bar.has_method("setup") and health_component != null:
			overhead_bar.call("setup", health_component, EnemyLevelScript.display_name(self))
	var display: Node2D = get_node_or_null("StatusDisplayComponent") as Node2D
	if display != null:
		display.position.y = -130.0
	GameFeel.sfx(self, &"rat_screech", global_position, 0.0, 0.8)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	match _mode:
		Mode.WINDUP:
			_tick_windup(delta)
			return
		Mode.CHARGE:
			_tick_charge(delta)
			return
		Mode.STUN:
			_mode_left -= delta
			_brake(delta, 1400.0)
			if _mode_left <= 0.0:
				_set_mode(Mode.CHASE)
			return
	super._physics_process(delta)
	if not is_aggroed or target_player == null or not is_instance_valid(target_player):
		return
	_charge_cooldown_left = maxf(0.0, _charge_cooldown_left - delta)
	_summon_cooldown_left = maxf(0.0, _summon_cooldown_left - delta)
	if _summon_cooldown_left <= 0.0:
		_summon_cooldown_left = ENRAGED_SUMMON_COOLDOWN if _enraged else SUMMON_COOLDOWN
		_call_the_plague()
	elif _charge_cooldown_left <= 0.0 and is_on_floor() and _player_in_charge_range():
		_start_windup()


func _player_in_charge_range() -> bool:
	if _melee != null and _melee.call("is_busy"):
		return false
	var dx: float = absf(target_player.global_position.x - global_position.x)
	var dy: float = absf(target_player.global_position.y - global_position.y)
	return dx >= CHARGE_MIN_RANGE and dx <= CHARGE_MAX_RANGE and dy <= CHARGE_MAX_DY


func _start_windup() -> void:
	_charge_dir = signf(target_player.global_position.x - global_position.x)
	if _charge_dir == 0.0:
		_charge_dir = 1.0
	if visuals != null:
		visuals.scale.x = _charge_dir
	_set_mode(Mode.WINDUP)
	_mode_left = ENRAGED_CHARGE_WINDUP if _enraged else CHARGE_WINDUP
	GameFeel.sfx(self, &"rat_screech", global_position, 0.0, 0.65)


func _tick_windup(delta: float) -> void:
	_mode_left -= delta
	_brake(delta, 1400.0)
	# Aviso: tiembla y se agacha, cada vez más
	if visuals != null:
		visuals.position = Vector2(randf_range(-3.0, 3.0), 4.0)
	if _mode_left <= 0.0:
		_set_mode(Mode.CHARGE)
		_mode_left = CHARGE_TIME
		_charge_hit = false
		GameFeel.shake(self, 3.0, 0.15)


func _tick_charge(delta: float) -> void:
	_mode_left -= delta
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = _charge_dir * (ENRAGED_CHARGE_SPEED if _enraged else CHARGE_SPEED)
	move_and_slide()
	if not _charge_hit and target_player != null and is_instance_valid(target_player):
		var to_player: Vector2 = target_player.global_position - global_position
		# Saltando por encima se esquiva: hace falta estar a la altura del lomo
		if absf(to_player.x) <= CHARGE_HIT_RADIUS and to_player.y > -BODY_SIZE.y - 20.0 and to_player.y < 40.0:
			_charge_hit = true
			target_player.take_damage(CHARGE_DAMAGE)
			target_player.velocity += Vector2(_charge_dir * CHARGE_PUSH, -260.0)
			GameFeel.shake(self, 5.0, 0.2)
	# Contra una pared o al terminar: se frena y queda aturdida
	if is_on_wall() or _mode_left <= 0.0:
		if is_on_wall():
			GameFeel.shake(self, 6.0, 0.25)
			GameFeel.sfx(self, &"boom_frag", global_position, -6.0, 0.6)
		_set_mode(Mode.STUN)
		_mode_left = STUN_TIME
		_charge_cooldown_left = ENRAGED_CHARGE_COOLDOWN if _enraged else CHARGE_COOLDOWN


func _brake(delta: float, decel: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, decel * delta)
	move_and_slide()


func _set_mode(mode: int) -> void:
	_mode = mode
	# El golpe de melé común no corre mientras arma o hace la embestida
	if _melee != null:
		_melee.set_physics_process(mode == Mode.CHASE)
	if visuals != null and mode != Mode.WINDUP:
		visuals.position = Vector2.ZERO


## Chilla y salen crías a sus costados (con tope de vivas).
func _call_the_plague() -> void:
	_minions = _minions.filter(func(m: Node) -> bool: return is_instance_valid(m) and _alive(m))
	var count: int = mini(ENRAGED_SUMMON_COUNT if _enraged else SUMMON_COUNT, MAX_MINIONS - _minions.size())
	if count <= 0:
		return
	GameFeel.sfx(self, &"rat_screech", global_position, 2.0, 1.1)
	GameFeel.shake(self, 2.5, 0.2)
	_spawn_minions.call_deferred(count)


func _alive(node: Node) -> bool:
	var hc: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
	return hc == null or hc.current_health > 0.0


func _spawn_minions(count: int) -> void:
	var host: Node = get_parent()
	if host == null or is_dead:
		return
	for i: int in count:
		var minion: CharacterBody2D = MINION_SCENE.instantiate() as CharacterBody2D
		var side: float = -1.0 if i % 2 == 0 else 1.0
		host.add_child(minion)
		minion.global_position = global_position + Vector2(side * (70.0 + 30.0 * float(i)), -20.0)
		minion.velocity = Vector2(side * 260.0, -320.0)
		minion.set("is_aggroed", true)
		_minions.append(minion)


func _on_boss_health_changed(current: float, maximum: float) -> void:
	if _enraged or maximum <= 0.0 or is_dead:
		return
	if current / maximum <= ENRAGE_FRACTION:
		_enraged = true
		move_speed = ENRAGED_SPEED
		if visuals != null:
			visuals.modulate = Color(1.0, 0.6, 0.55, 1.0)
		GameFeel.shake(self, 7.0, 0.4)
		_summon_cooldown_left = 0.5


## Al caer el jefe, las crías caen con él para que la arena quede despejada.
func _on_died() -> void:
	is_dead = true
	for minion: Node in _minions:
		if not is_instance_valid(minion):
			continue
		# Justo la vida que les queda: un daño enorme inflaría los efectos de sangre
		var hc: HealthComponent = minion.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and hc.current_health > 0.0:
			hc.call_deferred("apply_damage", hc.current_health + 1.0, false, "PHYSICAL")
	super._on_died()


## Pone el rectángulo de colisión en `size` apoyado en los pies (la forma ya es propia: la duplicó MobScale).
func _resize(path: String, size: Vector2) -> void:
	var node: CollisionShape2D = get_node_or_null(path) as CollisionShape2D
	if node == null:
		return
	var rect: RectangleShape2D = (node.shape.duplicate() as RectangleShape2D) if node.shape is RectangleShape2D else RectangleShape2D.new()
	rect.size = size
	node.shape = rect
	node.position = Vector2(0.0, -size.y * 0.5)
