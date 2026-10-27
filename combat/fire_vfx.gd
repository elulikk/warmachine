extends RefCounted
## Visuales del fuego con dos modos según el ajuste gráfico "fire_style":
##   0 = Sprites (por defecto, barato: AnimatedSprite2D con tiras de assets/art/fx)
##   1 = Partículas (CPUParticles2D, más vivo pero más caro)
## Tiras de 4 cuadros: fire_droplet, fire_pool (apoyado en el piso), fire_jet, fire_burn.

const SettingsScript = preload("res://core/settings.gd")
const FxShadersScript = preload("res://combat/fx_shaders.gd")
const STYLE_SPRITES: int = 0
const STYLE_PARTICLES: int = 1
const STYLE_SHADERS: int = 2

const FRAME_COUNT: int = 4
const STRIPS: Dictionary = {
	"droplet": {"file": "res://assets/art/fx/fire_droplet.png", "fps": 12.0, "loop": true},
	"pool": {"file": "res://assets/art/fx/fire_pool.png", "fps": 9.0, "loop": true},
	"jet": {"file": "res://assets/art/fx/fire_jet.png", "fps": 20.0, "loop": true},
	"burn": {"file": "res://assets/art/fx/fire_burn.png", "fps": 9.0, "loop": true},
}

static var _frames_cache: Dictionary = {}
static var _last_jet_msec: int = -1000

const JET_MIN_GAP_MSEC: int = 70


static func use_particles() -> bool:
	return SettingsScript.get_int("fire_style") == STYLE_PARTICLES


static func style() -> int:
	return SettingsScript.get_int("fire_style")


## Crea el visual del tipo pedido. `anchor_bottom` apoya la base del sprite en el origen
## (charcos y llamas de estado); si no, queda centrado. `target_width` reescala el cuadro.
static func make(kind: String, target_width: float = 0.0, anchor_bottom: bool = false) -> Node2D:
	match style():
		STYLE_PARTICLES:
			return _make_particles(kind, target_width, anchor_bottom)
		STYLE_SHADERS:
			return _make_shader(kind, target_width, anchor_bottom)
	return _make_sprite(kind, target_width, anchor_bottom)


static func _frames_for(kind: String) -> SpriteFrames:
	if _frames_cache.has(kind):
		return _frames_cache[kind]
	var info: Dictionary = STRIPS[kind]
	var tex: Texture2D = load(str(info["file"])) as Texture2D
	if tex == null:
		return null
	var frames: SpriteFrames = SpriteFrames.new()
	frames.set_animation_speed(&"default", float(info["fps"]))
	frames.set_animation_loop(&"default", bool(info["loop"]))
	var fw: int = tex.get_width() / FRAME_COUNT
	for i in range(FRAME_COUNT):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * fw, 0, fw, tex.get_height())
		frames.add_frame(&"default", atlas)
	_frames_cache[kind] = frames
	return frames


static func _make_sprite(kind: String, target_width: float, anchor_bottom: bool) -> Node2D:
	var frames: SpriteFrames = _frames_for(kind)
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	if frames == null:
		return sprite
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var first: Texture2D = frames.get_frame_texture(&"default", 0)
	var fw: float = first.get_width()
	var fh: float = first.get_height()
	if target_width > 0.0:
		var s: float = target_width / fw
		sprite.scale = Vector2(s, s)
		fh *= s
	if anchor_bottom:
		sprite.offset = Vector2(0.0, -first.get_height() * 0.5)
	sprite.frame = randi() % FRAME_COUNT
	sprite.play(&"default")
	# Desfasa la animación para que varios charcos no parpadeen al unísono.
	sprite.frame_progress = randf()
	return sprite


## Llama procedural: un cuadrado con shader (sin cuadros de animación ni partículas).
static func _make_shader(kind: String, target_width: float, anchor_bottom: bool) -> Node2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = FxShadersScript.white_texture()
	sprite.material = FxShadersScript.fire_material(kind)
	var width: float = target_width if target_width > 0.0 else 24.0
	var size: Vector2 = Vector2(width, width * 0.8)
	match kind:
		"pool":
			size = Vector2(width, width * 0.7)
		"droplet":
			size = Vector2(width * 0.6, width * 0.9)
		"jet":
			# Se dibuja vertical y se gira: la llama sale hacia +x desde el origen
			size = Vector2(width * 0.45, width)
			sprite.rotation = PI * 0.5
		"burn":
			size = Vector2(width, width * 1.3)
	sprite.scale = size / 4.0
	if anchor_bottom or kind == "jet":
		sprite.centered = false
		sprite.offset = Vector2(-2.0, -4.0)
	return sprite


static func _make_particles(kind: String, target_width: float, anchor_bottom: bool) -> Node2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	var density: float = SettingsScript.particle_scale()
	var width: float = target_width if target_width > 0.0 else 24.0
	p.emitting = true
	p.local_coords = false
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(width * 0.5, 2.0)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2(0.0, -60.0)
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 45.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.lifetime = 0.6
	p.amount = maxi(4, int(round(16.0 * density * clampf(width / 32.0, 0.5, 3.0))))
	var ramp: Gradient = Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.5, 1.0), Color(1.0, 0.5, 0.1, 0.9), Color(0.6, 0.1, 0.05, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = ramp
	match kind:
		"droplet":
			p.emission_rect_extents = Vector2(3.0, 3.0)
			p.direction = Vector2.LEFT
			p.spread = 20.0
			p.gravity = Vector2.ZERO
			p.lifetime = 0.3
			p.amount = maxi(4, int(round(10.0 * density)))
		"jet":
			p.direction = Vector2.RIGHT
			p.spread = 12.0
			p.gravity = Vector2(0.0, -20.0)
			p.initial_velocity_min = 80.0
			p.initial_velocity_max = 160.0
			p.lifetime = 0.35
			p.amount = maxi(6, int(round(24.0 * density)))
		"burn":
			p.amount = maxi(4, int(round(10.0 * density)))
	if anchor_bottom:
		p.position = Vector2.ZERO
	return p


## Chorro breve en la boca del arma. Se libera solo.
static func spawn_jet(parent: Node, pos: Vector2, dir: Vector2) -> void:
	if parent == null:
		return
	# A 14 disparos/s no hace falta un chorro por bala: con uno cada ~70 ms se ve continuo.
	var now: int = Time.get_ticks_msec()
	if now - _last_jet_msec < JET_MIN_GAP_MSEC:
		return
	_last_jet_msec = now
	var jet: Node2D = make("jet", 56.0)
	jet.global_position = pos
	jet.rotation = dir.angle()
	jet.z_index = 12
	parent.add_child(jet)
	if jet is AnimatedSprite2D and (jet as AnimatedSprite2D).sprite_frames != null:
		# El sprite del chorro nace en su borde izquierdo: se corre media longitud hacia adelante.
		var sprite: AnimatedSprite2D = jet as AnimatedSprite2D
		sprite.offset = Vector2(sprite.sprite_frames.get_frame_texture(&"default", 0).get_width() * 0.5, 0.0)
	var tw: Tween = jet.create_tween()
	tw.tween_interval(0.14)
	tw.tween_callback(jet.queue_free)
