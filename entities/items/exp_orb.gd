class_name ExpOrb
extends Area2D
## Orbe de experiencia soltado por enemigos al ser derrotados.
## Salta al aparecer, cae con gravedad hasta el piso (un rayo corto hacia abajo por cuadro mientras cae; quieto no
## consulta nada) y es atraído magnéticamente hacia el jugador, que lo junta por distancia.
## Los quietos se funden de a 3 en uno más brillante (`core/loot/loot_combiner.gd`): azul, verde, dorado, violeta.
## El área no monitorea: su máscara (capa 2) también detectaba a los enemigos y sumaba pares de colisión.

const ArtScript = preload("res://core/art/art.gd")
const LootCombinerScript = preload("res://core/loot/loot_combiner.gd")

const ORB_GROUP: StringName = &"exp_orbs"
const MAX_TIER: int = 3
const TIER_SCALE: Array[float] = [1.0, 1.35, 1.7, 2.0]
## El arte es cian: multiplicado por estos tonos da azul, verde brillante, dorado y violeta.
const TIER_TINT: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(0.55, 1.6, 0.6, 1.0),
	Color(1.7, 1.35, 0.45, 1.0),
	Color(1.45, 0.6, 1.75, 1.0),
]
const SPRITE_BASE_SCALE: float = 0.5
const GRAVITY: float = 620.0
const MAX_FALL_SPEED: float = 520.0
## Altura a la que queda flotando sobre el piso.
const HOVER_HEIGHT: float = 12.0
const SUPPORT_CHECK_INTERVAL: float = 0.5
const WORLD_MASK: int = 1
## Si cae más que esto sin encontrar piso (vacío), se queda quieto donde está en vez de caer para siempre.
const MAX_FALL_DISTANCE: float = 3000.0

@export var exp_amount: float = 15.0
@export var attract_distance: float = 240.0
@export var attract_speed: float = 400.0

var target_player: Player = null
var merge_tier: int = 0
var _collected: bool = false
var _resting: bool = false
var _attracted: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _support_timer: float = 0.0
var _spawn_y: float = 0.0
var _sprite: AnimatedSprite2D = null

static var _frames_cache: SpriteFrames = null


func _ready() -> void:
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_apply_art_frames()
	set_deferred("monitoring", false)
	_velocity = Vector2(randf_range(-60.0, 60.0), randf_range(-220.0, -140.0))
	_support_timer = randf() * SUPPORT_CHECK_INTERVAL
	_spawn_y = global_position.y
	target_player = get_tree().get_first_node_in_group(&"player") as Player
	add_to_group(ORB_GROUP)
	LootCombinerScript.ensure(self)


## Orbe de luz cian que late (assets/art/props/exp_N.png), en lugar del sprite 16x16.
func _apply_art_frames() -> void:
	if _sprite == null:
		return
	if _frames_cache == null:
		var frames: SpriteFrames = SpriteFrames.new()
		frames.add_animation(&"pulse")
		frames.set_animation_loop(&"pulse", true)
		frames.set_animation_speed(&"pulse", 8.0)
		for i in range(4):
			var texture: Texture2D = ArtScript.tex("res://assets/art/props/exp_%d.png" % i)
			if texture == null:
				return
			frames.add_frame(&"pulse", texture)
		if frames.has_animation(&"default"):
			frames.remove_animation(&"default")
		_frames_cache = frames
	_sprite.sprite_frames = _frames_cache
	_sprite.animation = &"pulse"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_apply_tier_visual()
	_sprite.play(&"pulse")


func _apply_tier_visual() -> void:
	if _sprite == null:
		return
	var tier: int = clampi(merge_tier, 0, MAX_TIER)
	var sprite_scale: float = SPRITE_BASE_SCALE * TIER_SCALE[tier]
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_sprite.modulate = TIER_TINT[tier]


func _physics_process(delta: float) -> void:
	if _collected:
		return

	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group(&"player") as Player

	if target_player != null and is_instance_valid(target_player):
		var dist: float = global_position.distance_to(target_player.global_position)
		if dist <= attract_distance:
			# Desplazamiento magnético hacia el jugador
			_attracted = true
			_resting = false
			_velocity = Vector2.ZERO
			var dir: Vector2 = (target_player.global_position - global_position).normalized()
			global_position += dir * attract_speed * delta
			if dist <= 24.0:
				_give_exp(target_player)
			return
	_attracted = false

	if _resting:
		_support_timer -= delta
		if _support_timer <= 0.0:
			_support_timer = SUPPORT_CHECK_INTERVAL
			if _floor_hit(HOVER_HEIGHT + 6.0).is_empty():
				_resting = false
		return

	# Caída: solo mira hacia abajo lo que va a recorrer en este cuadro
	_velocity.y = minf(_velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	_velocity.x = move_toward(_velocity.x, 0.0, 120.0 * delta)
	global_position.x += _velocity.x * delta
	if _velocity.y > 0.0:
		var hit: Dictionary = _floor_hit(HOVER_HEIGHT + _velocity.y * delta)
		if not hit.is_empty():
			global_position.y = (hit["position"] as Vector2).y - HOVER_HEIGHT
			_velocity = Vector2.ZERO
			_resting = true
			return
	global_position.y += _velocity.y * delta
	if global_position.y - _spawn_y > MAX_FALL_DISTANCE:
		_velocity = Vector2.ZERO
		_resting = true


## Rayo hacia abajo contra el mundo (capa 1) desde el centro del orbe.
func _floor_hit(length: float) -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0.0, length), WORLD_MASK)
	query.collide_with_areas = false
	# Si aparece metido en un bloque, lo cuenta como piso (lo sube) en vez de atravesarlo
	query.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(query)


# ==============================================================================
# Fusión (la llama LootCombiner)
# ==============================================================================

func can_merge() -> bool:
	return _resting and not _collected and not _attracted


func merge_kind() -> String:
	return "EXP"


func merge_value() -> float:
	return exp_amount


## Pasa al nivel siguiente con la experiencia sumada de los orbes fundidos.
func upgrade_merge(new_tier: int, total_value: float) -> void:
	merge_tier = mini(new_tier, MAX_TIER)
	exp_amount = total_value
	_apply_tier_visual()
	if _sprite != null:
		var final_scale: Vector2 = _sprite.scale
		_sprite.scale = final_scale * 1.5
		create_tween().tween_property(_sprite, "scale", final_scale, 0.22).set_trans(Tween.TRANS_BACK)


## Vuela hacia el orbe que lo absorbe y desaparece (su experiencia ya se sumó allá).
func absorb_into(target_pos: Vector2) -> void:
	_collected = true
	remove_from_group(ORB_GROUP)
	set_physics_process(false)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.16)
	tween.chain().tween_callback(queue_free)


func _give_exp(player: Player) -> void:
	if _collected:
		return
	_collected = true
	remove_from_group(ORB_GROUP)
	if player != null and player.stats_manager != null:
		player.stats_manager.add_experience(exp_amount)
		player.flash_exp_pickup()
	# Los fundidos suenan más graves
	GameFeel.sfx(self, &"exp", Vector2.INF, -8.0, randf_range(0.9, 1.3) * pow(0.8, float(merge_tier)))
	queue_free()
