extends RefCounted
## Paleta, tema e íconos de la cinta de opciones (`ui/debug/ribbon.gd`).
## Sin class_name a propósito: se carga por `preload` (ver class-name-cache-gotcha).
##
## - `theme()`: un único `Theme` para toda la cinta (botones, casillas, desplegables, pestañas, tooltips, barras de scroll).
##   Variaciones de botón: "RibbonTab" (pestaña), "RibbonChip" (opción de un selector segmentado), "RibbonPrimary"
##   (acción principal, color de acento), "RibbonDanger" (acción destructiva).
## - `icon(nombre)`: íconos de trazo dibujados con SVG (se tiñen con el color del botón). Para sumar uno, agregarlo a ICONS.

const BG_DEEP: Color = Color(0.063, 0.071, 0.086, 1.0)
const BG_BAR: Color = Color(0.094, 0.106, 0.129, 1.0)
const BG_BODY: Color = Color(0.137, 0.153, 0.180, 1.0)
const BG_CONTROL: Color = Color(0.180, 0.200, 0.235, 1.0)
const BG_HOVER: Color = Color(0.235, 0.263, 0.310, 1.0)
const BORDER: Color = Color(0.260, 0.290, 0.340, 1.0)
const TEXT: Color = Color(0.870, 0.880, 0.910, 1.0)
const TEXT_DIM: Color = Color(0.550, 0.580, 0.640, 1.0)
const ACCENT: Color = Color(0.950, 0.580, 0.220, 1.0)
const ACCENT_DIM: Color = Color(0.620, 0.370, 0.150, 1.0)
const GOOD: Color = Color(0.440, 0.810, 0.590, 1.0)
const WARN: Color = Color(0.950, 0.790, 0.300, 1.0)
const BAD: Color = Color(0.920, 0.340, 0.340, 1.0)

## Contenido SVG (viewBox 24x24, trazo blanco de 2 px) de cada ícono.
const ICONS: Dictionary = {
	"plus": "<path d='M12 5v14M5 12h14'/>",
	"kill": "<circle cx='12' cy='12' r='9'/><path d='M9 9l6 6M15 9l-6 6'/>",
	"bolt": "<path d='M13 3L5 14h6l-1 7 8-11h-6z'/>",
	"trash": "<path d='M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13'/>",
	"exit": "<path d='M10 4H5v16h5M14 8l4 4-4 4M18 12H9'/>",
	"folder": "<path d='M3 7h6l2 2h10v10H3z'/>",
	"chart": "<path d='M4 4v16h16M8 16v-5M12 16V8M16 16v-8'/>",
	"heart": "<path d='M12 20s-7-4.5-7-10a4 4 0 0 1 7-2 4 4 0 0 1 7 2c0 5.5-7 10-7 10z'/>",
	"snow": "<path d='M12 3v18M4.2 7.5l15.6 9M19.8 7.5l-15.6 9'/>",
	"sweep": "<path d='M4 12a8 8 0 0 1 14-5.3M20 4v5h-5M20 12a8 8 0 0 1-14 5.3M4 20v-5h5'/>",
	"list": "<path d='M5 6h14M5 12h14M5 18h9'/>",
	"pin": "<path d='M12 21s-6-6-6-11a6 6 0 0 1 12 0c0 5-6 11-6 11z'/><circle cx='12' cy='10' r='2'/>",
	"crosshair": "<circle cx='12' cy='12' r='7'/><path d='M12 2v5M12 17v5M2 12h5M17 12h5'/>",
	"up": "<path d='M6 15l6-6 6 6'/>",
	"down": "<path d='M6 9l6 6 6-6'/>",
}

static var _theme: Theme = null
static var _icons: Dictionary = {}


## Rectángulo plano. `margins` = (izquierda, arriba, derecha, abajo) de contenido.
static func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0, radius: int = 3,
		margins: Vector4 = Vector4(8, 3, 8, 3)) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	return style


static func icon(icon_name: String, scale: float = 1.0) -> Texture2D:
	var key: String = "%s@%.2f" % [icon_name, scale]
	if _icons.has(key):
		return _icons[key] as Texture2D
	if not ICONS.has(icon_name):
		return null
	var svg: String = ("<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' "
			+ "stroke='white' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>%s</svg>") % str(ICONS[icon_name])
	var image: Image = Image.new()
	var texture: Texture2D = null
	if image.load_svg_from_string(svg, scale) == OK:
		texture = ImageTexture.create_from_image(image)
	_icons[key] = texture
	return texture


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Inter", "Roboto", "Helvetica Neue", "Arial"])
	t.default_font = font
	t.default_font_size = 12

	_style_button(t, "Button")
	_style_button(t, "OptionButton")
	t.set_constant("arrow_margin", "OptionButton", 6)

	# Pestaña: la activa se funde con el cuerpo de la cinta y lleva un filo de acento arriba
	t.set_type_variation("RibbonTab", "Button")
	t.set_stylebox("normal", "RibbonTab", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, Vector4(12, 5, 12, 5)))
	t.set_stylebox("hover", "RibbonTab", box(BG_CONTROL, Color(0, 0, 0, 0), 0, 0, Vector4(12, 5, 12, 5)))
	var tab_on: StyleBoxFlat = box(BG_BODY, ACCENT, 0, 0, Vector4(12, 5, 12, 5))
	tab_on.border_width_top = 2
	t.set_stylebox("pressed", "RibbonTab", tab_on)
	t.set_stylebox("hover_pressed", "RibbonTab", tab_on)
	t.set_color("font_color", "RibbonTab", TEXT_DIM)
	t.set_color("font_hover_color", "RibbonTab", TEXT)
	t.set_color("font_pressed_color", "RibbonTab", ACCENT)
	t.set_color("font_hover_pressed_color", "RibbonTab", ACCENT)

	# Opción de un selector segmentado
	t.set_type_variation("RibbonChip", "Button")
	t.set_stylebox("normal", "RibbonChip", box(BG_CONTROL, BORDER, 1, 3, Vector4(7, 2, 7, 2)))
	t.set_stylebox("hover", "RibbonChip", box(BG_HOVER, BORDER, 1, 3, Vector4(7, 2, 7, 2)))
	t.set_stylebox("pressed", "RibbonChip", box(ACCENT_DIM, ACCENT, 1, 3, Vector4(7, 2, 7, 2)))
	t.set_stylebox("hover_pressed", "RibbonChip", box(ACCENT_DIM, ACCENT, 1, 3, Vector4(7, 2, 7, 2)))
	t.set_color("font_pressed_color", "RibbonChip", Color(1, 1, 1, 1))
	t.set_color("font_hover_pressed_color", "RibbonChip", Color(1, 1, 1, 1))

	# Acción principal y acción destructiva (botones grandes)
	_style_filled(t, "RibbonPrimary", Color(0.78, 0.43, 0.14, 1.0), ACCENT)
	_style_filled(t, "RibbonDanger", Color(0.55, 0.17, 0.17, 1.0), BAD)

	# Casillas de verificación con íconos propios (cuadro redondeado, con tilde sobre el color de acento)
	var unchecked: Texture2D = _svg_texture("<rect x='1.5' y='1.5' width='13' height='13' rx='3' fill='#1b1e24' stroke='#6b7380' stroke-width='1.5'/>")
	var checked: Texture2D = _svg_texture("<rect x='1' y='1' width='14' height='14' rx='3.5' fill='#f2943a'/>"
			+ "<path d='M4.3 8.3 L7 11 L11.8 5.2' fill='none' stroke='white' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/>")
	if unchecked != null and checked != null:
		t.set_icon("unchecked", "CheckBox", unchecked)
		t.set_icon("checked", "CheckBox", checked)
		t.set_icon("unchecked_disabled", "CheckBox", unchecked)
		t.set_icon("checked_disabled", "CheckBox", checked)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color(1, 1, 1, 1))
	t.set_color("font_pressed_color", "CheckBox", TEXT)
	t.set_color("font_hover_pressed_color", "CheckBox", Color(1, 1, 1, 1))
	t.set_constant("h_separation", "CheckBox", 7)

	t.set_color("font_color", "Label", TEXT)

	# Menú desplegable
	t.set_stylebox("panel", "PopupMenu", box(BG_BAR, BORDER, 1, 3, Vector4(4, 4, 4, 4)))
	t.set_stylebox("hover", "PopupMenu", box(ACCENT_DIM, Color(0, 0, 0, 0), 0, 2, Vector4(4, 2, 4, 2)))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 1, 1, 1))
	t.set_constant("v_separation", "PopupMenu", 6)

	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", box(BG_DEEP, ACCENT_DIM, 1, 3, Vector4(8, 5, 8, 5)))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 12)

	# Separadores y barras de desplazamiento (finas)
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = BORDER
	line.thickness = 1
	line.vertical = true
	t.set_stylebox("separator", "VSeparator", line)
	t.set_constant("separation", "VSeparator", 9)
	t.set_stylebox("scroll", "HScrollBar", box(BG_DEEP, Color(0, 0, 0, 0), 0, 2, Vector4(0, 0, 0, 0)))
	t.set_stylebox("grabber", "HScrollBar", box(BG_HOVER, Color(0, 0, 0, 0), 0, 2, Vector4(0, 0, 0, 0)))
	t.set_stylebox("grabber_highlight", "HScrollBar", box(ACCENT_DIM, Color(0, 0, 0, 0), 0, 2, Vector4(0, 0, 0, 0)))
	t.set_stylebox("grabber_pressed", "HScrollBar", box(ACCENT, Color(0, 0, 0, 0), 0, 2, Vector4(0, 0, 0, 0)))

	_theme = t
	return t


static func _style_button(t: Theme, type_name: String) -> void:
	t.set_stylebox("normal", type_name, box(BG_CONTROL, BORDER, 1, 3, Vector4(9, 3, 9, 3)))
	t.set_stylebox("hover", type_name, box(BG_HOVER, Color(0.38, 0.42, 0.49, 1.0), 1, 3, Vector4(9, 3, 9, 3)))
	t.set_stylebox("pressed", type_name, box(Color(0.12, 0.13, 0.16, 1.0), ACCENT, 1, 3, Vector4(9, 3, 9, 3)))
	t.set_stylebox("hover_pressed", type_name, box(Color(0.12, 0.13, 0.16, 1.0), ACCENT, 1, 3, Vector4(9, 3, 9, 3)))
	t.set_stylebox("disabled", type_name, box(BG_BODY, BORDER, 1, 3, Vector4(9, 3, 9, 3)))
	t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	t.set_color("font_color", type_name, TEXT)
	t.set_color("font_hover_color", type_name, Color(1, 1, 1, 1))
	t.set_color("font_pressed_color", type_name, TEXT)
	t.set_color("font_hover_pressed_color", type_name, TEXT)
	t.set_color("font_disabled_color", type_name, TEXT_DIM)
	t.set_color("icon_normal_color", type_name, TEXT)
	t.set_color("icon_hover_color", type_name, Color(1, 1, 1, 1))
	t.set_color("icon_pressed_color", type_name, ACCENT)
	t.set_constant("h_separation", type_name, 6)


## Botón grande relleno (acción principal / destructiva): mismo molde, distinto color.
static func _style_filled(t: Theme, variation: String, fill: Color, edge: Color) -> void:
	t.set_type_variation(variation, "Button")
	var margins: Vector4 = Vector4(10, 6, 10, 6)
	t.set_stylebox("normal", variation, box(fill, edge, 1, 4, margins))
	t.set_stylebox("hover", variation, box(fill.lightened(0.16), edge, 1, 4, margins))
	t.set_stylebox("pressed", variation, box(fill.darkened(0.25), edge, 1, 4, margins))
	t.set_stylebox("hover_pressed", variation, box(fill.darkened(0.25), edge, 1, 4, margins))
	t.set_color("font_color", variation, Color(1, 1, 1, 1))
	t.set_color("font_hover_color", variation, Color(1, 1, 1, 1))
	t.set_color("font_pressed_color", variation, Color(1, 1, 1, 1))
	t.set_color("icon_normal_color", variation, Color(1, 1, 1, 1))
	t.set_color("icon_hover_color", variation, Color(1, 1, 1, 1))
	t.set_color("icon_pressed_color", variation, Color(1, 1, 1, 1))


static func _svg_texture(content: String) -> Texture2D:
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'>%s</svg>" % content
	var image: Image = Image.new()
	if image.load_svg_from_string(svg, 1.0) != OK:
		return null
	return ImageTexture.create_from_image(image)
