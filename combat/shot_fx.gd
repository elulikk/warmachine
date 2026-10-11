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


## Fogonazo en la boca del cañón, orientado hacia `dir`. Dura una fracción de segundo.
static func muzzle_flash(host: Node, pos: Vector2, dir: Vector2, tint: Color = WARM) -> void:
	var container: Node = _container(host)
	if container == null:
		return
	var fx: Node2D = Node2D.new()
	fx.z_index = FX_Z_INDEX
	container.add_child(fx)
	fx.global_position = pos
	fx.rotation = dir.angle()

	fx.add_child(_disc(7.0, Color(tint.r, tint.g, tint.b, 0.35)))
	fx.add_child(_poly(PackedVector2Array([Vector2(-2.0, -6.0), Vector2(26.0, 0.0), Vector2(-2.0, 6.0)]), Color(tint.r, tint.g * 0.8, tint.b * 0.5, 0.8)))
	fx.add_child(_poly(PackedVector2Array([Vector2(2.0, 0.0), Vector2(11.0, -10.0), Vector2(6.0, 0.0)]), Color(tint.r, tint.g, tint.b, 0.85)))
	fx.add_child(_poly(PackedVector2Array([Vector2(2.0, 0.0), Vector2(11.0, 10.0), Vector2(6.0, 0.0)]), Color(tint.r, tint.g, tint.b, 0.85)))
	fx.add_child(_poly(PackedVector2Array([Vector2(-1.0, -3.0), Vector2(17.0, 0.0), Vector2(-1.0, 3.0)]), Color(1.0, 0.97, 0.82, 0.98)))

	fx.scale = Vector2(1.0, 1.0) * randf_range(0.9, 1.15)
	var tween: Tween = fx.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "scale", fx.scale * 1.6, 0.08)
	tween.tween_property(fx, "modulate:a", 0.0, 0.07).set_delay(0.02)
	tween.chain().tween_callback(fx.queue_free)


## Humito que sale de la boca del cañón y se eleva despacio, quedando atrás en el mundo.
static func muzzle_smoke(host: Node, pos: Vector2, dir: Vector2) -> void:
	var density: float = SettingsScript.particle_scale()
	if density < SMOKE_MIN_PARTICLE_SCALE:
		return
	var container: Node = _container(host)
	if container == null:
		return
	var puff: CPUParticles2D = CPUParticles2D.new()
	puff.texture = _puff_texture()
	puff.z_index = FX_Z_INDEX - 1
	puff.one_shot = true
	puff.amount = maxi(1, roundi(4.0 * density))
	puff.lifetime = 1.3
	puff.explosiveness = 1.0
	# Sale en la dirección del disparo y se curva hacia arriba
	puff.direction = (dir.normalized() + Vector2(0.0, -0.9)).normalized()
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
	container.add_child(puff)
	puff.global_position = pos
	puff.emitting = true
	puff.get_tree().create_timer(1.8).timeout.connect(puff.queue_free)


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

	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.z_index = FX_Z_INDEX
	sparks.one_shot = true
	sparks.amount = maxi(2, roundi(16.0 * SettingsScript.particle_scale()))
	sparks.lifetime = 0.4
	sparks.explosiveness = 1.0
	sparks.direction = direction
	sparks.spread = 58.0
	sparks.initial_velocity_min = 90.0
	sparks.initial_velocity_max = 260.0
	sparks.gravity = Vector2(0.0, 420.0)
	sparks.scale_amount_min = 2.5
	sparks.scale_amount_max = 5.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.98, 0.85, 1.0))
	ramp.set_color(1, Color(tint.r, tint.g * 0.45, tint.b * 0.2, 0.0))
	sparks.color_ramp = ramp
	container.add_child(sparks)
	sparks.global_position = pos
	sparks.emitting = true
	sparks.get_tree().create_timer(0.8).timeout.connect(sparks.queue_free)

	# Destello breve en el punto de contacto
	var flash: Node2D = Node2D.new()
	flash.z_index = FX_Z_INDEX
	container.add_child(flash)
	flash.global_position = pos
	flash.add_child(_disc(8.0, Color(1.0, 0.95, 0.75, 0.95)))
	flash.add_child(_disc(14.0, Color(tint.r, tint.g, tint.b, 0.4)))
	var tween: Tween = flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.7, 1.7), 0.09)
	tween.tween_property(flash, "modulate:a", 0.0, 0.09)
	tween.chain().tween_callback(flash.queue_free)
