extends Node2D
## Fuego del jetpack: llama aditiva pegada a la boca, núcleo blanco, humo y chispas que quedan en el mundo,
## brillo que titila y una bocanada de humo al encender. Lo crea el jugador y lo cuelga de la boca de la
## mochila del esqueleto (`CharacterRig.jet_mount`), así sigue la inclinación y el giro del personaje.
## Sin class_name: se carga por preload.

const SettingsScript = preload("res://core/settings.gd")

## Llama principal (la que apagan los estados del jugador por `Player.jetpack_particles`).
var flame: CPUParticles2D = null
var _core: CPUParticles2D = null
var _smoke: CPUParticles2D = null
var _sparks: CPUParticles2D = null
var _puff: CPUParticles2D = null
var _glow: Sprite2D = null
var _active: bool = false
var _glow_amount: float = 0.0

static var _dot: Texture2D = null


func _ready() -> void:
	var density: float = SettingsScript.particle_scale()
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Humo: queda en el mundo, se abre y sube apenas. Se crea antes que la llama para quedar debajo.
	_smoke = _emitter("Smoke", maxi(4, roundi(28 * density)), 0.85, false)
	_smoke.position = Vector2(0.0, 6.0)
	_smoke.spread = 24.0
	_smoke.initial_velocity_min = 70.0
	_smoke.initial_velocity_max = 120.0
	_smoke.damping_min = 90.0
	_smoke.damping_max = 140.0
	_smoke.gravity = Vector2(0.0, -40.0)
	_smoke.scale_amount_min = 0.45
	_smoke.scale_amount_max = 0.7
	_smoke.scale_amount_curve = _curve(0.5, 1.0, 1.9)
	_smoke.color_ramp = _ramp([
		[0.0, Color(0.55, 0.42, 0.32, 0.0)],
		[0.12, Color(0.52, 0.48, 0.46, 0.5)],
		[0.6, Color(0.34, 0.34, 0.37, 0.3)],
		[1.0, Color(0.16, 0.16, 0.18, 0.0)],
	])

	# Llama: corta, pegada a la boca, se afina hacia la punta
	flame = _emitter("Flame", maxi(8, roundi(30 * density)), 0.16, true)
	flame.material = add
	flame.spread = 9.0
	flame.initial_velocity_min = 230.0
	flame.initial_velocity_max = 320.0
	flame.scale_amount_min = 0.38
	flame.scale_amount_max = 0.55
	flame.scale_amount_curve = _curve(1.0, 0.75, 0.15)
	flame.color_ramp = _ramp([
		[0.0, Color(1.0, 0.95, 0.75, 1.0)],
		[0.3, Color(1.0, 0.62, 0.15, 0.95)],
		[0.7, Color(0.95, 0.25, 0.05, 0.6)],
		[1.0, Color(0.5, 0.08, 0.02, 0.0)],
	])

	# Núcleo: chorro blanco azulado muy corto en la boca
	_core = _emitter("Core", maxi(4, roundi(12 * density)), 0.07, true)
	_core.material = add
	_core.spread = 4.0
	_core.initial_velocity_min = 140.0
	_core.initial_velocity_max = 180.0
	_core.scale_amount_min = 0.22
	_core.scale_amount_max = 0.3
	_core.color_ramp = _ramp([
		[0.0, Color(1.0, 1.0, 1.0, 1.0)],
		[1.0, Color(0.6, 0.85, 1.0, 0.0)],
	])

	# Chispas: pocas, rápidas, caen con gravedad y quedan atrás
	_sparks = _emitter("Sparks", maxi(2, roundi(9 * density)), 0.4, false)
	_sparks.material = add
	_sparks.spread = 30.0
	_sparks.initial_velocity_min = 150.0
	_sparks.initial_velocity_max = 260.0
	_sparks.gravity = Vector2(0.0, 420.0)
	_sparks.scale_amount_min = 0.08
	_sparks.scale_amount_max = 0.14
	_sparks.color_ramp = _ramp([
		[0.0, Color(1.0, 0.95, 0.6, 1.0)],
		[1.0, Color(1.0, 0.4, 0.05, 0.0)],
	])

	# Bocanada al encender: un golpe de humo que se abre hacia los costados
	_puff = _emitter("Puff", maxi(5, roundi(16 * density)), 0.55, false)
	_puff.one_shot = true
	_puff.explosiveness = 0.95
	_puff.spread = 75.0
	_puff.initial_velocity_min = 70.0
	_puff.initial_velocity_max = 170.0
	_puff.damping_min = 220.0
	_puff.damping_max = 300.0
	_puff.scale_amount_min = 0.5
	_puff.scale_amount_max = 0.8
	_puff.scale_amount_curve = _curve(0.6, 1.1, 1.5)
	_puff.color_ramp = _smoke.color_ramp

	# Brillo: halo cálido que titila alrededor de la boca
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = _dot_texture()
	_glow.material = add
	_glow.position = Vector2(0.0, 8.0)
	_glow.modulate = Color(1.0, 0.55, 0.2, 0.0)
	add_child(_glow)


## Enciende o apaga todo el fuego. Al encender suelta la bocanada de humo.
func set_active(value: bool) -> void:
	if value and not _active:
		_puff.restart()
		_puff.emitting = true
	_active = value
	for emitter: CPUParticles2D in [flame, _core, _smoke, _sparks]:
		if emitter.emitting != value:
			emitter.emitting = value


func _process(delta: float) -> void:
	_glow_amount = move_toward(_glow_amount, 1.0 if _active else 0.0, delta * (10.0 if _active else 6.0))
	_glow.visible = _glow_amount > 0.01
	if _glow.visible:
		var flicker: float = randf_range(0.8, 1.15)
		_glow.scale = Vector2(1.5, 1.9) * flicker
		_glow.modulate.a = 0.55 * _glow_amount * flicker


func _emitter(emitter_name: String, amount: int, life: float, local: bool) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.name = emitter_name
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.local_coords = local
	p.texture = _dot_texture()
	p.direction = Vector2.DOWN
	p.gravity = Vector2.ZERO
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0
	add_child(p)
	return p


static func _curve(a: float, b: float, c: float) -> Curve:
	var curve: Curve = Curve.new()
	curve.max_value = maxf(maxf(a, b), maxf(c, 1.0))
	curve.add_point(Vector2(0.0, a))
	curve.add_point(Vector2(0.5, b))
	curve.add_point(Vector2(1.0, c))
	return curve


static func _ramp(stops: Array) -> Gradient:
	var grad: Gradient = Gradient.new()
	var offsets: PackedFloat32Array = PackedFloat32Array()
	var colors: PackedColorArray = PackedColorArray()
	for stop: Array in stops:
		offsets.append(float(stop[0]))
		colors.append(stop[1] as Color)
	grad.offsets = offsets
	grad.colors = colors
	return grad


## Punto suave (blanco al centro, transparente al borde) de 32 px, compartido por todos los emisores.
static func _dot_texture() -> Texture2D:
	if _dot == null:
		var grad: Gradient = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = grad
		tex.width = 32
		tex.height = 32
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		_dot = tex
	return _dot
