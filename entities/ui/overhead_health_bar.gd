class_name OverheadHealthBar
extends Node2D
## Componente visual de placa superior (Overhead UI) para entidades de combate.
## Renderiza nombre, barra de vida, barra de escudo y badge de armadura.
## Soporta alternancia global de visibilidad mediante GameManager.overhead_visibility_toggled (tecla F2).
##
## Es UN solo nodo que dibuja todo con `_draw` (antes eran ~9 Controls por enemigo: contenedores, barras y
## etiquetas con su propio layout). Solo se redibuja cuando cambia la vida, el escudo o la armadura.

@export var display_name: String = ""
@export var show_overhead_ui: bool = true
@export var hide_when_full: bool = false
@export var vertical_offset_y: float = -58.0

const BAR_WIDTH: float = 54.0
const HEALTH_HEIGHT: float = 5.0
const SHIELD_HEIGHT: float = 3.0
const BAR_GAP: float = 1.0
const BADGE_GAP: float = 3.0
const BADGE_HEIGHT: float = 11.0
const BADGE_PAD: float = 3.0
const NAME_FONT_SIZE: int = 9
const BADGE_FONT_SIZE: int = 8
const NAME_OUTLINE: int = 3

const NAME_COLOR: Color = Color(0.95, 0.96, 1.0, 1.0)
const NAME_OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const BADGE_TEXT_COLOR: Color = Color(0.85, 0.9, 1.0, 1.0)

var target_health_component: HealthComponent = null
var _current_health: float = 0.0
var _max_health: float = 100.0
var _current_shield: float = 0.0
var _max_shield: float = 0.0
var _armor: float = 0.0
var _is_dead: bool = false
var _fade_tween: Tween = null

static var _font_cache: Font = null
static var _hp_bg: StyleBoxFlat = null
static var _hp_fill: StyleBoxFlat = null
static var _shield_bg: StyleBoxFlat = null
static var _shield_fill: StyleBoxFlat = null
static var _badge_box: StyleBoxFlat = null


func _ready() -> void:
	position.y = vertical_offset_y

	# Conexión al gestor global para alternancia en tiempo real con tecla F2
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal(&"overhead_visibility_toggled"):
		var sig: Signal = gm.overhead_visibility_toggled
		if not sig.is_connected(_on_global_visibility_toggled):
			sig.connect(_on_global_visibility_toggled)
		# Inicializar según el estado global actual
		if "show_overhead_bars" in gm and not bool(gm.get("show_overhead_bars")):
			show_overhead_ui = false

	_update_visibility()


## Configura e inicializa la placa superior con el HealthComponent de la entidad.
func setup(health_comp: HealthComponent, entity_name: String = "") -> void:
	if not entity_name.is_empty():
		display_name = entity_name

	if health_comp == null:
		queue_redraw()
		return

	# Desconectar componente previo si correspondiera
	if target_health_component != null and is_instance_valid(target_health_component):
		if target_health_component.health_changed.is_connected(_on_health_changed):
			target_health_component.health_changed.disconnect(_on_health_changed)
		if target_health_component.shield_changed.is_connected(_on_shield_changed):
			target_health_component.shield_changed.disconnect(_on_shield_changed)
		if target_health_component.died.is_connected(_on_died):
			target_health_component.died.disconnect(_on_died)

	target_health_component = health_comp

	if not target_health_component.health_changed.is_connected(_on_health_changed):
		target_health_component.health_changed.connect(_on_health_changed)
	if not target_health_component.shield_changed.is_connected(_on_shield_changed):
		target_health_component.shield_changed.connect(_on_shield_changed)
	if not target_health_component.died.is_connected(_on_died):
		target_health_component.died.connect(_on_died)

	_max_health = target_health_component.max_health
	_current_health = target_health_component.current_health
	_max_shield = target_health_component.max_shield
	_current_shield = target_health_component.current_shield
	_armor = target_health_component.armor

	_update_visibility()
	queue_redraw()


func _on_health_changed(current: float, max_hp: float) -> void:
	_current_health = current
	_max_health = max_hp
	_update_visibility()
	queue_redraw()


func _on_shield_changed(current: float, max_s: float) -> void:
	_current_shield = current
	_max_shield = max_s
	_update_visibility()
	queue_redraw()


func _on_died() -> void:
	_is_dead = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_fade_tween.tween_callback(func() -> void: visible = false)


func _on_global_visibility_toggled(is_visible: bool) -> void:
	show_overhead_ui = is_visible
	_update_visibility()


func _update_visibility() -> void:
	if _is_dead:
		visible = false
		return

	if not show_overhead_ui:
		visible = false
		return

	if hide_when_full:
		var is_health_full: bool = (_current_health >= _max_health)
		var is_shield_full: bool = (_max_shield <= 0.0 or _current_shield >= _max_shield)
		if is_health_full and is_shield_full:
			visible = false
			return

	visible = true


# ==============================================================================
# Dibujo
# ==============================================================================

static func _font() -> Font:
	if _font_cache == null:
		var probe: Label = Label.new()
		_font_cache = probe.get_theme_default_font()
		probe.free()
	return _font_cache


static func _box(fill: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(2)
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	return box


static func _ensure_boxes() -> void:
	if _hp_bg != null:
		return
	_hp_bg = _box(Color(0.12, 0.08, 0.08, 0.85))
	_hp_fill = _box(Color(0.92, 0.22, 0.22, 1.0))
	_shield_bg = _box(Color(0.08, 0.12, 0.16, 0.8))
	_shield_fill = _box(Color(0.2, 0.75, 1.0, 1.0))
	_badge_box = _box(Color(0.18, 0.22, 0.28, 0.9), Color(0.45, 0.55, 0.7, 0.9), 1)


func _draw_bar(bg: StyleBoxFlat, fill: StyleBoxFlat, rect: Rect2, fraction: float) -> void:
	draw_style_box(bg, rect)
	var width: float = rect.size.x * clampf(fraction, 0.0, 1.0)
	# Un relleno más fino que el radio de las esquinas se dibujaría deforme: se omite
	if width >= 2.0:
		draw_style_box(fill, Rect2(rect.position, Vector2(width, rect.size.y)))


func _draw() -> void:
	_ensure_boxes()
	var font: Font = _font()
	var has_shield: bool = _max_shield > 0.0
	var bars_height: float = HEALTH_HEIGHT + ((BAR_GAP + SHIELD_HEIGHT) if has_shield else 0.0)

	var badge_text: String = ""
	var badge_width: float = 0.0
	if _armor > 0.0:
		badge_text = "ARM: %d" % roundi(_armor)
		badge_width = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT_SIZE).x + BADGE_PAD * 2.0

	var total_width: float = BAR_WIDTH + ((BADGE_GAP + badge_width) if badge_width > 0.0 else 0.0)
	var left: float = -total_width * 0.5
	var top: float = -bars_height

	var y: float = top
	if has_shield:
		_draw_bar(_shield_bg, _shield_fill, Rect2(left, y, BAR_WIDTH, SHIELD_HEIGHT), _current_shield / maxf(1.0, _max_shield))
		y += SHIELD_HEIGHT + BAR_GAP
	_draw_bar(_hp_bg, _hp_fill, Rect2(left, y, BAR_WIDTH, HEALTH_HEIGHT), _current_health / maxf(1.0, _max_health))

	if badge_width > 0.0:
		var badge_rect: Rect2 = Rect2(left + BAR_WIDTH + BADGE_GAP, top + (bars_height - BADGE_HEIGHT) * 0.5, badge_width, BADGE_HEIGHT)
		draw_style_box(_badge_box, badge_rect)
		var badge_baseline: float = badge_rect.position.y + (BADGE_HEIGHT + font.get_ascent(BADGE_FONT_SIZE) - font.get_descent(BADGE_FONT_SIZE)) * 0.5
		draw_string(font, Vector2(badge_rect.position.x + BADGE_PAD, badge_baseline), badge_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT_SIZE, BADGE_TEXT_COLOR)

	if not display_name.is_empty():
		var name_pos: Vector2 = Vector2(-BAR_WIDTH * 0.5 - 20.0, top - 3.0)
		var name_box: float = BAR_WIDTH + 40.0
		draw_string_outline(font, name_pos, display_name, HORIZONTAL_ALIGNMENT_CENTER, name_box, NAME_FONT_SIZE,
				NAME_OUTLINE, NAME_OUTLINE_COLOR)
		draw_string(font, name_pos, display_name, HORIZONTAL_ALIGNMENT_CENTER, name_box, NAME_FONT_SIZE, NAME_COLOR)
