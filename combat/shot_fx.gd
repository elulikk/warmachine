extends RefCounted
## Efectos visuales de disparo: fogonazo en la boca del arma y chispas al chocar contra el entorno.
## Sin class_name a propósito: se carga por `preload` (ver class-name-cache-gotcha).
## Todo es procedural (polígonos y partículas de CPU), compatible con el renderizador gl_compatibility.

const FX_Z_INDEX: int = 20
const WARM: Color = Color(1.0, 0.82, 0.35, 1.0)
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


## Chispas al chocar contra el entorno. `normal` apunta hacia afuera de la superficie.
static func wall_impact(host: Node, pos: Vector2, normal: Vector2, tint: Color = WARM) -> void:
	var container: Node = _container(host)
	if container == null:
		return
	var direction: Vector2 = normal.normalized() if normal.length() > 0.01 else Vector2.UP

	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.z_index = FX_Z_INDEX
	sparks.one_shot = true
	sparks.amount = 16
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
