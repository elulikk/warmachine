extends RefCounted
## Aspecto steampunk de la interfaz (texturas de `assets/art/ui/`, extraídas de las hojas de UI).
## Sin class_name a propósito: se carga por `preload` (ver DraggableWindow, ItemSlot y HUD).
##
## - Fábrica de estilos: `window_style()`, `slot_style()`, `inset_style()`, `button_style()`, `parchment_style()`.
## - `skin_tree(raíz)` recorre una ventana y cambia paneles, botones y rótulos genéricos al nuevo aspecto
##   sin tocar cada escena; se vuelve a llamar al mostrar la ventana por si se agregaron nodos por código.
## Si falta alguna textura, cae a un `StyleBoxFlat` de colores cobre/madera para que nada quede sin marco.

const ArtScript = preload("res://core/art/art.gd")

const UI_DIR: String = "res://assets/art/ui/"

const COLOR_TEXT: Color = Color(0.96, 0.88, 0.70, 1.0)
const COLOR_TEXT_DIM: Color = Color(0.74, 0.64, 0.50, 1.0)
const COLOR_GOLD: Color = Color(1.0, 0.82, 0.36, 1.0)
const COLOR_TITLE: Color = Color(0.98, 0.86, 0.60, 1.0)
const COLOR_OUTLINE: Color = Color(0.10, 0.06, 0.04, 1.0)
const COLOR_PARCHMENT_TEXT: Color = Color(0.20, 0.12, 0.06, 1.0)
const COLOR_WOOD: Color = Color(0.23, 0.16, 0.13, 1.0)
const COLOR_COPPER: Color = Color(0.72, 0.43, 0.28, 1.0)

static var _styles: Dictionary = {}
static var _title_font: Font = null


## Marco de ventana (9-slice). Los márgenes de contenido dejan el interior libre de remaches.
static func window_style() -> StyleBox:
	if _styles.has("window"):
		return _styles["window"] as StyleBox
	var box: StyleBox = _texture_box("win_frame.png", Vector4(17, 40, 17, 17), Vector4(15, 6, 15, 14),
			_flat_fallback(Color(0.2, 0.14, 0.11, 0.97), COLOR_COPPER, 3, 6))
	_styles["window"] = box
	return box


## Casillero de cuero para ítems.
static func slot_style() -> StyleBox:
	if _styles.has("slot"):
		return _styles["slot"] as StyleBox
	var box: StyleBox = _texture_box("slot_leather.png", Vector4(9, 9, 9, 9), Vector4(3, 3, 3, 3),
			_flat_fallback(Color(0.30, 0.18, 0.12, 1.0), Color(0.45, 0.28, 0.18, 1.0), 1, 4))
	_styles["slot"] = box
	return box


## Panel interior oscuro (secciones dentro de una ventana).
static func inset_style() -> StyleBox:
	if _styles.has("inset"):
		return _styles["inset"] as StyleBox
	var box: StyleBox = _texture_box("inset_dark.png", Vector4(10, 10, 10, 10), Vector4(8, 6, 8, 8),
			_flat_fallback(Color(0.18, 0.13, 0.11, 0.95), Color(0.10, 0.07, 0.05, 1.0), 2, 6))
	_styles["inset"] = box
	return box


## Pergamino (tooltips, fichas de estadísticas).
static func parchment_style() -> StyleBox:
	if _styles.has("parchment"):
		return _styles["parchment"] as StyleBox
	var box: StyleBox = _texture_box("parchment.png", Vector4(18, 16, 18, 16), Vector4(12, 10, 12, 10),
			_flat_fallback(Color(0.90, 0.80, 0.58, 1.0), Color(0.45, 0.30, 0.15, 1.0), 2, 3))
	_styles["parchment"] = box
	return box


## Botón de placa. `kind`: "copper" (por defecto), "dark" o "plate". `state`: normal, hover, pressed, disabled.
static func button_style(kind: String = "copper", state: String = "normal") -> StyleBox:
	var key: String = "btn_%s_%s" % [kind, state]
	if _styles.has(key):
		return _styles[key] as StyleBox
	var files: Dictionary = {"copper": "btn_copper.png", "dark": "btn_dark.png", "plate": "btn_plate.png"}
	var file: String = str(files.get(kind, "btn_copper.png"))
	var box: StyleBox = _texture_box(file, Vector4(26, 16, 26, 16), Vector4(14, 6, 14, 6),
			_flat_fallback(Color(0.42, 0.26, 0.17, 1.0), Color(0.75, 0.5, 0.3, 1.0), 2, 4))
	var tex_box: StyleBoxTexture = box as StyleBoxTexture
	if tex_box != null:
		match state:
			"hover":
				tex_box.modulate_color = Color(1.18, 1.12, 1.05, 1.0)
			"pressed":
				tex_box.modulate_color = Color(0.72, 0.66, 0.6, 1.0)
			"disabled":
				tex_box.modulate_color = Color(0.5, 0.48, 0.46, 0.8)
	_styles[key] = box
	return box


## Placa oscura con tornillos para los paneles del HUD.
static func hud_plate_style() -> StyleBox:
	if _styles.has("hud_plate"):
		return _styles["hud_plate"] as StyleBox
	var box: StyleBox = _texture_box("slot_screws.png", Vector4(14, 14, 14, 14), Vector4(14, 8, 14, 8),
			_flat_fallback(Color(0.16, 0.11, 0.09, 0.95), COLOR_COPPER, 2, 5))
	_styles["hud_plate"] = box
	return box


## Casillero cuadrado pequeño de cobre (sockets de runas del HUD).
static func socket_style() -> StyleBox:
	if _styles.has("socket"):
		return _styles["socket"] as StyleBox
	var box: StyleBox = _texture_box("slot_dark.png", Vector4(10, 10, 10, 10), Vector4(3, 3, 3, 3),
			_flat_fallback(Color(0.18, 0.12, 0.09, 0.95), COLOR_COPPER, 2, 4))
	_styles["socket"] = box
	return box


## Tubo de la barra de salud: "bg" (vidrio vacío) o "fill" (líquido, se tiñe con `tint`).
static func bar_style(kind: String, tint: Color = Color.WHITE) -> StyleBox:
	var key: String = "bar_%s_%s" % [kind, tint.to_html()]
	if _styles.has(key):
		return _styles[key] as StyleBox
	var file: String = "bar_under.png" if kind == "bg" else "bar_fill.png"
	var fallback: StyleBoxFlat = _flat_fallback(Color(0.1, 0.07, 0.06, 1.0) if kind == "bg" else tint, COLOR_COPPER, 1, 3)
	var box: StyleBox = _texture_box(file, Vector4(16, 0, 9, 0), Vector4(0, 0, 0, 0), fallback)
	var tex_box: StyleBoxTexture = box as StyleBoxTexture
	if tex_box != null and kind != "bg":
		tex_box.modulate_color = tint
	_styles[key] = box
	return box


## Botón de la barra de armas del HUD: placa redondeada, dorada si es el arma activa.
static func weapon_button_style(active: bool) -> StyleBox:
	var key: String = "wbtn_active" if active else "wbtn_idle"
	if _styles.has(key):
		return _styles[key] as StyleBox
	var box: StyleBox = _texture_box("slot_dark.png", Vector4(10, 10, 10, 10), Vector4(8, 3, 8, 3),
			_flat_fallback(Color(0.16, 0.11, 0.09, 0.95), COLOR_GOLD if active else COLOR_COPPER, 2, 4))
	var tex_box: StyleBoxTexture = box as StyleBoxTexture
	if tex_box != null:
		tex_box = tex_box.duplicate() as StyleBoxTexture
		tex_box.modulate_color = Color(1.55, 1.25, 0.7, 1.0) if active else Color(0.8, 0.72, 0.68, 1.0)
		box = tex_box
	_styles[key] = box
	return box


## Estilo del botón de cerrar (X).
static func close_style(state: String = "normal") -> StyleBox:
	var key: String = "close_" + state
	if _styles.has(key):
		return _styles[key] as StyleBox
	var tex: Texture2D = ArtScript.tex(UI_DIR + "close_btn.png")
	var result: StyleBox
	if tex == null:
		result = _flat_fallback(Color(0.6, 0.15, 0.15, 1.0), Color(0.9, 0.5, 0.3, 1.0), 1, 3)
	else:
		var box: StyleBoxTexture = StyleBoxTexture.new()
		box.texture = tex
		match state:
			"hover":
				box.modulate_color = Color(1.25, 1.15, 1.1, 1.0)
			"pressed":
				box.modulate_color = Color(0.7, 0.65, 0.6, 1.0)
		result = box
	_styles[key] = result
	return result


## Fuente de títulos: serif con peso (Windows), con respaldo de la fuente por defecto.
static func title_font() -> Font:
	if _title_font == null:
		var system: SystemFont = SystemFont.new()
		system.font_names = PackedStringArray(["Georgia", "Cambria", "Palatino Linotype", "Book Antiqua", "Times New Roman", "Serif"])
		system.font_weight = 700
		system.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_title_font = system
	return _title_font


# ==============================================================================
# Aplicación sobre ventanas y árboles de controles
# ==============================================================================

## Marco, cabecera y botón de cerrar de una DraggableWindow.
static func skin_window(window: PanelContainer) -> void:
	window.add_theme_stylebox_override("panel", window_style())
	var title: Label = window.get_node_or_null("VBox/HeaderBar/TitleLabel") as Label
	if title != null:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", title_font())
		title.add_theme_font_size_override("font_size", 13)
		title.add_theme_color_override("font_color", COLOR_TITLE)
		title.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
		title.add_theme_constant_override("outline_size", 3)
	var header: Control = window.get_node_or_null("VBox/HeaderBar") as Control
	if header != null:
		header.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var close: Button = window.get_node_or_null("VBox/HeaderBar/CloseButton") as Button
	if close != null:
		close.text = ""
		close.custom_minimum_size = Vector2(22, 22)
		close.add_theme_stylebox_override("normal", close_style("normal"))
		close.add_theme_stylebox_override("hover", close_style("hover"))
		close.add_theme_stylebox_override("pressed", close_style("pressed"))
		close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	skin_tree(window)


## Recorre `root` y reemplaza estilos planos genéricos (paneles, botones, rótulos, pestañas, scroll).
static func skin_tree(root: Node) -> void:
	for child: Node in root.get_children():
		_skin_node(child)
		skin_tree(child)


static func _skin_node(node: Node) -> void:
	# Los casilleros y las ventanas anidadas se estilizan solos
	if node is ItemSlot or node is DraggableWindow:
		return
	if node.has_meta(&"steam_skinned"):
		return
	if node is TabContainer:
		_skin_tabs(node as TabContainer)
	elif node is Button:
		_skin_button(node as Button)
	elif node is PanelContainer or node is Panel:
		_skin_panel(node as Control)
	elif node is Label:
		_skin_label(node as Label)
	elif node is ScrollContainer:
		_skin_scroll(node as ScrollContainer)
	elif node is HSeparator or node is VSeparator:
		(node as Control).add_theme_stylebox_override("separator", _separator())


static func _skin_button(button: Button) -> void:
	if button.flat or button.has_meta(&"keep_style"):
		return
	# El botón de cerrar de la cabecera ya recibió su textura
	if button.get_parent() != null and button.get_parent().name == &"HeaderBar":
		return
	button.add_theme_stylebox_override("normal", button_style("copper", "normal"))
	button.add_theme_stylebox_override("hover", button_style("copper", "hover"))
	button.add_theme_stylebox_override("pressed", button_style("copper", "pressed"))
	button.add_theme_stylebox_override("disabled", button_style("copper", "disabled"))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8, 1))
	button.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.45, 1))
	button.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	button.add_theme_constant_override("outline_size", 2)


static func _skin_panel(panel: Control) -> void:
	var current: StyleBox = panel.get_theme_stylebox("panel")
	if current is StyleBoxTexture:
		return
	# Solo paneles que ya traían un estilo propio (secciones); los neutros se dejan
	if not panel.has_theme_stylebox_override("panel"):
		return
	panel.add_theme_stylebox_override("panel", inset_style())


static func _skin_label(label: Label) -> void:
	# Los rótulos con color propio azulado/verdoso pasan a la paleta cálida; los de rareza/estado se respetan
	if not label.has_theme_color_override("font_color"):
		label.add_theme_color_override("font_color", COLOR_TEXT)
		return
	var color: Color = label.get_theme_color("font_color")
	var cold: bool = color.b > color.r + 0.12 and color.b > 0.6
	var mint: bool = color.g > color.r + 0.35 and color.g > color.b + 0.1 and color.b < 0.75
	if cold or mint:
		label.add_theme_color_override("font_color", COLOR_GOLD if mint else COLOR_TEXT)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", maxi(label.get_theme_constant("outline_size"), 1))


static func _skin_tabs(tabs: TabContainer) -> void:
	tabs.add_theme_stylebox_override("panel", inset_style())
	tabs.add_theme_stylebox_override("tab_selected", _tab_box(true))
	tabs.add_theme_stylebox_override("tab_unselected", _tab_box(false))
	tabs.add_theme_stylebox_override("tab_hovered", _tab_box(true))
	tabs.add_theme_stylebox_override("tab_focus", StyleBoxEmpty.new())
	tabs.add_theme_color_override("font_selected_color", Color(0.2, 0.1, 0.05, 1))
	tabs.add_theme_color_override("font_unselected_color", COLOR_TEXT)
	tabs.add_theme_color_override("font_hovered_color", Color(1, 0.95, 0.8, 1))
	tabs.add_theme_font_override("font", title_font())
	tabs.add_theme_font_size_override("font_size", 12)


static func _tab_box(selected: bool) -> StyleBox:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.88, 0.74, 0.5, 1.0) if selected else Color(0.28, 0.19, 0.14, 1.0)
	box.border_color = Color(0.45, 0.28, 0.14, 1.0)
	box.set_border_width_all(2)
	box.border_width_bottom = 0
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


static func _skin_scroll(scroll: ScrollContainer) -> void:
	var grabber: StyleBoxFlat = StyleBoxFlat.new()
	grabber.bg_color = Color(0.72, 0.45, 0.25, 1.0)
	grabber.set_corner_radius_all(4)
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.08, 0.06, 0.9)
	track.set_corner_radius_all(4)
	for bar: ScrollBar in [scroll.get_v_scroll_bar(), scroll.get_h_scroll_bar()]:
		if bar == null:
			continue
		bar.add_theme_stylebox_override("grabber", grabber)
		bar.add_theme_stylebox_override("grabber_highlight", grabber)
		bar.add_theme_stylebox_override("grabber_pressed", grabber)
		bar.add_theme_stylebox_override("scroll", track)


static func _separator() -> StyleBox:
	if _styles.has("sep"):
		return _styles["sep"] as StyleBox
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = Color(0.55, 0.34, 0.2, 0.9)
	line.thickness = 2
	_styles["sep"] = line
	return line


# ==============================================================================
# Internos
# ==============================================================================

static func _texture_box(file: String, margins: Vector4, content: Vector4, fallback: StyleBox) -> StyleBox:
	var tex: Texture2D = ArtScript.tex(UI_DIR + file)
	if tex == null:
		return fallback
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = margins.x
	box.texture_margin_top = margins.y
	box.texture_margin_right = margins.z
	box.texture_margin_bottom = margins.w
	box.content_margin_left = content.x
	box.content_margin_top = content.y
	box.content_margin_right = content.z
	box.content_margin_bottom = content.w
	return box


static func _flat_fallback(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 6.0
	box.content_margin_top = 4.0
	box.content_margin_right = 6.0
	box.content_margin_bottom = 4.0
	return box
