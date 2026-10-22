extends Control
## Barra de vida del jefe, arriba al centro de la pantalla. La crea el HUD.
## Aparece cuando un enemigo del grupo `boss` persigue al jugador (o está cerca) y se va cuando muere.
## La vida se lee del HealthComponent del jefe (o de `current_health`/`max_health` si no tiene).
## La franja clara detrás de la roja muestra el daño reciente y baja con retraso.
## Sin class_name a propósito: se carga por preload desde hud.gd.

const BAR_WIDTH: float = 560.0
const BAR_HEIGHT: float = 16.0
const TOP_MARGIN: float = 22.0
## Distancia (px de mundo) a la que aparece sin estar persiguiendo todavía.
const SHOW_RANGE: float = 900.0
const SCAN_INTERVAL: float = 0.25

var _boss: Node2D = null
var _ratio: float = 1.0
var _trail: float = 1.0
var _trail_wait: float = 0.0
var _alpha: float = 0.0
var _scan_left: float = 0.0
var _name: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = SCAN_INTERVAL
		_boss = _find_active_boss()
	var showing: bool = _boss != null and is_instance_valid(_boss) and not _is_dead(_boss)
	if showing:
		var new_ratio: float = _read_ratio(_boss)
		if new_ratio < _ratio:
			_trail_wait = 0.45
		_ratio = new_ratio
		_name = str(_boss.get("entity_name")) if _boss.get("entity_name") != null else "Jefe"
	elif _boss != null and is_instance_valid(_boss):
		_ratio = 0.0
	if _trail_wait > 0.0:
		_trail_wait -= delta
	else:
		_trail = move_toward(_trail, _ratio, delta * 0.8)
	if _trail < _ratio:
		_trail = _ratio
	_alpha = move_toward(_alpha, 1.0 if showing else 0.0, delta * 3.0)
	if _alpha <= 0.0 and not showing:
		_trail = 1.0
		_ratio = 1.0
	queue_redraw()


func _find_active_boss() -> Node2D:
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	var best: Node2D = null
	var best_dist: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"boss"):
		var boss: Node2D = node as Node2D
		if boss == null or _is_dead(boss):
			continue
		var dist: float = boss.global_position.distance_to(player.global_position) if player != null else 0.0
		if boss.get("is_aggroed") != true and dist > SHOW_RANGE:
			continue
		if dist < best_dist:
			best_dist = dist
			best = boss
	return best


func _is_dead(boss: Node) -> bool:
	return boss.get("is_dead") == true or _read_ratio(boss) <= 0.0


func _read_ratio(boss: Node) -> float:
	var hc: HealthComponent = boss.get_node_or_null("HealthComponent") as HealthComponent
	if hc != null and hc.max_health > 0.0:
		return clampf(hc.current_health / hc.max_health, 0.0, 1.0)
	var cur: Variant = boss.get("current_health")
	var mx: Variant = boss.get("max_health")
	if cur != null and mx != null and float(mx) > 0.0:
		return clampf(float(cur) / float(mx), 0.0, 1.0)
	return 1.0


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var width: float = minf(BAR_WIDTH, size.x - 32.0)
	var origin: Vector2 = Vector2((size.x - width) * 0.5, TOP_MARGIN + 22.0)
	var a: float = _alpha
	var font: Font = get_theme_default_font()
	var font_size: int = 18
	var text_w: float = font.get_string_size(_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_pos: Vector2 = Vector2((size.x - text_w) * 0.5, TOP_MARGIN + 14.0)
	draw_string_outline(font, text_pos, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.9 * a))
	draw_string(font, text_pos, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.86, 0.62, a))
	draw_rect(Rect2(origin - Vector2(3, 3), Vector2(width + 6, BAR_HEIGHT + 6)), Color(0.05, 0.03, 0.02, 0.85 * a))
	draw_rect(Rect2(origin, Vector2(width, BAR_HEIGHT)), Color(0.18, 0.06, 0.05, 0.9 * a))
	draw_rect(Rect2(origin, Vector2(width * _trail, BAR_HEIGHT)), Color(1.0, 0.85, 0.55, 0.85 * a))
	draw_rect(Rect2(origin, Vector2(width * _ratio, BAR_HEIGHT)), Color(0.78, 0.1, 0.08, a))
	draw_rect(Rect2(origin, Vector2(width * _ratio, BAR_HEIGHT * 0.35)), Color(1.0, 0.4, 0.35, 0.5 * a))
	draw_rect(Rect2(origin - Vector2(3, 3), Vector2(width + 6, BAR_HEIGHT + 6)), Color(0.72, 0.52, 0.28, a), false, 2.0)
