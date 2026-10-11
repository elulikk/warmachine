extends Node
## Daño visible en un enemigo: sangre (o aceite y chispas si es mecánico) al recibir golpes, manchas
## en el piso que duran un rato y marcas de heridas que se acumulan a medida que pierde vida.
## Sin class_name a propósito. Lo agrega `HealthComponent` solo a los hijos del grupo `enemies`.
##
## - Cada golpe: salpicadura en la dirección del impacto y manchas donde caen las gotas.
## - Marcas en el cuerpo (salpicaduras y tajos): una por cada octavo de vida perdido.
## - Al cruzar 2/3 y 1/3 de vida (y al morir): trozos que salen despedidos.
## - Con menos de la mitad de vida gotea sangre al caminar (solo en calidad gráfica media o alta).

const BloodFx = preload("res://combat/blood_fx.gd")
const SettingsScript = preload("res://core/settings.gd")

const MAX_MARKS: int = 8
const MECHANICAL_SCRIPTS: Array[String] = ["SniperTurret", "TrainingTurret", "TrainingDummy"]
const THRESHOLDS: Array[float] = [0.66, 0.33]
const DRIP_RATIO: float = 0.5
const DRIP_MIN_DENSITY: float = 0.75

var health: Node = null

var _host: Node2D = null
var _mechanical: bool = false
var _body_rect: Rect2 = Rect2(-10.0, -34.0, 20.0, 34.0)
var _marks: int = 0
var _last_ratio: float = 1.0
var _drip_timer: float = 1.0


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
	if _last_ratio > DRIP_RATIO or SettingsScript.particle_scale() < DRIP_MIN_DENSITY:
		return
	_drip_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = randf_range(1.0, 2.2)
		var pos: Vector2 = _body_center() + Vector2(randf_range(-5.0, 5.0), _body_rect.size.y * 0.3)
		BloodFx.stains(_host, pos, Vector2.ZERO, 1, 0.6, false)


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

	BloodFx.spray(_host, spot, dir, strength, _mechanical)
	if not _mechanical:
		BloodFx.spray_sprite(_host, spot, dir, strength)
	BloodFx.stains(_host, spot, dir, 1 + int(strength / 14.0), clampf(0.8 + strength / 60.0, 0.8, 1.6), _mechanical)

	# Heridas visibles en el cuerpo: una por cada octavo de vida perdido
	var wanted: int = int(floor((1.0 - ratio) * float(MAX_MARKS)))
	var added: int = 0
	while _marks < wanted and added < 3:
		_add_mark()
		_marks += 1
		added += 1

	for threshold: float in THRESHOLDS:
		if _last_ratio > threshold and ratio <= threshold:
			BloodFx.gibs(_host, spot, 3, _mechanical, 0.8)
	_last_ratio = ratio


func _on_died() -> void:
	if _host == null or not _host.is_inside_tree():
		return
	var spot: Vector2 = _body_center()
	# Explosión final: lluvia de trozos y tripas, doble salpicadura y varios charcos
	BloodFx.gibs(_host, spot, 12, _mechanical, 1.0)
	BloodFx.spray(_host, spot, Vector2.UP, 60.0, _mechanical)
	BloodFx.spray(_host, spot + Vector2(0.0, 6.0), Vector2.LEFT, 40.0, _mechanical)
	BloodFx.spray(_host, spot + Vector2(0.0, 6.0), Vector2.RIGHT, 40.0, _mechanical)
	BloodFx.spray_sprite(_host, spot, Vector2.UP, 90.0)
	BloodFx.spray_sprite(_host, spot, Vector2.from_angle(deg_to_rad(-30.0)), 70.0)
	BloodFx.spray_sprite(_host, spot, Vector2.from_angle(deg_to_rad(-150.0)), 70.0)
	BloodFx.stains(_host, spot, Vector2.ZERO, 6, 1.9, _mechanical)


## Agrega una herida al cuerpo: salpicadura irregular o tajo.
func _add_mark() -> void:
	var margin_x: float = _body_rect.size.x * 0.15
	var margin_y: float = _body_rect.size.y * 0.1
	var at: Vector2 = Vector2(
		randf_range(_body_rect.position.x + margin_x, _body_rect.end.x - margin_x),
		randf_range(_body_rect.position.y + margin_y, _body_rect.end.y - margin_y)
	)
	var mark: Node2D = Node2D.new()
	mark.position = at
	mark.z_index = 2
	mark.rotation = randf() * TAU
	var mark_art: Texture2D = null if _mechanical else BloodFx.variant_tex("blood_mark", 4)
	if mark_art != null:
		var painted: Sprite2D = Sprite2D.new()
		painted.texture = mark_art
		painted.scale = Vector2(0.5, 0.5)
		mark.add_child(painted)
		_host.add_child(mark)
		mark.scale = Vector2(0.2, 0.2)
		mark.create_tween().tween_property(mark, "scale", Vector2.ONE, 0.1)
		return
	var dark: Color = Color(0.09, 0.09, 0.1, 0.9) if _mechanical else Color(0.42, 0.02, 0.04, 0.92)
	var bright: Color = Color(0.9, 0.88, 0.8, 0.9) if _mechanical else Color(0.72, 0.06, 0.08, 0.95)
	if randf() < 0.55:
		var radius: float = randf_range(3.0, 6.0)
		var points: PackedVector2Array = PackedVector2Array()
		for i in range(8):
			var angle: float = TAU * float(i) / 8.0
			points.append(Vector2.from_angle(angle) * radius * randf_range(0.55, 1.1))
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
		var length: float = randf_range(7.0, 13.0)
		var line_points: PackedVector2Array = PackedVector2Array([Vector2(-length * 0.5, 0.0), Vector2(length * 0.5, randf_range(-1.5, 1.5))])
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
	var pop: Tween = mark.create_tween()
	pop.tween_property(mark, "scale", Vector2.ONE, 0.1)
