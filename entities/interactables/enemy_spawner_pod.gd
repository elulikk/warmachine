extends Area2D
## Pod spawner del Sandbox: parado encima, [E] invoca un enemigo de `enemy_scene` a cierta distancia,
## del lado al que mira el jugador (o del otro si ahí hay pared). Sin escena, el pod limpia la zona
## (mata a todo lo invocado y a los enemigos sueltos, como la tecla K).
## Se arma por código: `EnemySpawnerPod.new()`, fijar los campos y agregarlo al árbol.

const SPAWN_DISTANCE: float = 280.0
const SPAWN_MIN_X: float = -200.0
const SPAWN_MAX_X: float = 5100.0
## Las ratas de techo nacen pegadas al piso de la Sala de Movilidad (el "techo" sobre el inicio).
const CEILING_MIN_X: float = -400.0
const CEILING_MAX_X: float = 400.0
const CEILING_Y: float = 385.0
const SPAWN_COLOR: Color = Color(0.85, 0.35, 1.0)
const CLEAR_COLOR: Color = Color(1.0, 0.3, 0.25)

@export var enemy_scene: PackedScene = null
@export var label_text: String = ""
## true para enemigos que viven colgados del techo.
@export var ceiling: bool = false

var _player: Player = null
var _time: float = 0.0
var _glow: float = 0.0
## Destello al invocar (1 → 0).
var _flash: float = 0.0
var _count_label: Label = null
var _spawned: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(44.0, 70.0)
	shape_node.shape = rect
	shape_node.position = Vector2(0.0, -35.0)
	add_child(shape_node)
	# Nombre apoyado sobre el emisor (los de dos renglones crecen hacia arriba) y el aviso de [E] encima
	var name_top: float = -100.0 - 14.0 * float(label_text.count("
") + 1)
	_make_label(label_text, Vector2(-32.0, name_top), 10, _color())
	_count_label = _make_label("[E]", Vector2(-32.0, name_top - 15.0), 10, Color(1.0, 0.95, 0.6))
	_count_label.visible = false


func _make_label(text_value: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.position = pos
	label.custom_minimum_size = Vector2(64.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	return label


func _color() -> Color:
	return SPAWN_COLOR if enemy_scene != null else CLEAR_COLOR


func _process(delta: float) -> void:
	_time += delta
	_glow = move_toward(_glow, 1.0 if _player != null else 0.0, delta * 4.0)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _player != null and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if enemy_scene != null:
			_spawn()
		else:
			_clear()
		_flash = 1.0


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player
		_count_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		_count_label.visible = false


func _spawn() -> void:
	var enemy: Node2D = enemy_scene.instantiate() as Node2D
	if enemy == null:
		return
	var level: Node = get_parent()
	level.add_child(enemy)
	var dir: float = float(_player.facing_direction)
	var x: float = _player.global_position.x + dir * SPAWN_DISTANCE
	if ceiling:
		if x < CEILING_MIN_X or x > CEILING_MAX_X:
			x = _player.global_position.x - dir * SPAWN_DISTANCE
		enemy.global_position = Vector2(clampf(x, CEILING_MIN_X, CEILING_MAX_X), CEILING_Y)
	else:
		if x < SPAWN_MIN_X or x > SPAWN_MAX_X:
			x = _player.global_position.x - dir * SPAWN_DISTANCE
		enemy.global_position = Vector2(clampf(x, SPAWN_MIN_X, SPAWN_MAX_X), global_position.y - 8.0)
	_spawned += 1
	_count_label.text = "[E] x%d" % _spawned


func _clear() -> void:
	var level: Node = get_parent()
	if level != null and level.has_method("_kill_all_enemies"):
		level.call("_kill_all_enemies")


func _draw() -> void:
	var col: Color = _color()
	var g: float = maxf(_glow, _flash)
	# Columna de luz
	for i: int in 3:
		var w: float = 32.0 - float(i) * 9.0
		var a: float = (0.05 + 0.1 * g + 0.25 * _flash) * (1.0 + 0.25 * sin(_time * 3.0 + float(i)))
		draw_rect(Rect2(-w * 0.5, -86.0, w, 78.0), Color(col, a))
	# Partículas que bajan (el pod "materializa")
	for i: int in 5:
		var phase: float = fposmod(_time * (0.4 + 0.6 * g) + float(i) / 5.0, 1.0)
		var x: float = sin(float(i) * 2.1 + _time * 1.3) * 11.0
		draw_circle(Vector2(x, -86.0 + phase * 76.0), 1.5 + g, Color(col, phase * (0.3 + 0.6 * g)))
	# Base y emisor superior
	draw_rect(Rect2(-24.0, -10.0, 48.0, 10.0), Color(0.16, 0.14, 0.2))
	draw_rect(Rect2(-24.0, -10.0, 48.0, 2.0), Color(0.34, 0.3, 0.4))
	draw_rect(Rect2(-17.0, -13.0, 34.0, 3.0), col.lerp(Color.WHITE, 0.3 * g))
	draw_rect(Rect2(-20.0, -94.0, 40.0, 6.0), Color(0.16, 0.14, 0.2))
	draw_rect(Rect2(-14.0, -88.0, 28.0, 2.0), col.lerp(Color.WHITE, 0.3 * g))
	# Símbolo: calavera simple (invocar) o X (limpiar)
	var c: Vector2 = Vector2(0.0, -54.0)
	var s: Color = Color(col.lerp(Color.WHITE, 0.5 * g), 0.55 + 0.45 * g)
	if enemy_scene != null:
		draw_circle(c, 8.0, s)
		draw_rect(Rect2(c.x - 5.0, c.y + 5.0, 10.0, 6.0), s)
		draw_circle(c + Vector2(-3.0, -1.0), 2.2, Color(0.1, 0.05, 0.12))
		draw_circle(c + Vector2(3.0, -1.0), 2.2, Color(0.1, 0.05, 0.12))
	else:
		draw_line(c + Vector2(-8.0, -8.0), c + Vector2(8.0, 8.0), s, 4.0)
		draw_line(c + Vector2(8.0, -8.0), c + Vector2(-8.0, 8.0), s, 4.0)
