extends Area2D

const FireVfx = preload("res://combat/fire_vfx.gd")
const SfxScript = preload("res://core/sfx.gd")
## Charco de fuego del lanzallamas de combustible. Quema (burn) con ticks a quien lo pisa.
## Visual: sprites animados o partículas según el ajuste gráfico (ver FireVfx).

@export var lifetime: float = 5.0
@export var tick_interval: float = 0.4
@export var tick_damage: float = 4.0
@export var pool_width: float = 64.0
@export var pool_height: float = 20.0

var source_node: Node2D = null

var _age: float = 0.0
var _tick_timer: float = 0.1
var _visual: Node2D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 5

	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(pool_width, pool_height)
	shape_node.shape = rect
	shape_node.position = Vector2(0.0, -pool_height * 0.5)
	add_child(shape_node)
	
	_visual = FireVfx.make("pool", pool_width * 1.1, true)
	add_child(_visual)
	SfxScript.play(self, &"fire_ignite", global_position, -6.0, randf_range(0.9, 1.1))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_tick()

	var fade: float = clampf((lifetime - _age) / 0.8, 0.0, 1.0)
	_visual.modulate.a = fade


func _apply_tick() -> void:
	var targets: Array[Node2D] = ThrowableUtil.collect_hostile_targets(self)
	for target in targets:
		if not is_instance_valid(target):
			continue
		var effects: Array[String] = ["FIRE"]
		var payload: HitPayload = HitPayload.new(
			tick_damage,
			0.0,
			Vector2.ZERO,
			source_node,
			effects,
			1,
			0.0,
			0.0
		)
		ThrowableUtil.deliver_hit(target, payload)

