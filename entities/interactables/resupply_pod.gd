extends Area2D
## Pod de reabastecimiento del Sandbox: mientras el jugador está parado encima, regenera
## vida, munición o cargas de arrojadizos. El pod DRAIN hace lo contrario (quita vida sin
## matar) para poder probar el de vida, porque en el Sandbox el jugador es invulnerable.
## Se arma todo por código: `ResupplyPod.new()`, fijar `kind` y agregarlo al árbol.

enum Kind { HEALTH, AMMO, GEAR, DRAIN }

const TICK: float = 0.25
## Fracción de la vida máxima curada por tick (~1/3 por segundo).
const HEAL_PER_TICK: float = 0.08
## Fracción de cargador repuesta por tick en cada arma (cargador primero, después reserva).
const AMMO_PER_TICK: float = 0.25
## Segundos de recarga de arrojadizos que adelanta cada tick (x6 de la velocidad normal).
const GEAR_SECONDS_PER_TICK: float = 1.5
const DRAIN_PER_TICK: float = 6.0

const NAMES: Array[String] = ["Vida", "Munición", "Granadas", "Daño"]
const COLORS: Array[Color] = [
	Color(0.35, 1.0, 0.45),
	Color(1.0, 0.78, 0.25),
	Color(0.4, 0.75, 1.0),
	Color(1.0, 0.25, 0.2),
]

@export var kind: Kind = Kind.HEALTH

var _player: Player = null
var _tick_left: float = 0.0
var _time: float = 0.0
## 0..1: qué tan encendido está (sube al pararse encima, baja al salir).
var _glow: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(52.0, 70.0)
	shape_node.shape = rect
	shape_node.position = Vector2(0.0, -35.0)
	add_child(shape_node)

	var label: Label = Label.new()
	label.text = NAMES[kind]
	label.position = Vector2(-30.0, -110.0)
	label.custom_minimum_size = Vector2(60.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", COLORS[kind])
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)


func _process(delta: float) -> void:
	_time += delta
	_glow = move_toward(_glow, 1.0 if _player != null else 0.0, delta * 4.0)
	if _player != null:
		_tick_left -= delta
		if _tick_left <= 0.0:
			_tick_left += TICK
			_apply_tick()
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player
		_tick_left = 0.0


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


func _apply_tick() -> void:
	match kind:
		Kind.HEALTH:
			var stats: StatsManager = _player.stats_manager
			if stats != null and stats.current_health < stats.get_max_health():
				stats.heal(stats.get_max_health() * HEAL_PER_TICK)
		Kind.AMMO:
			var wm: WeaponManager = _player.weapon_manager
			if wm != null:
				wm.restock_ammo(AMMO_PER_TICK)
				if wm.offhand != null:
					wm.offhand.restock_ammo(AMMO_PER_TICK)
		Kind.GEAR:
			var tm: Node = _player.get_node_or_null("ThrowableManager")
			if tm != null and tm.has_method("restock"):
				tm.call("restock", GEAR_SECONDS_PER_TICK)
		Kind.DRAIN:
			# Directo a StatsManager: saltea la invulnerabilidad del Sandbox y nunca baja de 1.
			var stats: StatsManager = _player.stats_manager
			if stats != null and stats.current_health > 1.0:
				stats.take_damage(minf(DRAIN_PER_TICK, stats.current_health - 1.0))


func _draw() -> void:
	var col: Color = COLORS[kind]
	var g: float = _glow
	# Columna de luz: capas translúcidas que se angostan hacia arriba
	for i: int in 4:
		var w: float = 40.0 - float(i) * 9.0
		var a: float = (0.05 + 0.1 * g) * (1.0 + 0.25 * sin(_time * 3.0 + float(i)))
		draw_rect(Rect2(-w * 0.5, -86.0, w, 78.0), Color(col, a))
	# Partículas que suben (más rápidas y brillantes con el jugador encima)
	var rise: float = 30.0 + 60.0 * g
	for i: int in 6:
		var phase: float = fposmod(_time * rise / 80.0 + float(i) / 6.0, 1.0)
		var x: float = sin(float(i) * 2.3 + _time) * 14.0
		var y: float = -10.0 - phase * 76.0
		draw_circle(Vector2(x, y), 1.5 + g, Color(col, (1.0 - phase) * (0.35 + 0.6 * g)))
	# Base metálica y emisor
	draw_rect(Rect2(-28.0, -10.0, 56.0, 10.0), Color(0.16, 0.17, 0.2))
	draw_rect(Rect2(-28.0, -10.0, 56.0, 2.0), Color(0.32, 0.34, 0.38))
	draw_rect(Rect2(-20.0, -13.0, 40.0, 3.0), col.lerp(Color.WHITE, 0.3 * g))
	# Emisor superior con el símbolo
	draw_rect(Rect2(-22.0, -94.0, 44.0, 6.0), Color(0.16, 0.17, 0.2))
	draw_rect(Rect2(-16.0, -88.0, 32.0, 2.0), col.lerp(Color.WHITE, 0.3 * g))
	_draw_symbol(Vector2(0.0, -50.0), col.lerp(Color.WHITE, 0.5 * g))


func _draw_symbol(c: Vector2, col: Color) -> void:
	var s: Color = Color(col, 0.55 + 0.45 * _glow)
	match kind:
		Kind.HEALTH:
			draw_rect(Rect2(c.x - 3.0, c.y - 9.0, 6.0, 18.0), s)
			draw_rect(Rect2(c.x - 9.0, c.y - 3.0, 18.0, 6.0), s)
		Kind.AMMO:
			for dx: float in [-7.0, 0.0, 7.0]:
				draw_rect(Rect2(c.x + dx - 2.0, c.y - 4.0, 4.0, 12.0), s)
				draw_circle(Vector2(c.x + dx, c.y - 4.0), 2.0, s)
		Kind.GEAR:
			draw_circle(c + Vector2(0.0, 2.0), 7.0, s)
			draw_rect(Rect2(c.x - 3.0, c.y - 9.0, 6.0, 4.0), s)
		Kind.DRAIN:
			draw_line(c + Vector2(-8.0, -8.0), c + Vector2(8.0, 8.0), s, 4.0)
			draw_line(c + Vector2(8.0, -8.0), c + Vector2(-8.0, 8.0), s, 4.0)
