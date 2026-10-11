class_name AcidPool
extends Area2D
## Charco de ácido persistente. Aplica ticks continuos a los blancos hostiles que lo pisan
## con `armor_penetration = 1.0`, anulando su armadura mientras dura el efecto.

@export var lifetime: float = 5.0
@export var tick_interval: float = 0.5
@export var tick_damage: float = 8.0
@export var armor_penetration: float = 1.0
@export var pool_width: float = 150.0
@export var pool_height: float = 36.0
@export var pool_color: Color = Color(0.45, 0.95, 0.15, 1.0)

var source_node: Node2D = null

var _age: float = 0.0
var _tick_timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	
	# El rectángulo se apoya sobre el punto de impacto para cubrir a quienes están parados encima.
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(pool_width, pool_height)
	shape_node.shape = rect
	shape_node.position = Vector2(0.0, -pool_height * 0.5)
	add_child(shape_node)
	
	_tick_timer = 0.15


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_tick()
	
	queue_redraw()


func _apply_tick() -> void:
	var targets: Array[Node2D] = ThrowableUtil.collect_hostile_targets(self)
	for target in targets:
		if not is_instance_valid(target):
			continue
		var effects: Array[String] = ["ACID"]
		var payload: HitPayload = HitPayload.new(
			tick_damage,
			0.0,
			Vector2.ZERO,
			source_node,
			effects,
			1,
			0.0,
			armor_penetration
		)
		ThrowableUtil.deliver_hit(target, payload)


func _draw() -> void:
	var remaining: float = clampf((lifetime - _age) / 0.8, 0.0, 1.0)
	var bubble_phase: float = _age * 4.0
	
	var base: Color = pool_color
	base.a = 0.55 * remaining
	var half_w: float = pool_width * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 24
	for i in range(steps):
		var ang: float = TAU * float(i) / float(steps)
		var wobble: float = 1.0 + 0.06 * sin(bubble_phase + ang * 3.0)
		points.append(Vector2(cos(ang) * half_w * wobble, sin(ang) * 9.0 * wobble - 4.0))
	draw_colored_polygon(points, base)
	
	var rim: Color = pool_color.lightened(0.35)
	rim.a = 0.85 * remaining
	draw_polyline(points + PackedVector2Array([points[0]]), rim, 1.5)
	
	# Burbujas animadas
	var bubble: Color = Color(0.85, 1.0, 0.5, 0.8 * remaining)
	for i in range(4):
		var bx: float = sin(bubble_phase * 0.7 + float(i) * 1.9) * half_w * 0.6
		var by: float = -4.0 - absf(sin(bubble_phase + float(i) * 1.3)) * 7.0
		draw_circle(Vector2(bx, by), 2.0, bubble)
