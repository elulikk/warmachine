class_name LootDrop
extends CharacterBody2D
## Recompensa física arrojada por enemigos con efecto de dispersión piñata, rebote
## sobre el suelo, atracción magnética hacia el Jugador y recolección de recursos.
## El botín quieto se funde de a 10 del mismo tipo en uno más grande que vale la suma (`core/loot/loot_combiner.gd`):
## `merge_tier` 0-3. Las monedas además cambian de tono (moneda, grande, platino, gema de tesoro).
## Quietas en el piso no calculan física (solo revisan cada tanto si siguen apoyadas) y la recolección es por
## distancia: el `PickupArea` queda apagado porque su máscara (capa 2) también detectaba a los enemigos.

const ArtScript = preload("res://core/art/art.gd")
const LootCombinerScript = preload("res://core/loot/loot_combiner.gd")

const LOOT_GROUP: StringName = &"loot_drops"
const MAX_TIER: int = 3
## Tamaño y tinte por nivel de fusión: moneda, moneda grande, moneda de platino, gema de tesoro.
const TIER_SCALE: Array[float] = [1.0, 1.4, 1.75, 2.1]
const TIER_TINT: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.25, 1.12, 0.8, 1.0),
	Color(0.85, 1.05, 1.4, 1.0),
	Color(1.45, 0.55, 0.85, 1.0),
]
const SPRITE_BASE_SCALE: float = 0.5
## Por debajo de esta velocidad horizontal, apoyada en el piso, la moneda se duerme.
const REST_SPEED: float = 20.0
const SUPPORT_CHECK_INTERVAL: float = 0.5

@export var item_type: String = "COIN" # "COIN", "AMMO", "HEALTH"
@export var amount: int = 1
@export var gravity: float = 750.0
@export var magnet_range: float = 180.0
@export var magnet_max_speed: float = 650.0

@onready var visual_rect: ColorRect = get_node_or_null("Visuals/ColorRect") as ColorRect
@onready var inner_rect: ColorRect = get_node_or_null("Visuals/InnerRect") as ColorRect
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("Visuals/AnimatedSprite2D") as AnimatedSprite2D
@onready var pickup_area: Area2D = get_node_or_null("PickupArea") as Area2D

var target_player: Player = null
var is_magnetized: bool = false
var magnet_speed: float = 0.0
var merge_tier: int = 0
var _collected: bool = false
var _resting: bool = false
var _support_timer: float = 0.0

## Racha de monedas juntadas seguidas: cada una suena un semitono más agudo (hasta una sexta mayor).
static var _coin_combo: int = 0
static var _last_coin_msec: int = -10000
## SpriteFrames compartidos por tipo de botín (antes se armaba uno por moneda).
static var _frames_cache: Dictionary = {}


func _ready() -> void:
	_apply_art_frames()
	# Impulso físico aleatorio de eyección si no fue configurado previamente (Efecto Piñata)
	if velocity == Vector2.ZERO:
		velocity.x = randf_range(-120.0, 120.0)
		velocity.y = randf_range(-340.0, -220.0)

	# La recolección es por distancia (ver _physics_process); el área solo sumaba pares de colisión con enemigos
	if pickup_area != null:
		pickup_area.set_deferred("monitoring", false)
	_support_timer = randf() * SUPPORT_CHECK_INTERVAL

	target_player = get_tree().get_first_node_in_group(&"player") as Player
	_refresh_group()
	_update_visuals()


## Inicializa el tipo de botín y la cantidad contenida.
func setup(p_type: String, p_amount: int = 1) -> void:
	item_type = p_type
	amount = p_amount
	# Impulso de eyección piñata: dispersión en abanico
	velocity.x = randf_range(-130.0, 130.0)
	velocity.y = randf_range(-350.0, -210.0)
	_resting = false
	_apply_art_frames()
	_refresh_group()
	_update_visuals()


## Multiplica la cantidad si se trata de monedas y existe un mutador activo de zona.
func apply_coin_drop_multiplier() -> void:
	if item_type.to_upper() == "COIN":
		var mult: float = ZoneModifierManager.get_world_mult("coin_drop_mult", 1.0)
		if mult > 1.0:
			amount = maxi(1, int(roundf(float(amount) * mult)))


## El grupo lo recorre LootCombiner.
func _refresh_group() -> void:
	if not is_inside_tree() or _collected:
		return
	add_to_group(LOOT_GROUP)
	LootCombinerScript.ensure(self)


## Cambia el sprite 16x16 por el arte de monedas, engranajes y frascos (assets/art/props).
func _apply_art_frames() -> void:
	if anim_sprite == null:
		return
	var kind: String = item_type.to_upper()
	if _frames_cache.has(kind):
		_set_frames(_frames_cache[kind] as SpriteFrames)
		return
	var files: Array[String] = []
	match kind:
		"AMMO":
			files = ["ammo_gear.png"]
		"HEALTH":
			files = ["health_drop.png"]
		_:
			files = ["coin_0.png", "coin_1.png", "coin_2.png", "coin_3.png", "coin_4.png", "coin_5.png"]
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"spin")
	frames.set_animation_loop(&"spin", true)
	frames.set_animation_speed(&"spin", 10.0)
	for file: String in files:
		var texture: Texture2D = ArtScript.tex("res://assets/art/props/" + file)
		if texture == null:
			return
		frames.add_frame(&"spin", texture)
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	_frames_cache[kind] = frames
	_set_frames(frames)


func _set_frames(frames: SpriteFrames) -> void:
	anim_sprite.sprite_frames = frames
	anim_sprite.animation = &"spin"
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_apply_tier_scale()
	anim_sprite.play(&"spin")


## Escala del sprite según el nivel de fusión, apoyado sobre el borde inferior de la colisión (radio 4 px).
func _apply_tier_scale() -> void:
	if anim_sprite == null or anim_sprite.sprite_frames == null or not anim_sprite.sprite_frames.has_animation(&"spin"):
		return
	var sprite_scale: float = SPRITE_BASE_SCALE * TIER_SCALE[clampi(merge_tier, 0, MAX_TIER)]
	anim_sprite.scale = Vector2(sprite_scale, sprite_scale)
	var first_frame: Texture2D = anim_sprite.sprite_frames.get_frame_texture(&"spin", 0)
	if first_frame != null:
		var half_height: float = float(first_frame.get_height()) * 0.5 * sprite_scale
		anim_sprite.position.y = -(half_height - 4.0)


## Asigna colores temáticos distintivos según el tipo de botín.
func _update_visuals() -> void:
	if anim_sprite != null:
		match item_type.to_upper():
			"COIN":
				anim_sprite.modulate = TIER_TINT[clampi(merge_tier, 0, MAX_TIER)] # Dorado original; más grande y otro tono al fundirse
			"CRYSTAL":
				anim_sprite.modulate = Color(0.45, 1.2, 1.6, 1.0) # moneda teñida de cian: cristal de tiempo
			"AMMO":
				anim_sprite.modulate = Color(0.75, 0.92, 1.1, 1.0) # Engranaje con leve tinte frío (fundido: solo más grande)
			"HEALTH":
				anim_sprite.modulate = Color.WHITE # El frasco ya es rojo
			_:
				anim_sprite.modulate = Color.WHITE
		return

	if visual_rect == null:
		return

	match item_type.to_upper():
		"COIN":
			visual_rect.color = Color(1.0, 0.84, 0.1, 1.0) # Amarillo brillante
			if inner_rect != null:
				inner_rect.color = Color(1.0, 0.96, 0.55, 1.0)
		"AMMO":
			visual_rect.color = Color(0.22, 0.65, 1.0, 1.0) # Azul cian brillante
			if inner_rect != null:
				inner_rect.color = Color(0.7, 0.9, 1.0, 1.0)
		"HEALTH":
			visual_rect.color = Color(0.2, 0.85, 0.35, 1.0) # Verde esmeralda
			if inner_rect != null:
				inner_rect.color = Color(0.7, 1.0, 0.75, 1.0)
		_:
			visual_rect.color = Color(0.9, 0.9, 0.9, 1.0)


func _physics_process(delta: float) -> void:
	if _collected:
		return

	# 1. Chequeo de succión magnética
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group(&"player") as Player

	if target_player != null and is_instance_valid(target_player):
		var target_center: Vector2 = target_player.global_position + Vector2(0, -32.0)
		var dist: float = global_position.distance_to(target_center)
		if dist <= magnet_range or is_magnetized:
			is_magnetized = true
			_resting = false
			var dir: Vector2 = (target_center - global_position).normalized()
			magnet_speed = move_toward(magnet_speed, magnet_max_speed, 1200.0 * delta)
			velocity = dir * magnet_speed
			move_and_slide()

			if dist < 42.0:
				_collect(target_player)
			return

	# 2. Quieta en el piso: sin física; cada tanto revisa si sigue apoyada (plataformas que se mueven)
	if _resting:
		_support_timer -= delta
		if _support_timer <= 0.0:
			_support_timer = SUPPORT_CHECK_INTERVAL
			if not test_move(global_transform, Vector2(0.0, 2.0)):
				_resting = false
		return

	# 3. Física normal balística con gravedad y rebote en el suelo
	velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, 160.0 * delta)

	var pre_vel_y: float = velocity.y
	move_and_slide()

	# Amortiguación y rebote piñata al tocar superficie sólida
	if is_on_floor() and pre_vel_y > 45.0:
		velocity.y = -pre_vel_y * 0.42
		velocity.x *= 0.65
	elif is_on_floor() and absf(velocity.x) < REST_SPEED:
		velocity = Vector2.ZERO
		_resting = true


# ==============================================================================
# Fusión (la llama LootCombiner)
# ==============================================================================

func can_merge() -> bool:
	return _resting and not _collected and not is_magnetized


## Solo se funden entre sí los del mismo tipo.
func merge_kind() -> String:
	return item_type.to_upper()


func merge_value() -> float:
	return float(amount)


## Pasa al nivel siguiente con el valor sumado de las monedas fundidas.
func upgrade_merge(new_tier: int, total_value: float) -> void:
	merge_tier = mini(new_tier, MAX_TIER)
	amount = maxi(1, int(roundf(total_value)))
	_apply_tier_scale()
	_update_visuals()
	var visuals: Node2D = get_node_or_null("Visuals") as Node2D
	if visuals != null:
		visuals.scale = Vector2(1.5, 1.5)
		create_tween().tween_property(visuals, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)


## Vuela hacia la moneda que la absorbe y desaparece (su valor ya se sumó allá).
func absorb_into(target_pos: Vector2) -> void:
	_collected = true
	remove_from_group(LOOT_GROUP)
	set_physics_process(false)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.4, 0.4), 0.16)
	tween.chain().tween_callback(queue_free)


## Procesa la entrega del recurso al Jugador.
func _collect(player: Player) -> void:
	if _collected:
		return
	_collected = true
	if is_in_group(LOOT_GROUP):
		remove_from_group(LOOT_GROUP)

	match item_type.to_upper():
		"COIN":
			if player.stats_manager != null:
				player.stats_manager.add_coins(amount)
			var now_msec: int = Time.get_ticks_msec()
			_coin_combo = mini(_coin_combo + 1, 9) if now_msec - _last_coin_msec < 420 else 0
			_last_coin_msec = now_msec
			# Las fundidas suenan más graves (más pesadas)
			GameFeel.sfx(self, &"coin", Vector2.INF, -1.0, pow(2.0, float(_coin_combo - merge_tier * 4) / 12.0))
		"CRYSTAL":
			if player.stats_manager != null:
				player.stats_manager.add_crystals(amount)
			GameFeel.sfx(self, &"coin", Vector2.INF, -2.0, 1.5)
		"AMMO":
			if player.weapon_manager != null:
				player.weapon_manager.add_ammo(amount)
			GameFeel.sfx(self, &"pickup_ammo", Vector2.INF, -6.0)
		"HEALTH":
			if player.stats_manager != null:
				player.stats_manager.heal(float(amount) * 15.0)
				print("[LootDrop] +%.0f HP restaurados." % (float(amount) * 15.0))
				GameFeel.sfx(self, &"heal", Vector2.INF, -4.0)

	# Animación compacta de absorción y auto-destrucción
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.12).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)
