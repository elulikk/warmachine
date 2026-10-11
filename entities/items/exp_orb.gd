class_name ExpOrb
extends Area2D
## Orbe de experiencia soltado por enemigos al ser derrotados.
## Es atraído magnéticamente hacia el jugador y le otorga experiencia al contacto.

const ArtScript = preload("res://core/art/art.gd")

@export var exp_amount: float = 20.0
@export var attract_distance: float = 240.0
@export var attract_speed: float = 400.0

var target_player: Player = null
var _collected: bool = false


func _ready() -> void:
	_apply_art_frames()
	body_entered.connect(_on_body_entered)
	target_player = get_tree().get_first_node_in_group(&"player") as Player


## Orbe de luz cian que late (assets/art/props/exp_N.png), en lugar del sprite 16x16.
func _apply_art_frames() -> void:
	var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
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
	sprite.sprite_frames = frames
	sprite.animation = &"pulse"
	sprite.scale = Vector2(0.5, 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.play(&"pulse")


func _physics_process(delta: float) -> void:
	if _collected:
		return
	
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group(&"player") as Player
	
	if target_player != null and is_instance_valid(target_player):
		var dist: float = global_position.distance_to(target_player.global_position)
		if dist <= attract_distance:
			# Desplazamiento magnético hacia el jugador
			var dir: Vector2 = (target_player.global_position - global_position).normalized()
			global_position += dir * attract_speed * delta
			if dist <= 24.0:
				_give_exp(target_player)


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	
	if body is Player:
		_give_exp(body as Player)


func _give_exp(player: Player) -> void:
	if _collected:
		return
	_collected = true
	if player != null and player.stats_manager != null:
		player.stats_manager.add_experience(exp_amount)
		print("[ExpOrb] Jugador recogió orbe de +%.0f EXP." % exp_amount)
	GameFeel.sfx(self, &"exp", Vector2.INF, -8.0, randf_range(0.9, 1.3))
	queue_free()
