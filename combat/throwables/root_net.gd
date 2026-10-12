extends Area2D
## Red arraigadora (Fase R). Al desplegarse deja arraigados (sin poder moverse) a los enemigos que
## están dentro o que entran mientras dura. Cada enemigo se arraiga una sola vez por red, así que
## no se queda trabado para siempre. No hace daño. Visual procedural: telaraña sobre el piso.

const SfxScript = preload("res://core/sfx.gd")

@export var lifetime: float = 4.0
@export var root_duration: float = 2.0
@export var radius: float = 120.0
@export var check_interval: float = 0.1
@export var net_color: Color = Color(0.75, 0.9, 0.55, 1.0)

var source_node: Node2D = null

var _age: float = 0.0
var _check_timer: float = 0.0
var _caught: Dictionary = {} ## instance_id -> true (ya arraigados por esta red)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 5

	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	shape_node.position = Vector2(0.0, -radius * 0.25)
	add_child(shape_node)
	SfxScript.play(self, &"net_deploy", global_position, -2.0, randf_range(0.95, 1.05))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = check_interval
		_root_targets()
	queue_redraw()


func _root_targets() -> void:
	for target: Node2D in ThrowableUtil.collect_hostile_targets(self):
		if not is_instance_valid(target):
			continue
		var key: int = target.get_instance_id()
		if _caught.has(key):
			continue
		var receiver: StatusReceiverComponent = ThrowableUtil.get_status_receiver(target)
		if receiver == null:
			continue
		_caught[key] = true
		receiver.apply_root(root_duration)


func _draw() -> void:
	var open_t: float = clampf(_age / 0.2, 0.0, 1.0)
	var fade: float = clampf((lifetime - _age) / 0.6, 0.0, 1.0)
	var rx: float = radius * open_t
	var ry: float = radius * 0.28 * open_t
	var line: Color = net_color
	line.a = 0.9 * fade
	var fill: Color = net_color
	fill.a = 0.16 * fade
	var center: Vector2 = Vector2(0.0, -ry * 0.5)
	# Relleno y anillos concéntricos
	var outline: PackedVector2Array = PackedVector2Array()
	for i: int in 33:
		var ang: float = TAU * float(i) / 32.0
		outline.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(outline, fill)
	for ring: int in range(1, 4):
		var k: float = float(ring) / 3.0
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 33:
			var ang: float = TAU * float(i) / 32.0
			pts.append(center + Vector2(cos(ang) * rx * k, sin(ang) * ry * k))
		draw_polyline(pts, line, 1.5)
	# Hilos radiales
	for i: int in 8:
		var ang: float = TAU * float(i) / 8.0
		draw_line(center, center + Vector2(cos(ang) * rx, sin(ang) * ry), line, 1.2)
