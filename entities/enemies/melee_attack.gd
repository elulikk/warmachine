extends Node
## Ataque cuerpo a cuerpo de los enemigos de melé: tocar al jugador ya no lastima. Al acercarse a su alcance el enemigo
## se frena y arma el golpe (aviso: la animación de ataque corre entera) y recién al final pega, solo si el jugador sigue
## a su alcance. Se esquiva alejándose, saltando por encima o con el dash. Después descansa antes del siguiente.
## Lo crea `attach()` desde el `_ready` de cada anfitrión (BasicRunner, ArmoredBrute, ShieldedSentinel).
## Sin class_name a propósito: se carga por `preload`.

enum Phase { READY, WINDUP, RECOVER }

## Por `art_kind`: `windup` = segundos de aviso (el golpe cae al final), `rest` = descanso entre golpes,
## `extra` = alcance sumado al ancho del cuerpo de ambos (px).
const PROFILES: Dictionary = {
	"rat": {"windup": 0.20, "rest": 0.80, "extra": 14.0},
	"thief": {"windup": 0.28, "rest": 0.90, "extra": 20.0},
	"runner": {"windup": 0.28, "rest": 0.90, "extra": 20.0},
	"zombie": {"windup": 0.40, "rest": 1.10, "extra": 22.0},
	"ghost": {"windup": 0.30, "rest": 1.00, "extra": 20.0},
	"thug": {"windup": 0.50, "rest": 1.30, "extra": 26.0},
	"brute": {"windup": 0.55, "rest": 1.40, "extra": 28.0},
	"bouncer": {"windup": 0.55, "rest": 1.40, "extra": 28.0},
	"sentinel": {"windup": 0.42, "rest": 1.10, "extra": 24.0},
}
const DEFAULT_PROFILE: Dictionary = {"windup": 0.30, "rest": 1.00, "extra": 20.0}
## Mitad del ancho del jugador (px).
const PLAYER_HALF_WIDTH: float = 14.0
## Diferencia máxima de altura (pies contra pies) para alcanzar al jugador: saltando por encima se esquiva.
const MAX_DY: float = 64.0
## Margen extra de alcance en el momento del golpe (el que se aleja un poco todavía lo recibe).
const STRIKE_GRACE: float = 12.0
## Qué fracción del tiempo de animación de ataque es el aviso: el cuadro del golpe cae a ese punto (ver EnemyArt).
const STRIKE_POINT: float = 0.55

var phase: int = Phase.READY
var windup: float = 0.3
var rest: float = 1.0
var reach: float = -1.0   # se calcula en el primer cuadro: el anfitrión puede cambiar su colisión en su `_ready`

var _host: CharacterBody2D = null
var _timer: float = 0.0
var _facing: float = 1.0
var _art: Node = null
var _extra: float = 20.0


static func attach(host: CharacterBody2D, art_kind: String) -> Node:
	var existing: Node = host.get_node_or_null("MeleeAttack")
	if existing != null:
		return existing
	var node: Node = (load("res://entities/enemies/melee_attack.gd") as GDScript).new() as Node
	node.name = "MeleeAttack"
	host.add_child(node)
	node.call("setup", host, art_kind)
	return node


func setup(host: CharacterBody2D, art_kind: String) -> void:
	_host = host
	var profile: Dictionary = PROFILES.get(art_kind, DEFAULT_PROFILE) as Dictionary
	windup = float(profile["windup"])
	rest = float(profile["rest"])
	_extra = float(profile["extra"])
	_art = host.get_node_or_null("Visuals/EnemyArt")


## true mientras arma el golpe: el anfitrión se queda quieto.
func is_busy() -> bool:
	return phase == Phase.WINDUP


func _physics_process(delta: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	if _host.get("on_ceiling") == true or _host.get("is_dead") == true:
		return
	if reach < 0.0:
		reach = _body_half_width() + PLAYER_HALF_WIDTH + _extra
	var status: Object = _host.get("status_receiver") as Object
	var stunned: bool = status != null and status.get("is_stunned") == true
	var player: Player = _host.get("target_player") as Player
	_timer -= delta
	match phase:
		Phase.READY:
			if _timer <= 0.0 and not stunned and _host.get("is_aggroed") == true and _in_reach(player, 0.0):
				_begin(player)
		Phase.WINDUP:
			if stunned:
				_finish()
			elif _timer <= 0.0:
				_strike(player)
				_finish()
		Phase.RECOVER:
			if _timer <= 0.0:
				phase = Phase.READY


func _begin(player: Player) -> void:
	phase = Phase.WINDUP
	_timer = windup
	_facing = signf(player.global_position.x - _host.global_position.x)
	if _facing == 0.0:
		_facing = 1.0
	var visuals: Node2D = _host.get_node_or_null("Visuals") as Node2D
	if visuals != null:
		visuals.scale.x = _facing
	if _art != null and _art.has_method("play_attack_for"):
		_art.call("play_attack_for", windup / STRIKE_POINT)


func _strike(player: Player) -> void:
	if player == null or not is_instance_valid(player) or not _in_reach(player, STRIKE_GRACE):
		return
	if player.phase_timer > 0.0:
		return
	var dx: float = player.global_position.x - _host.global_position.x
	# Solo pega hacia donde apuntó el golpe (pasarle por detrás lo esquiva)
	if dx * _facing < -PLAYER_HALF_WIDTH:
		return
	player.take_contact_damage(float(_host.get("contact_damage")), _host)


func _finish() -> void:
	phase = Phase.RECOVER
	_timer = rest


func _in_reach(player: Player, grace: float) -> bool:
	if player == null or not is_instance_valid(player) or player.is_invisible:
		return false
	var dx: float = absf(player.global_position.x - _host.global_position.x)
	var dy: float = absf(player.global_position.y - _host.global_position.y)
	return dx <= reach + grace and dy <= MAX_DY


## Mitad del ancho de la colisión del anfitrión, con su escala (la Rata Gigante es enorme).
func _body_half_width() -> float:
	var node: CollisionShape2D = _host.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if node == null or node.shape == null:
		return 14.0
	var half: float = 14.0
	if node.shape is RectangleShape2D:
		half = (node.shape as RectangleShape2D).size.x * 0.5
	elif node.shape is CapsuleShape2D:
		half = (node.shape as CapsuleShape2D).radius
	elif node.shape is CircleShape2D:
		half = (node.shape as CircleShape2D).radius
	return half * absf(node.global_scale.x)
