extends Node
## Daño visible en un enemigo: sangre (o aceite y chispas si es mecánico) al recibir golpes, manchas
## en el piso que duran un rato y marcas de heridas que se acumulan a medida que pierde vida.
## Sin class_name a propósito. Lo agrega `HealthComponent` solo a los hijos del grupo `enemies`.
##
## - Cada golpe: salpicadura en la dirección del impacto y manchas donde caen las gotas.
## - Cicatrices en el cuerpo (heridas chicas que se quedan): una por cada octavo de vida perdido.
## - Pixeles de sangre que brotan del cuerpo, más cuanta menos vida le queda.
## - Al cruzar 2/3 y 1/3 de vida (y al morir): trozos que salen despedidos.

const BloodFx = preload("res://combat/blood_fx.gd")
const DeathFxQueueScript = preload("res://combat/death_fx_queue.gd")
const SettingsScript = preload("res://core/settings.gd")
const ViewCullScript = preload("res://core/view_cull.gd")

## Cicatrices máximas en el cuerpo y tamaño del arte respecto del alto del cuerpo (el arte pintado a escala 0.5 se veía enorme).
const MAX_MARKS: int = 8
const MARK_SIZE_RATIO: float = 0.2
const MECHANICAL_SCRIPTS: Array[String] = ["SniperTurret", "TrainingTurret", "TrainingDummy"]
const THRESHOLDS: Array[float] = [0.66, 0.33]
## Empieza a sangrar al bajar de esta fracción de vida; con menos densidad de partículas no sangra.
const BLEED_START: float = 0.8
const BLEED_MIN_DENSITY: float = 0.5
const BLEED_TEX_PX: int = 4
static var _bleed_tex: Texture2D = null

var health: Node = null

var _host: Node2D = null
var _mechanical: bool = false
var _body_rect: Rect2 = Rect2(-10.0, -34.0, 20.0, 34.0)
var _marks: int = 0
var _bleed: CPUParticles2D = null
var _bleed_check: float = 0.0
var _last_ratio: float = 1.0


func _ready() -> void:
	_host = get_parent() as Node2D
	if _host == null or health == null:
		queue_free()
		return
	var script_name: String = ""
	if _host.get_script() != null:
		script_name = str((_host.get_script() as Script).get_global_name())
	_mechanical = MECHANICAL_SCRIPTS.has(script_name)
	_body_rect = _find_body_rect()
	health.connect(&"hit_resolved", _on_hit_resolved)
	health.connect(&"died", _on_died)


func _process(delta: float) -> void:
	if _mechanical or health == null or bool(health.get("is_dead")):
		return
	_update_bleed(delta)


## Pixeles de sangre que brotan del cuerpo: más y más seguido cuanta menos vida le queda.
## Un solo CPUParticles2D por enemigo herido, apagado cuando está lejos de la cámara o con pocas partículas.
func _update_bleed(delta: float) -> void:
	_bleed_check -= delta
	if _bleed_check > 0.0:
		return
	_bleed_check = 0.25
	var level: float = clampf((BLEED_START - _last_ratio) / BLEED_START, 0.0, 1.0)
	var wanted: bool = level > 0.0 and SettingsScript.particle_scale() >= BLEED_MIN_DENSITY and ViewCullScript.near(_host, 120.0)
	if not wanted:
		if _bleed != null:
			_bleed.emitting = false
		return
	if _bleed == null:
		_bleed = _make_bleed_emitter()
		_host.add_child(_bleed)
	# CPUParticles2D no tiene amount_ratio: cambiar `amount` reinicia la emisión, así que solo si cambia de verdad
	var bleed_count: int = maxi(3, roundi(12.0 * lerpf(0.2, 1.0, level)))
	if _bleed.amount != bleed_count:
		_bleed.amount = bleed_count
	# Mientras menos vida, más grandes
	_bleed.scale_amount_min = lerpf(1.5, 6.0, level) / float(BLEED_TEX_PX)
	_bleed.scale_amount_max = lerpf(2.5, 11.0, level) / float(BLEED_TEX_PX)
	_bleed.emitting = true


## Cuadradito blanco (el color lo da el degradé): sin textura la partícula no respeta bien la escala.
static func _bleed_texture() -> Texture2D:
	if _bleed_tex == null:
		var image: Image = Image.create(BLEED_TEX_PX, BLEED_TEX_PX, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_bleed_tex = ImageTexture.create_from_image(image)
	return _bleed_tex


func _make_bleed_emitter() -> CPUParticles2D:
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.name = "BleedFx"
	# Nacen repartidas por todo el cuerpo, no desde un solo punto
	emitter.position = _body_rect.get_center()
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emitter.emission_rect_extents = _body_rect.size * 0.5
	emitter.z_index = 3
	emitter.amount = 12
	emitter.lifetime = 0.55
	emitter.local_coords = false
	emitter.direction = Vector2(0.0, -1.0)
	emitter.spread = 80.0
	emitter.initial_velocity_min = 18.0
	emitter.initial_velocity_max = 55.0
	emitter.gravity = Vector2(0.0, 520.0)
	emitter.texture = _bleed_texture()
	emitter.scale_amount_min = 1.5 / float(BLEED_TEX_PX)
	emitter.scale_amount_max = 2.5 / float(BLEED_TEX_PX)
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(0.8, 0.05, 0.08, 1.0), Color(0.5, 0.02, 0.05, 1.0), Color(0.4, 0.02, 0.04, 0.0)])
	emitter.color_ramp = ramp
	return emitter


## Rectángulo del cuerpo en coordenadas locales del enemigo (a partir de su colisión).
func _find_body_rect() -> Rect2:
	for child: Node in _host.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			continue
		var size: Vector2 = Vector2(20.0, 34.0)
		if shape_node.shape is RectangleShape2D:
			size = (shape_node.shape as RectangleShape2D).size
		elif shape_node.shape is CapsuleShape2D:
			var capsule: CapsuleShape2D = shape_node.shape as CapsuleShape2D
			size = Vector2(capsule.radius * 2.0, capsule.height)
		elif shape_node.shape is CircleShape2D:
			var radius: float = (shape_node.shape as CircleShape2D).radius
			size = Vector2(radius * 2.0, radius * 2.0)
		return Rect2(shape_node.position - size * 0.5, size)
	return _body_rect


func _body_center() -> Vector2:
	return _host.to_global(_body_rect.get_center())


func _on_hit_resolved(payload: HitPayload, damage: float, is_critical: bool) -> void:
	if damage <= 0.0 or _host == null or not _host.is_inside_tree():
		return
	var max_health: float = maxf(1.0, float(health.get("max_health")))
	var ratio: float = clampf(float(health.get("current_health")) / max_health, 0.0, 1.0)
	var dir: Vector2 = payload.knockback_direction if payload != null else Vector2.ZERO
	var spot: Vector2 = _body_center() + Vector2(randf_range(-3.0, 3.0), randf_range(-0.3, 0.3) * _body_rect.size.y)
	var strength: float = damage * (1.6 if is_critical else 1.0)

	var amount: float = _gore_amount()
	BloodFx.spray(_host, spot, dir, strength * amount, _mechanical)
	if not _mechanical and amount >= 0.7:
		BloodFx.spray_sprite(_host, spot, dir, strength * amount)
	BloodFx.stains(_host, spot, dir, maxi(1, roundi(float(1 + int(strength / 14.0)) * amount)), clampf(0.8 + strength / 60.0, 0.8, 1.6) * lerpf(0.7, 1.0, amount) * lerpf(0.5, 1.0, _gore_scale()), _mechanical)

	# Cicatrices: una por cada octavo de vida perdido (hasta 3 por golpe)
	var wanted: int = int(floor((1.0 - ratio) * float(MAX_MARKS)))
	var added: int = 0
	while _marks < wanted and added < 3:
		_add_mark()
		_marks += 1
		added += 1

	for threshold: float in THRESHOLDS:
		if _last_ratio > threshold and ratio <= threshold and amount >= 0.7:
			BloodFx.gibs(_host, spot, 2, _mechanical, 0.8, _gore_scale())
	_last_ratio = ratio


func _on_died() -> void:
	if _host == null or not _host.is_inside_tree():
		return
	# Explosión final (lluvia de trozos y tripas, salpicaduras y charcos): la arma la cola de muertes,
	# repartida en los cuadros siguientes si mueren muchos juntos (combat/death_fx_queue.gd)
	DeathFxQueueScript.gore(_host, _body_center(), _mechanical, _gore_scale(), _gore_amount())


## Cantidad de sangre y trozos del enemigo (`gore_amount` de su escena; 1.0 si no la tiene).
func _gore_amount() -> float:
	var value: Variant = _host.get("gore_amount")
	return clampf(float(value), 0.1, 1.5) if value != null else 1.0


## Los bichos chicos (ratas) sueltan menos trozos y más chicos: 1.0 para un humano, menos según el alto del cuerpo.
func _gore_scale() -> float:
	return clampf(_body_rect.size.y / 44.0, 0.35, 1.0)


## Agrega una cicatriz al cuerpo: herida pintada, o salpicadura / tajo dibujados si no hay arte (y en las máquinas).
## Su tamaño sale del alto del cuerpo: en una rata es chica y en un humano ronda los 9 px.
func _add_mark() -> void:
	var margin_x: float = _body_rect.size.x * 0.15
	var margin_y: float = _body_rect.size.y * 0.1
	var at: Vector2 = Vector2(
		randf_range(_body_rect.position.x + margin_x, _body_rect.end.x - margin_x),
		randf_range(_body_rect.position.y + margin_y, _body_rect.end.y - margin_y)
	)
	var size_px: float = clampf(_body_rect.size.y * MARK_SIZE_RATIO, 4.0, 12.0) * randf_range(0.8, 1.2)
	var mark: Node2D = Node2D.new()
	mark.position = at
	mark.z_index = 2
	mark.rotation = randf() * TAU
	var mark_art: Texture2D = null if _mechanical else BloodFx.variant_tex("blood_mark", 4)
	if mark_art != null:
		var painted: Sprite2D = Sprite2D.new()
		painted.texture = mark_art
		var fit: float = size_px / float(maxi(mark_art.get_width(), mark_art.get_height()))
		painted.scale = Vector2(fit, fit)
		mark.add_child(painted)
	else:
		var dark: Color = Color(0.09, 0.09, 0.1, 0.9) if _mechanical else Color(0.42, 0.02, 0.04, 0.92)
		var bright: Color = Color(0.9, 0.88, 0.8, 0.9) if _mechanical else Color(0.72, 0.06, 0.08, 0.95)
		var half: float = size_px * 0.5
		if randf() < 0.55:
			var points: PackedVector2Array = PackedVector2Array()
			for i in range(8):
				points.append(Vector2.from_angle(TAU * float(i) / 8.0) * half * randf_range(0.55, 1.1))
			var splat: Polygon2D = Polygon2D.new()
			splat.polygon = points
			splat.color = dark
			mark.add_child(splat)
			if not _mechanical:
				var core_points: PackedVector2Array = PackedVector2Array()
				for point: Vector2 in points:
					core_points.append(point * 0.5)
				var core: Polygon2D = Polygon2D.new()
				core.polygon = core_points
				core.color = bright
				mark.add_child(core)
		else:
			var line_points: PackedVector2Array = PackedVector2Array([Vector2(-half, 0.0), Vector2(half, randf_range(-1.0, 1.0))])
			var gash: Line2D = Line2D.new()
			gash.points = line_points
			gash.width = 2.0
			gash.default_color = dark
			mark.add_child(gash)
			var edge: Line2D = Line2D.new()
			edge.points = line_points
			edge.width = 0.8
			edge.default_color = bright
			mark.add_child(edge)
	_host.add_child(mark)
	mark.scale = Vector2(0.2, 0.2)
	mark.create_tween().tween_property(mark, "scale", Vector2.ONE, 0.1)
