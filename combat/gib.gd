extends Node2D
## Trozo de carne, tripa, hueso (o chatarra y resorte en los mecánicos) que sale despedido al morir un
## enemigo. Física mínima a mano: gravedad, rebote contra el piso (raycast a la capa 1) y reposo.
## Deja una mancha donde cae y se desvanece pasado un rato. Sin class_name a propósito.
##
## Si existe el arte (`assets/art/fx/gore_*.png`, ver BloodFx) usa esa textura; si no, dibuja una
## forma procedural del mismo tipo.

const BloodFx = preload("res://combat/blood_fx.gd")

const GRAVITY: float = 900.0
const MAX_BOUNCES: int = 2
const BOUNCE_DAMPING: float = 0.36
const FRICTION: float = 0.6
const REST_SECONDS: float = 6.0
const FADE_SECONDS: float = 1.5
## Si en el aire no encuentra piso en este tiempo, se desvanece igual.
const AIR_TIMEOUT: float = 2.5

var velocity: Vector2 = Vector2.ZERO
var spin: float = 0.0
var mechanical: bool = false

var _bounces: int = 0
var _resting: bool = false
var _air_time: float = 0.0
var _stained: bool = false


## Arma el aspecto. kind: "chunk", "gut" o "bone" (orgánico); "scrap" o "spring" (mecánico).
func build(kind: String, texture: Texture2D) -> void:
	if texture != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = texture
		# El arte se exporta al doble del tamaño en juego (igual que los props)
		sprite.scale = Vector2(0.5, 0.5)
		sprite.flip_h = randf() < 0.5
		add_child(sprite)
		return

	match kind:
		"gut":
			var length: float = randf_range(14.0, 24.0)
			var points: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var t: float = float(i) / 5.0
				points.append(Vector2(lerpf(-length * 0.5, length * 0.5, t), sin(t * TAU * 1.3) * 3.2))
			var outline: Line2D = Line2D.new()
			outline.points = points
			outline.width = 6.0
			outline.default_color = Color(0.35, 0.04, 0.07, 0.95)
			outline.joint_mode = Line2D.LINE_JOINT_ROUND
			outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
			outline.end_cap_mode = Line2D.LINE_CAP_ROUND
			add_child(outline)
			var flesh: Line2D = Line2D.new()
			flesh.points = points
			flesh.width = 3.4
			flesh.default_color = Color(0.86, 0.42, 0.5, 1.0)
			flesh.joint_mode = Line2D.LINE_JOINT_ROUND
			flesh.begin_cap_mode = Line2D.LINE_CAP_ROUND
			flesh.end_cap_mode = Line2D.LINE_CAP_ROUND
			add_child(flesh)
		"bone":
			var bone: Polygon2D = Polygon2D.new()
			bone.polygon = PackedVector2Array([Vector2(-6.0, -1.2), Vector2(-7.0, -2.4), Vector2(-7.0, 2.4), Vector2(-6.0, 1.2), Vector2(6.0, 1.2), Vector2(7.0, 2.4), Vector2(7.0, -2.4), Vector2(6.0, -1.2)])
			bone.color = Color(0.9, 0.87, 0.78, 1.0)
			add_child(bone)
		"spring":
			var zigzag: Line2D = Line2D.new()
			var spring_points: PackedVector2Array = PackedVector2Array()
			for i in range(7):
				spring_points.append(Vector2(-9.0 + float(i) * 3.0, -2.5 if i % 2 == 0 else 2.5))
			zigzag.points = spring_points
			zigzag.width = 1.4
			zigzag.default_color = Color(0.65, 0.65, 0.68, 1.0)
			add_child(zigzag)
		"scrap":
			add_child(_irregular(randf_range(3.0, 5.5), Color(0.3, 0.31, 0.35, 1.0) if randf() < 0.6 else Color(0.5, 0.33, 0.18, 1.0)))
		_:
			var radius: float = randf_range(3.6, 7.0)
			var base: Color = [Color(0.62, 0.07, 0.1, 1.0), Color(0.82, 0.32, 0.36, 1.0), Color(0.45, 0.04, 0.07, 1.0)].pick_random()
			var body: Polygon2D = _irregular(radius, base)
			add_child(body)
			var shine: Polygon2D = _irregular(radius * 0.45, Color(minf(base.r * 1.4, 1.0), minf(base.g * 1.6, 1.0), minf(base.b * 1.6, 1.0), 0.9))
			shine.position = Vector2(-radius * 0.15, -radius * 0.15)
			add_child(shine)


static func _irregular(radius: float, color: Color) -> Polygon2D:
	var points: PackedVector2Array = PackedVector2Array()
	var count: int = randi_range(6, 8)
	for i in range(count):
		points.append(Vector2.from_angle(TAU * float(i) / float(count)) * radius * randf_range(0.6, 1.1))
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	return polygon


func _physics_process(delta: float) -> void:
	if _resting:
		return
	_air_time += delta
	if _air_time > AIR_TIMEOUT:
		_rest(false)
		return

	velocity.y += GRAVITY * delta
	var step: Vector2 = velocity * delta
	if velocity.y > 0.0:
		var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + step + Vector2(0.0, 3.0), 1)
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			global_position = (hit["position"] as Vector2) + Vector2(0.0, -1.5)
			_land()
			return
	global_position += step
	rotation += spin * delta


func _land() -> void:
	if not _stained:
		_stained = true
		BloodFx.stains(self, global_position + Vector2(0.0, -2.0), velocity, 1, 1.0, mechanical)
	_bounces += 1
	if _bounces > MAX_BOUNCES or absf(velocity.y) < 60.0:
		_rest(true)
		return
	velocity.y = -velocity.y * BOUNCE_DAMPING
	velocity.x *= FRICTION
	spin *= 0.5


## Se queda quieto en el piso (o donde esté) y se desvanece pasado un rato.
func _rest(on_floor: bool) -> void:
	_resting = true
	velocity = Vector2.ZERO
	if on_floor:
		rotation = roundf(rotation / PI) * PI
	var fade: Tween = create_tween()
	fade.tween_interval(REST_SECONDS if on_floor else 0.2)
	fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	fade.tween_callback(queue_free)
