extends RefCounted
## Efectos visuales de disparo: fogonazo en la boca del arma y chispas al chocar contra el entorno.
## Sin class_name a propósito: se carga por `preload` (ver class-name-cache-gotcha).
## Todo es procedural (polígonos y partículas de CPU), compatible con el renderizador gl_compatibility.

const FX_Z_INDEX: int = 20
const WARM: Color = Color(1.0, 0.82, 0.35, 1.0)
## Con calidad gráfica baja (densidad de partículas menor) el humo no se dibuja y las chispas son menos.
const SMOKE_MIN_PARTICLE_SCALE: float = 0.75
const SettingsScript = preload("res://core/settings.gd")
const COLD: Color = Color(0.45, 0.85, 1.0, 1.0)


static func _container(host: Node) -> Node:
	if host == null or not host.is_inside_tree():
		return null
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


static func _poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	return polygon


static func _disc(radius: float, color: Color) -> Polygon2D:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		points.append(Vector2.from_angle(TAU * float(i) / 10.0) * radius)
	return _poly(points, color)


## Reserva de efectos: los disparos automáticos crean decenas por segundo, así que se reutilizan los nodos
## en vez de instanciarlos y liberarlos cada vez. Un nodo vuelve a la reserva con `_recycle` al terminar.
const POOL_MAX: int = 40
static var _flash_pool: Array[Node2D] = []
static var _smoke_pool: Array[CPUParticles2D] = []
static var _spark_pool: Array[CPUParticles2D] = []
static var _impact_flash_pool: Array[Node2D] = []


static func _take(pool: Array) -> Node:
	while not pool.is_empty():
		var node: Node = pool.pop_back() as Node
		if is_instance_valid(node) and not node.is_inside_tree():
			return node
	return null


static func _recycle(node: Node, pool: Array) -> void:
	if not is_instance_valid(node):
		return
	if node.is_inside_tree():
		node.get_parent().remove_child(node)
	if pool.size() < POOL_MAX:
		pool.append(node)
	else:
		node.queue_free()


## Programa el regreso de `node` a su reserva tras `seconds`.
static func _recycle_after(node: Node, seconds: float, pool: Array) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(_recycle.bind(node, pool))


static func _paint_flash(fx: Node2D, tint: Color) -> void:
	var colors: Array[Color] = [
		Color(tint.r, tint.g, tint.b, 0.35),
		Color(tint.r, tint.g * 0.8, tint.b * 0.5, 0.8),
		Color(tint.r, tint.g, tint.b, 0.85),
		Color(tint.r, tint.g, tint.b, 0.85),
		Color(1.0, 0.97, 0.82, 0.98),
	]
	for i in range(5):
		(fx.get_child(i) as Polygon2D).color = colors[i]


## Fogonazo en la boca del cañón, orientado hacia `dir`. Dura una fracción de segundo.
static func muzzle_flash(host: Node, pos: Vector2, dir: Vector2, tint: Color = WARM) -> void:
	var container: Node = _container(host)
	if container == null:
		return
	var fx: Node2D = _take(_flash_pool) as Node2D
	if fx == null:
		fx = Node2D.new()
		fx.z_index = FX_Z_INDEX
		fx.add_child(_disc(7.0, WARM))
		fx.add_child(_poly(PackedVector2Array([Vector2(-2.0, -6.0), Vector2(26.0, 0.0), Vector2(-2.0, 6.0)]), WARM))
		fx.add_child(_poly(PackedVector2Array([Vector2(2.0, 0.0), Vector2(11.0, -10.0), Vector2(6.0, 0.0)]), WARM))
		fx.add_child(_poly(PackedVector2Array([Vector2(2.0, 0.0), Vector2(11.0, 10.0), Vector2(6.0, 0.0)]), WARM))
		fx.add_child(_poly(PackedVector2Array([Vector2(-1.0, -3.0), Vector2(17.0, 0.0), Vector2(-1.0, 3.0)]), WARM))
	_paint_flash(fx, tint)
	fx.modulate = Color.WHITE
	container.add_child(fx)
	fx.global_position = pos
	fx.rotation = dir.angle()
	fx.scale = Vector2.ONE * randf_range(0.9, 1.15)
	var tween: Tween = fx.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "scale", fx.scale * 1.6, 0.08)
	tween.tween_property(fx, "modulate:a", 0.0, 0.07).set_delay(0.02)
	tween.chain().tween_callback(_recycle.bind(fx, _flash_pool))


## Humito que sale de la boca del cañón y se eleva despacio, quedando atrás en el mundo.
static func muzzle_smoke(host: Node, pos: Vector2, dir: Vector2) -> void:
	var density: float = SettingsScript.particle_scale()
	if density < SMOKE_MIN_PARTICLE_SCALE:
		return
	var container: Node = _container(host)
	if container == null:
		return
	var puff: CPUParticles2D = _take(_smoke_pool) as CPUParticles2D
	if puff == null:
		puff = CPUParticles2D.new()
		puff.texture = _puff_texture()
		puff.z_index = FX_Z_INDEX - 1
		puff.one_shot = true
		puff.lifetime = 1.3
		puff.explosiveness = 1.0
		puff.spread = 28.0
		puff.initial_velocity_min = 10.0
		puff.initial_velocity_max = 34.0
		puff.gravity = Vector2(0.0, -16.0)
		puff.damping_min = 12.0
		puff.damping_max = 22.0
		puff.scale_amount_min = 0.6
		puff.scale_amount_max = 0.9
		var growth: Curve = Curve.new()
		growth.add_point(Vector2(0.0, 0.5))
		growth.add_point(Vector2(1.0, 2.4))
		puff.scale_amount_curve = growth
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(0.86, 0.84, 0.8, 0.85))
		ramp.set_color(1, Color(0.6, 0.58, 0.55, 0.0))
		puff.color_ramp = ramp
	puff.amount = maxi(1, roundi(4.0 * density))
	# Sale en la dirección del disparo y se curva hacia arriba
	puff.direction = (dir.normalized() + Vector2(0.0, -0.9)).normalized()
	container.add_child(puff)
	puff.global_position = pos
	puff.restart()
	puff.emitting = true
	_recycle_after(puff, 1.8, _smoke_pool)


static var _puff_tex: Texture2D = null


## Disco suave y borroso (se genera una vez) para las nubes de humo.
static func _puff_texture() -> Texture2D:
	if _puff_tex != null:
		return _puff_tex
	var size: int = 24
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = (size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x - center, y - center).length() / center
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	_puff_tex = ImageTexture.create_from_image(image)
	return _puff_tex


## Chispas al chocar contra el entorno. `normal` apunta hacia afuera de la superficie.
static func wall_impact(host: Node, pos: Vector2, normal: Vector2, tint: Color = WARM) -> void:
	var container: Node = _container(host)
	if container == null:
		return
	var direction: Vector2 = normal.normalized() if normal.length() > 0.01 else Vector2.UP

	var sparks: CPUParticles2D = _take(_spark_pool) as CPUParticles2D
	if sparks == null:
		sparks = CPUParticles2D.new()
		sparks.z_index = FX_Z_INDEX
		sparks.one_shot = true
		sparks.lifetime = 0.4
		sparks.explosiveness = 1.0
		sparks.spread = 58.0
		sparks.initial_velocity_min = 90.0
		sparks.initial_velocity_max = 260.0
		sparks.gravity = Vector2(0.0, 420.0)
		sparks.scale_amount_min = 2.5
		sparks.scale_amount_max = 5.0
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(1.0, 0.98, 0.85, 1.0))
		ramp.set_color(1, Color(1.0, 0.4, 0.2, 0.0))
		sparks.color_ramp = ramp
	sparks.amount = maxi(2, roundi(16.0 * SettingsScript.particle_scale()))
	sparks.direction = direction
	sparks.color_ramp.set_color(1, Color(tint.r, tint.g * 0.45, tint.b * 0.2, 0.0))
	container.add_child(sparks)
	sparks.global_position = pos
	sparks.restart()
	sparks.emitting = true
	_recycle_after(sparks, 0.8, _spark_pool)

	# Destello breve en el punto de contacto
	var flash: Node2D = _take(_impact_flash_pool) as Node2D
	if flash == null:
		flash = Node2D.new()
		flash.z_index = FX_Z_INDEX
		flash.add_child(_disc(8.0, Color(1.0, 0.95, 0.75, 0.95)))
		flash.add_child(_disc(14.0, WARM))
	(flash.get_child(1) as Polygon2D).color = Color(tint.r, tint.g, tint.b, 0.4)
	flash.scale = Vector2.ONE
	flash.modulate = Color.WHITE
	container.add_child(flash)
	flash.global_position = pos
	var tween: Tween = flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.7, 1.7), 0.09)
	tween.tween_property(flash, "modulate:a", 0.0, 0.09)
	tween.chain().tween_callback(_recycle.bind(flash, _impact_flash_pool))
