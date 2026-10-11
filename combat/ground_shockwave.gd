class_name GroundShockwave
extends Area2D
## Onda de expansión física en el suelo generada por impactos contundentes (ej. Martillo Pesado).
## Se expande horizontalmente 120px a cada lado (ancho total 240px, altura 32px), inflige 25 DMG
## y aplica el estado "STUN" durante 1.5s a todos los enemigos en el piso dentro de su alcance.

@export var damage: float = 25.0
@export var stun_duration: float = 1.5
@export var half_width: float = 120.0
@export var height: float = 32.0
@export var duration: float = 0.35
@export var shockwave_color: Color = Color(1.0, 0.85, 0.3, 1.0)

var source_node: Node2D = null
var _progress: float = 0.0
var _hit_targets: Array[Node] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detecta capas de enemigos y hurtboxes
	monitoring = true
	monitorable = false
	
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect_shape: RectangleShape2D = RectangleShape2D.new()
	rect_shape.size = Vector2(half_width * 2.0, height)
	shape_node.shape = rect_shape
	shape_node.position = Vector2(0.0, -height * 0.5)
	add_child(shape_node)
	
	body_entered.connect(_on_target_entered)
	area_entered.connect(_on_target_entered)
	
	_animate_shockwave()


func _animate_shockwave() -> void:
	var tw: Tween = create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(queue_free)
	
	# Chequeo inicial diferido para atrapar superposiciones que ya estaban tocando el área
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_inside_tree():
		var targets: Array[Node2D] = ThrowableUtil.collect_hostile_targets(self)
		for t in targets:
			_hit_target(t)


func _on_target_entered(node: Node) -> void:
	var target: Node2D = ThrowableUtil.resolve_hostile_target(node)
	if target != null:
		_hit_target(target)


func _hit_target(target: Node2D) -> void:
	if target == null or not is_instance_valid(target) or _hit_targets.has(target):
		return
	_hit_targets.append(target)
	
	# Calcular empuje ligero hacia afuera y ascendente
	var diff_x: float = target.global_position.x - global_position.x
	var push_dir: Vector2 = Vector2(signf(diff_x) if absf(diff_x) > 4.0 else 1.0, -0.6).normalized()
	
	var payload: HitPayload = HitPayload.new(
		damage,
		240.0,
		push_dir,
		source_node,
		["STUN"],
		1,
		stun_duration,
		0.15
	)
	ThrowableUtil.deliver_hit(target, payload)
	
	# Garantizar aplicación directa de stun si el target posee StatusReceiverComponent
	var receiver: StatusReceiverComponent = ThrowableUtil.get_status_receiver(target)
	if receiver != null:
		receiver.apply_stun(stun_duration)


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	var current_w: float = half_width * _progress
	var alpha: float = 1.0 - _progress
	
	# Onda de polvo y energía que se propaga a izquierda y derecha
	var wave_col: Color = shockwave_color
	wave_col.a = 0.7 * alpha
	
	# Línea frontal de choque en el suelo
	draw_line(Vector2(-current_w, -2.0), Vector2(current_w, -2.0), wave_col, 4.0)
	
	# Picos/rocas estilizadas que se elevan
	var steps: int = 8
	var step_w: float = current_w / float(steps)
	for i in range(1, steps + 1):
		var x_pos: float = float(i) * step_w
		var spike_h: float = (height * 0.75) * (1.0 - float(i) / float(steps * 1.2)) * alpha
		# Lado derecho
		draw_line(Vector2(x_pos, 0.0), Vector2(x_pos, -spike_h), wave_col, 3.0)
		# Lado izquierdo
		draw_line(Vector2(-x_pos, 0.0), Vector2(-x_pos, -spike_h), wave_col, 3.0)
	
	# Relleno de resplandor central en el punto de impacto
	var core_col: Color = Color(1.0, 1.0, 0.8, 0.5 * alpha)
	draw_circle(Vector2(0.0, -4.0), 16.0 * (1.0 - _progress * 0.5), core_col)
