class_name LootDrop
extends CharacterBody2D
## Recompensa física arrojada por enemigos con efecto de dispersión piñata, rebote
## sobre el suelo, atracción magnética hacia el Jugador y recolección de recursos.

const ArtScript = preload("res://core/art/art.gd")

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
var _collected: bool = false

## Racha de monedas juntadas seguidas: cada una suena un semitono más agudo (hasta una sexta mayor).
static var _coin_combo: int = 0
static var _last_coin_msec: int = -10000


func _ready() -> void:
	_apply_art_frames()
	# Impulso físico aleatorio de eyección si no fue configurado previamente (Efecto Piñata)
	if velocity == Vector2.ZERO:
		velocity.x = randf_range(-120.0, 120.0)
		velocity.y = randf_range(-340.0, -220.0)
	
	if pickup_area != null:
		pickup_area.body_entered.connect(_on_pickup_area_entered)
	
	target_player = get_tree().get_first_node_in_group(&"player") as Player
	_update_visuals()


## Inicializa el tipo de botín y la cantidad contenida.
func setup(p_type: String, p_amount: int = 1) -> void:
	item_type = p_type
	amount = p_amount
	# Impulso de eyección piñata: dispersión en abanico
	velocity.x = randf_range(-130.0, 130.0)
	velocity.y = randf_range(-350.0, -210.0)
	_update_visuals()


## Multiplica la cantidad si se trata de monedas y existe un mutador activo de zona.
func apply_coin_drop_multiplier() -> void:
	if item_type.to_upper() == "COIN":
		var mult: float = ZoneModifierManager.get_world_mult("coin_drop_mult", 1.0)
		if mult > 1.0:
			amount = maxi(1, int(roundf(float(amount) * mult)))


## Cambia el sprite 16x16 por el arte de monedas, engranajes y frascos (assets/art/props).
func _apply_art_frames() -> void:
	if anim_sprite == null:
		return
	var files: Array[String] = []
	match item_type.to_upper():
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
	anim_sprite.sprite_frames = frames
	anim_sprite.animation = &"spin"
	anim_sprite.scale = Vector2(0.5, 0.5)
	# El sprite se apoya sobre el borde inferior de la colisión (radio 4 px) en vez de hundirse en el suelo
	var first_frame: Texture2D = frames.get_frame_texture(&"spin", 0)
	if first_frame != null:
		var half_height: float = float(first_frame.get_height()) * 0.5 * anim_sprite.scale.y
		anim_sprite.position.y = -(half_height - 4.0)
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	anim_sprite.play(&"spin")


## Asigna colores temáticos distintivos según el tipo de botín.
func _update_visuals() -> void:
	if anim_sprite != null:
		match item_type.to_upper():
			"COIN":
				anim_sprite.modulate = Color.WHITE # Sprite dorado original
			"AMMO":
				anim_sprite.modulate = Color(0.75, 0.92, 1.1, 1.0) # Engranaje con leve tinte frío
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
			var dir: Vector2 = (target_center - global_position).normalized()
			magnet_speed = move_toward(magnet_speed, magnet_max_speed, 1200.0 * delta)
			velocity = dir * magnet_speed
			move_and_slide()
			
			if dist < 42.0 or (pickup_area != null and pickup_area.overlaps_body(target_player)):
				_collect(target_player)
			return
	
	# 2. Física normal balística con gravedad y rebote en el suelo
	velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, 160.0 * delta)
	
	var pre_vel_y: float = velocity.y
	move_and_slide()
	
	# Amortiguación y rebote piñata al tocar superficie sólida
	if is_on_floor() and pre_vel_y > 45.0:
		velocity.y = -pre_vel_y * 0.42
		velocity.x *= 0.65


func _on_pickup_area_entered(body: Node2D) -> void:
	if _collected:
		return
	if body is Player:
		_collect(body as Player)


## Procesa la entrega del recurso al Jugador.
func _collect(player: Player) -> void:
	if _collected:
		return
	_collected = true
	
	match item_type.to_upper():
		"COIN":
			if player.stats_manager != null:
				player.stats_manager.add_coins(amount)
			var now_msec: int = Time.get_ticks_msec()
			_coin_combo = mini(_coin_combo + 1, 9) if now_msec - _last_coin_msec < 420 else 0
			_last_coin_msec = now_msec
			GameFeel.sfx(self, &"coin", Vector2.INF, -1.0, pow(2.0, float(_coin_combo) / 12.0))
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
