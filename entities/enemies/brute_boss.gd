extends "res://entities/enemies/armored_brute.gd"
## Coloso del Núcleo: jefe del Sector 10 (primer jefe del juego).
## Un Bruto Acorazado más grande, con más vida y una onda de choque en el suelo que se esquiva saltando.
## Al bajar de la mitad de vida se enfurece: más rápido, más golpe, onda más seguida y llama refuerzos.
## Va al grupo `boss` (música de jefe). Sin class_name a propósito: se carga por preload / escena.

const ShockwaveFxScript = preload("res://entities/enemies/boss_shockwave_fx.gd")
const MINION_SCENE: PackedScene = preload("res://entities/enemies/basic_runner.tscn")

const BOSS_HEALTH: float = 1200.0
const BOSS_ARMOR: float = 40.0
const BOSS_SPEED: float = 52.0
const BOSS_CONTACT_DAMAGE: float = 28.0
const BOSS_EXP: float = 150.0
## Escala extra del arte sobre el 1.5x común de los mobs (la colisión no cambia).
const ART_EXTRA_SCALE: float = 1.35

const ENRAGE_FRACTION: float = 0.5
const ENRAGED_SPEED: float = 80.0
const ENRAGED_CONTACT_DAMAGE: float = 36.0
const MINIONS_ON_ENRAGE: int = 4

## Onda de choque: se avisa en el suelo, y si el jugador sigue en el piso dentro del ancho recibe el golpe.
const SLAM_TRIGGER_RANGE: float = 320.0
const SLAM_WINDUP: float = 0.8
const SLAM_COOLDOWN: float = 4.5
const ENRAGED_SLAM_COOLDOWN: float = 3.0
const SLAM_HALF_WIDTH: float = 240.0
const SLAM_DAMAGE: float = 30.0
const SLAM_PUSH: float = 320.0

var _enraged: bool = false
var _slam_cooldown_left: float = 2.5
var _windup_left: float = 0.0
var _minions: Array[Node] = []


func _ready() -> void:
	super._ready()
	entity_name = "Coloso del Núcleo"
	max_health = BOSS_HEALTH
	current_health = BOSS_HEALTH
	move_speed = BOSS_SPEED
	exp_reward = BOSS_EXP
	contact_damage = BOSS_CONTACT_DAMAGE
	aggro_range = 4000.0
	add_to_group(&"boss")
	if health_component != null:
		health_component.max_health = BOSS_HEALTH
		health_component.current_health = BOSS_HEALTH
		health_component.armor = BOSS_ARMOR
		health_component.health_changed.connect(_on_boss_health_changed)
	var art: Node2D = get_node_or_null("Visuals/EnemyArt") as Node2D
	if art != null:
		art.scale *= ART_EXTRA_SCALE
	if overhead_bar != null:
		overhead_bar.set("vertical_offset_y", -150.0)
		if overhead_bar.has_method("setup") and health_component != null:
			overhead_bar.call("setup", health_component, entity_name)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _windup_left > 0.0:
		_windup_left -= delta
		# Quieto y en guardia mientras avisa la onda
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		if _windup_left <= 0.0:
			_slam_impact()
		return
	super._physics_process(delta)
	_slam_cooldown_left = maxf(0.0, _slam_cooldown_left - delta)
	if _slam_cooldown_left <= 0.0 and is_on_floor() and _player_in_slam_range():
		_start_slam()


func _player_in_slam_range() -> bool:
	if target_player == null or not is_instance_valid(target_player):
		return false
	return absf(target_player.global_position.x - global_position.x) <= SLAM_TRIGGER_RANGE


func _start_slam() -> void:
	_windup_left = SLAM_WINDUP
	_slam_cooldown_left = ENRAGED_SLAM_COOLDOWN if _enraged else SLAM_COOLDOWN
	_spawn_fx(SLAM_WINDUP, false)
	GameFeel.sfx(self, &"barrier_close", global_position, -2.0, 0.6)


func _slam_impact() -> void:
	_spawn_fx(0.35, true)
	GameFeel.sfx(self, &"boom_frag", global_position, 0.0, 0.55)
	GameFeel.shake(self, 6.0, 0.25)
	if target_player == null or not is_instance_valid(target_player):
		return
	var dx: float = target_player.global_position.x - global_position.x
	# Saltando se esquiva: solo golpea a quien sigue pisando el suelo
	if target_player.is_on_floor() and absf(dx) <= SLAM_HALF_WIDTH:
		target_player.take_damage(SLAM_DAMAGE)
		var side: float = signf(dx) if absf(dx) > 4.0 else 1.0
		target_player.velocity += Vector2(side * SLAM_PUSH, -220.0)


func _spawn_fx(duration: float, burst: bool) -> void:
	var host: Node = get_tree().current_scene
	if host == null:
		return
	var fx: Node2D = ShockwaveFxScript.new() as Node2D
	fx.set("half_width", SLAM_HALF_WIDTH)
	fx.set("duration", duration)
	fx.set("burst", burst)
	host.add_child(fx)
	fx.global_position = global_position


func _on_boss_health_changed(current: float, maximum: float) -> void:
	if _enraged or maximum <= 0.0 or is_dead:
		return
	if current / maximum <= ENRAGE_FRACTION:
		_enrage()


func _enrage() -> void:
	_enraged = true
	move_speed = ENRAGED_SPEED
	contact_damage = ENRAGED_CONTACT_DAMAGE
	var art: Node2D = get_node_or_null("Visuals/EnemyArt") as Node2D
	if art != null:
		art.modulate = Color(1.0, 0.55, 0.5, 1.0)
	GameFeel.shake(self, 8.0, 0.4)
	GameFeel.sfx(self, &"boom_fire", global_position, 0.0, 0.7)
	_summon_minions.call_deferred()


func _summon_minions() -> void:
	var host: Node = get_parent()
	if host == null or is_dead:
		return
	for i: int in MINIONS_ON_ENRAGE:
		var minion: Node2D = MINION_SCENE.instantiate() as Node2D
		var side: float = -1.0 if i % 2 == 0 else 1.0
		host.add_child(minion)
		minion.global_position = global_position + Vector2(side * (160.0 + 90.0 * floorf(i / 2.0)), 0.0)
		minion.set("is_aggroed", true)
		_minions.append(minion)


## Al caer el jefe, los refuerzos caen con él para que la arena quede despejada.
func die() -> void:
	if is_dead:
		return
	for minion: Node in _minions:
		if not is_instance_valid(minion):
			continue
		# Justo la vida que les queda: un daño enorme inflaría los efectos de sangre
		var hc: HealthComponent = minion.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null:
			hc.call_deferred("apply_damage", hc.current_health + 1.0, false, "PHYSICAL")
	super.die()
