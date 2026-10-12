extends Node2D
## Aura visual de subida de nivel (estilo columna de luz ascendente MU Online / WoW).
## Sin class_name a propósito: se carga por preload.
## Administra la columna de luz dorada, anillos de halo sagrado, resplandor en el suelo y partículas.

const SettingsScript = preload("res://core/settings.gd")
const BloodFxScript = preload("res://combat/blood_fx.gd")

const DURATION: float = 2.2
const RISE_DURATION: float = 0.28
const BEAM_HEIGHT: float = 140.0
const BEAM_WIDTH_BASE: float = 54.0
const BEAM_WIDTH_TOP: float = 40.0

## Subclase interna para dibujar capas específicas con su propio z_index y material aditivo.
class Drawer extends Node2D:
	var draw_callback: Callable

	func _draw() -> void:
		if draw_callback.is_valid():
			draw_callback.call(self)


var _time: float = 0.0
var _master_alpha: float = 1.0

var _back_drawer: Drawer = null
var _front_drawer: Drawer = null
var _particles: CPUParticles2D = null


func _ready() -> void:
	# 1. Capa trasera (z_index = -1): pilar de luz amplio y resplandor de suelo detrás del cuerpo
	_back_drawer = Drawer.new()
	_back_drawer.name = "BackDrawer"
	_back_drawer.draw_callback = _draw_back
	_back_drawer.z_index = -1
	_back_drawer.z_as_relative = true
	var mat_back: CanvasItemMaterial = CanvasItemMaterial.new()
	mat_back.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_back_drawer.material = mat_back
	add_child(_back_drawer)

	# 2. Capa delantera (z_index = 1): núcleo fino, halos ascendentes y destello frontal
	_front_drawer = Drawer.new()
	_front_drawer.name = "FrontDrawer"
	_front_drawer.draw_callback = _draw_front
	_front_drawer.z_index = 1
	_front_drawer.z_as_relative = true
	var mat_front: CanvasItemMaterial = CanvasItemMaterial.new()
	mat_front.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_front_drawer.material = mat_front
	add_child(_front_drawer)

	# 3. Partículas de chispas sagradas doradas subiendo
	_setup_particles()


func _setup_particles() -> void:
	_particles = CPUParticles2D.new()
	_particles.name = "LevelUpParticles"
	_particles.z_index = 1
	_particles.z_as_relative = true

	var p_scale: float = SettingsScript.particle_scale()
	_particles.amount = maxi(1, int(roundf(26.0 * p_scale)))
	_particles.lifetime = 0.85
	_particles.explosiveness = 0.05
	_particles.randomness = 0.3
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(18.0, 3.0)
	_particles.position = Vector2(0.0, 0.0)
	_particles.direction = Vector2(0.0, -1.0)
	_particles.spread = 10.0
	_particles.gravity = Vector2(0.0, -40.0)
	_particles.initial_velocity_min = 100.0
	_particles.initial_velocity_max = 180.0

	var disc_tex: Texture2D = BloodFxScript.disc_texture()
	_particles.texture = disc_tex
	var tex_w: float = float(disc_tex.get_width()) if disc_tex != null else 12.0
	_particles.scale_amount_min = 2.5 / tex_w
	_particles.scale_amount_max = 5.5 / tex_w

	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 0.92, 0.45, 0.95),
		Color(1.0, 0.70, 0.20, 0.75),
		Color(1.0, 0.45, 0.05, 0.0)
	])
	_particles.color_ramp = grad

	add_child(_particles)
	_particles.emitting = true


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return

	# Curva de desvanecimiento suave: subida rápida, meseta y fade out gradual
	var alpha_in: float = clampf(_time / 0.12, 0.0, 1.0)
	var fade_out: float = 1.0
	if _time > 1.0:
		fade_out = clampf(1.0 - (_time - 1.0) / (DURATION - 1.0), 0.0, 1.0)
		fade_out = fade_out * fade_out
	_master_alpha = alpha_in * fade_out

	if _particles != null:
		# Dejar de emitir nuevas partículas hacia el final para que mueran naturalmente
		_particles.emitting = (_time < 1.1)

	if _back_drawer != null:
		_back_drawer.queue_redraw()
	if _front_drawer != null:
		_front_drawer.queue_redraw()


## Reinicia la animación en el acto si el jugador sube varios niveles seguidos.
func restart() -> void:
	_time = 0.0
	_master_alpha = 1.0
	if _particles != null:
		var p_scale: float = SettingsScript.particle_scale()
		_particles.amount = maxi(1, int(roundf(26.0 * p_scale)))
		_particles.restart()
		_particles.emitting = true
	if _back_drawer != null:
		_back_drawer.queue_redraw()
	if _front_drawer != null:
		_front_drawer.queue_redraw()


func _draw_back(ci: CanvasItem) -> void:
	if _master_alpha <= 0.005:
		return

	var w_factor: float = clampf(_time / 0.18, 0.0, 1.0)
	var rise: float = clampf(_time / RISE_DURATION, 0.0, 1.0)
	var eased_rise: float = 1.0 - pow(1.0 - rise, 3.0)
	var top_y: float = lerpf(2.0, -BEAM_HEIGHT, eased_rise)

	var shimmer: float = 0.92 + 0.08 * sin(_time * 20.0) + 0.04 * cos(_time * 33.0)
	var col_alpha: float = _master_alpha * shimmer

	# 1. Resplandor / sello en los pies del personaje
	var ground_rx: float = 30.0 * w_factor
	var ground_ry: float = 9.0 * w_factor
	_draw_filled_ellipse(ci, Vector2(0.0, 2.0), ground_rx, ground_ry, Color(1.0, 0.78, 0.25, 0.35 * _master_alpha))
	_draw_ellipse(ci, Vector2(0.0, 2.0), ground_rx * 1.12, ground_ry * 1.12, Color(1.0, 0.90, 0.45, 0.55 * _master_alpha), 2.0)
	_draw_ellipse(ci, Vector2(0.0, 2.0), ground_rx * 0.65, ground_ry * 0.65, Color(1.0, 0.96, 0.60, 0.40 * _master_alpha), 1.5)

	# Si la columna todavía no empezó a subir, no dibujar el cuerpo vertical
	if absf(top_y - 2.0) < 2.0:
		return

	# 2. Haz exterior suave (resplandor dorado amplio)
	var hw_base_outer: float = (BEAM_WIDTH_BASE * 0.55) * w_factor
	var hw_top_outer: float = (BEAM_WIDTH_TOP * 0.55) * w_factor
	var poly_outer: PackedVector2Array = PackedVector2Array([
		Vector2(-hw_top_outer, top_y),
		Vector2(hw_top_outer, top_y),
		Vector2(hw_base_outer, 2.0),
		Vector2(-hw_base_outer, 2.0)
	])
	ci.draw_colored_polygon(poly_outer, Color(1.0, 0.70, 0.18, 0.24 * col_alpha))

	# 3. Haz medio (columna de luz dorada viva)
	var hw_base_mid: float = (BEAM_WIDTH_BASE * 0.35) * w_factor
	var hw_top_mid: float = (BEAM_WIDTH_TOP * 0.35) * w_factor
	var poly_mid: PackedVector2Array = PackedVector2Array([
		Vector2(-hw_top_mid, top_y),
		Vector2(hw_top_mid, top_y),
		Vector2(hw_base_mid, 2.0),
		Vector2(-hw_base_mid, 2.0)
	])
	ci.draw_colored_polygon(poly_mid, Color(1.0, 0.85, 0.30, 0.45 * col_alpha))

	# 4. Tapa de disipación superior (corona de luz al final de la columna)
	_draw_filled_ellipse(ci, Vector2(0.0, top_y), hw_top_outer * 0.9, hw_top_outer * 0.28, Color(1.0, 0.92, 0.55, 0.38 * col_alpha))

	# 5. Rayos verticales brillantes (estelas de energía en el pilar)
	var ray_color: Color = Color(1.0, 0.94, 0.55, 0.35 * col_alpha)
	var ray_offsets: Array[float] = [-12.0, -4.0, 5.0, 13.0]
	for idx: int in range(ray_offsets.size()):
		var x_off: float = ray_offsets[idx] * w_factor
		var wobble: float = sin(_time * 12.0 + float(idx) * 1.5) * 2.0
		var from_pt: Vector2 = Vector2(x_off + wobble * 0.3, 2.0)
		var to_pt: Vector2 = Vector2(x_off * 0.8 + wobble, top_y)
		ci.draw_line(from_pt, to_pt, ray_color, 1.5)


func _draw_front(ci: CanvasItem) -> void:
	if _master_alpha <= 0.005:
		return

	var w_factor: float = clampf(_time / 0.18, 0.0, 1.0)
	var rise: float = clampf(_time / RISE_DURATION, 0.0, 1.0)
	var eased_rise: float = 1.0 - pow(1.0 - rise, 3.0)
	var top_y: float = lerpf(2.0, -BEAM_HEIGHT, eased_rise)

	var shimmer: float = 0.92 + 0.08 * sin(_time * 20.0) + 0.04 * cos(_time * 33.0)
	var col_alpha: float = _master_alpha * shimmer

	# 1. Núcleo incandescente frontal (fino y translúcido para mantener legible el personaje)
	if absf(top_y - 2.0) >= 2.0:
		var hw_base_core: float = (BEAM_WIDTH_BASE * 0.16) * w_factor
		var hw_top_core: float = (BEAM_WIDTH_TOP * 0.16) * w_factor
		var poly_core: PackedVector2Array = PackedVector2Array([
			Vector2(-hw_top_core, top_y),
			Vector2(hw_top_core, top_y),
			Vector2(hw_base_core, 2.0),
			Vector2(-hw_base_core, 2.0)
		])
		ci.draw_colored_polygon(poly_core, Color(1.0, 0.98, 0.85, 0.28 * col_alpha))

	# 2. Anillos de halo ascendentes (el toque distintivo estilo WoW / MU Online)
	# Onda 1: rápida, asciende inmediatamente
	var p1: float = clampf((_time - 0.04) / 0.68, 0.0, 1.0)
	if p1 > 0.0 and p1 < 1.0:
		var ring_y_1: float = lerpf(2.0, -BEAM_HEIGHT * 1.05, p1)
		var ring_rx_1: float = lerpf(22.0, 36.0, p1) * w_factor
		var ring_ry_1: float = ring_rx_1 * 0.32
		var ring_a1: float = sin(p1 * PI) * _master_alpha * 0.88
		_draw_ellipse(ci, Vector2(0.0, ring_y_1), ring_rx_1, ring_ry_1, Color(1.0, 0.96, 0.65, ring_a1), 2.5)
		_draw_ellipse(ci, Vector2(0.0, ring_y_1), ring_rx_1 + 2.5, ring_ry_1 + 0.8, Color(1.0, 0.80, 0.20, ring_a1 * 0.45), 1.5)

	# Onda 2: secundaria, asciende poco después para mantener la sensación de ascensión
	var p2: float = clampf((_time - 0.36) / 0.78, 0.0, 1.0)
	if p2 > 0.0 and p2 < 1.0:
		var ring_y_2: float = lerpf(2.0, -BEAM_HEIGHT * 1.05, p2)
		var ring_rx_2: float = lerpf(20.0, 34.0, p2) * w_factor
		var ring_ry_2: float = ring_rx_2 * 0.32
		var ring_a2: float = sin(p2 * PI) * _master_alpha * 0.80
		_draw_ellipse(ci, Vector2(0.0, ring_y_2), ring_rx_2, ring_ry_2, Color(1.0, 0.90, 0.45, ring_a2), 2.5)
		_draw_ellipse(ci, Vector2(0.0, ring_y_2), ring_rx_2 + 2.5, ring_ry_2 + 0.8, Color(1.0, 0.75, 0.15, ring_a2 * 0.45), 1.5)

	# 3. Destello inicial en el torso (y = -32.0), respetando la opción de accesibilidad
	if _time < 0.22 and not SettingsScript.reduce_flashes():
		var flash_p: float = 1.0 - (_time / 0.22)
		var flash_rad: float = lerpf(40.0, 22.0, flash_p)
		_draw_filled_ellipse(ci, Vector2(0.0, -32.0), flash_rad, flash_rad, Color(1.0, 1.0, 0.85, 0.30 * flash_p))


func _draw_ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, width: float = 2.0) -> void:
	if rx <= 0.0 or ry <= 0.0 or col.a <= 0.005:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 24
	for i in range(steps + 1):
		var angle: float = float(i) * TAU / float(steps)
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	ci.draw_polyline(pts, col, width)


func _draw_filled_ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.0 or ry <= 0.0 or col.a <= 0.005:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 20
	for i in range(steps):
		var angle: float = float(i) * TAU / float(steps)
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	ci.draw_colored_polygon(pts, col)
