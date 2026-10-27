extends "res://entities/enemies/armored_brute.gd"
## Guardia Antidisturbios de la torre del Sindicato: un patovica con escudo frontal que para las balas.
## De frente, los tiros pegan en el escudo (`ranged_block_mult` del daño, chispa y clanc) y los golpes de melé
## pasan a medias. Por la espalda o aturdido recibe todo. Cómo se pelea: saltarlo y pegarle por atrás,
## aturdirlo (Llave Stillson) o empujarlo con el Matafuegos.

const ShotFx = preload("res://combat/shot_fx.gd")
const SHIELD_TEX: Texture2D = preload("res://assets/art/world1/riot_shield.png")
## Distancia al atacante por debajo de la cual el golpe cuenta como melé (en px de mundo).
const MELEE_DISTANCE: float = 150.0

@export var ranged_block_mult: float = 0.1
@export var melee_block_mult: float = 0.5

var _shield: Sprite2D = null


func _ready() -> void:
	super._ready()
	if visuals != null:
		# El escudo cuelga de Visuals: se da vuelta con el guardia
		_shield = Sprite2D.new()
		_shield.name = "RiotShield"
		_shield.texture = SHIELD_TEX
		_shield.scale = Vector2.ONE / 3.0
		_shield.position = Vector2(13.0, -29.0)
		_shield.z_index = 1
		visuals.add_child(_shield)


func take_hit(payload: HitPayload) -> void:
	if is_dead or payload == null:
		return
	if not _blocks(payload):
		super.take_hit(payload)
		return
	var melee: bool = payload.source_node != null and is_instance_valid(payload.source_node) \
		and global_position.distance_to(payload.source_node.global_position) < MELEE_DISTANCE
	var blocked: HitPayload = payload.duplicate_payload()
	blocked.base_damage *= melee_block_mult if melee else ranged_block_mult
	blocked.knockback_force *= 0.5
	if not melee:
		# La bala rebota en el policarbonato: no prende fuego ni congela
		var none: Array[String] = []
		blocked.status_effects = none
	var face: float = _facing()
	var hit_pos: Vector2 = global_position + Vector2(face * 22.0, -40.0)
	ShotFx.wall_impact(self, hit_pos, Vector2(face, 0.0), ShotFx.WARM)
	GameFeel.sfx(self, &"hit_shield", hit_pos, -4.0, randf_range(0.9, 1.1))
	if _shield != null:
		var tween: Tween = _shield.create_tween()
		_shield.position.x = 9.0
		tween.tween_property(_shield, "position:x", 13.0, 0.12)
	super.take_hit(blocked)


func _facing() -> float:
	if visuals == null or visuals.scale.x == 0.0:
		return 1.0
	return signf(visuals.scale.x)


## El escudo para el golpe si el atacante está adelante y el golpe viene de frente, salvo que esté aturdido.
func _blocks(payload: HitPayload) -> bool:
	if status_receiver != null and status_receiver.is_stunned:
		return false
	var face: float = _facing()
	if payload.source_node != null and is_instance_valid(payload.source_node):
		if (payload.source_node.global_position.x - global_position.x) * face <= 0.0:
			return false
	return payload.knockback_direction.x * face <= 0.0
