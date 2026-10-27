extends Control
## Escenario de pantalla de una cinemática: fondo, sprites de pantalla, barras negras, subtítulo,
## título, destello, fundido y la ayuda de teclas. Solo arma y expone los nodos; los comandos los animan.
## Orden de dibujo (de atrás hacia adelante): fondo, sprites, barras, subtítulo, título, destello, fundido, ayuda.

const BAR_HEIGHT: float = 64.0
const HINT_TEXT: String = "[Enter] avanzar   [Esc] saltar   mantener [R] saltar"

var bg: TextureRect
var sprites: Control
var bar_top: ColorRect
var bar_bottom: ColorRect
## Subtítulo de los diálogos: solo el texto, sin fondo ni nombre.
var subtitle: Label
var title_label: Label
var flash: ColorRect
var fade: ColorRect
var hint: Label

var _sprites_by_id: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	bg = TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.visible = false
	_add_full(bg)

	sprites = Control.new()
	_add_full(sprites)

	bar_top = _make_bar(true)
	bar_bottom = _make_bar(false)

	subtitle = Label.new()
	subtitle.anchor_left = 0.5
	subtitle.anchor_right = 0.5
	subtitle.anchor_top = 1.0
	subtitle.anchor_bottom = 1.0
	subtitle.offset_left = -460.0
	subtitle.offset_right = 460.0
	subtitle.offset_top = -BAR_HEIGHT - 90.0
	subtitle.offset_bottom = -BAR_HEIGHT - 12.0
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	subtitle.add_theme_constant_override("outline_size", 6)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.visible = false
	add_child(subtitle)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.modulate.a = 0.0
	_add_full(title_label)

	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	_add_full(flash)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	_add_full(fade)

	hint = Label.new()
	hint.text = HINT_TEXT
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -360.0
	hint.offset_top = -BAR_HEIGHT + 8.0
	hint.offset_right = -12.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _add_full(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)


func _make_bar(top: bool) -> ColorRect:
	var bar: ColorRect = ColorRect.new()
	bar.color = Color.BLACK
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.0 if top else 1.0
	bar.anchor_bottom = 0.0 if top else 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	return bar




# ==============================================================================
# API para los comandos
# ==============================================================================



## Solo el texto, centrado abajo, sin fondo ni nombre.
func show_subtitle(text: String) -> void:
	subtitle.text = text
	subtitle.visible = true


func hide_line() -> void:
	subtitle.visible = false


## Sprite fijo en pantalla. Reemplaza al que tenga el mismo id.
func add_sprite(id: String, rect: Control) -> void:
	remove_sprite(id)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprites.add_child(rect)
	_sprites_by_id[id] = rect


func remove_sprite(id: String) -> void:
	var found: Variant = _sprites_by_id.get(id, null)
	if found != null and is_instance_valid(found):
		(found as Node).queue_free()
	_sprites_by_id.erase(id)


func get_sprite(id: String) -> Control:
	var found: Variant = _sprites_by_id.get(id, null)
	return found as Control if found != null and is_instance_valid(found) else null
