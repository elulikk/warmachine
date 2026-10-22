extends RefCounted
## Caja de herramientas de la UI: fábricas de controles ya estilizados con el tema activo.
## Sin class_name a propósito: se usa por `preload` (`const UiKit = preload("res://ui/framework/ui_kit.gd")`).
##
## Todas las funciones reciben el `parent` donde se agrega el control y devuelven lo creado, así una
## ventana se arma en pocas líneas:
##     var body: VBoxContainer = UiKit.section(root, "PERSONAJE")
##     var grid: GridContainer = UiKit.stat_grid(body)
##     var hp: Label = UiKit.stat_row(grid, "Vida:", "100")
##     UiKit.button(body, "Curar", _on_heal)
## Colores, fuentes y marcos salen de `UiTheme` / `SteamSkin`: nunca se escriben colores sueltos en las
## ventanas, así cambiar el tema cambia todo. Los controles creados acá quedan marcados como estilizados
## para que `SteamSkin.skin_tree` no los vuelva a pintar.

const UiThemeScript = preload("res://ui/framework/ui_theme.gd")
const SteamSkin = preload("res://ui/components/steam_skin.gd")

const SKINNED: StringName = &"steam_skinned"


static func theme() -> Resource:
	return UiThemeScript.current()


# ==============================================================================
# Texto
# ==============================================================================

## Rótulo. `role`: "body", "dim", "small", "header", "title", "big", "gold", "good", "bad".
static func label(parent: Node, text: String, role: String = "body") -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	style_label(lbl, role)
	_add(parent, lbl)
	return lbl


## Párrafo que corta en varias líneas al ancho disponible.
static func paragraph(parent: Node, text: String, role: String = "body") -> Label:
	var lbl: Label = label(parent, text, role)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.custom_minimum_size.x = 60.0
	return lbl


## Aplica un rol de texto a un Label existente (sirve para cambiar de rol en caliente).
static func style_label(lbl: Label, role: String) -> void:
	var t: Resource = theme()
	var color: Color = t.text
	var size: int = t.size_body
	var font: Font = t.body_font
	var outline: int = 1
	match role:
		"dim":
			color = t.text_dim
		"small":
			color = t.text_dim
			size = t.size_small
		"header":
			color = t.gold
			size = t.size_header
			font = t.get_title_font()
			outline = 2
		"title":
			color = t.title
			size = t.size_title
			font = t.get_title_font()
			outline = 3
		"big":
			color = t.title
			size = t.size_big
			font = t.get_title_font()
			outline = 3
		"gold":
			color = t.gold
		"good":
			color = t.good
		"bad":
			color = t.bad
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", t.outline)
	lbl.add_theme_constant_override("outline_size", outline)
	lbl.add_theme_font_size_override("font_size", size)
	if font != null:
		lbl.add_theme_font_override("font", font)
	lbl.set_meta(SKINNED, true)


# ==============================================================================
# Contenedores
# ==============================================================================

static func vbox(parent: Node, separation: int = 6) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	_add(parent, box)
	return box


static func hbox(parent: Node, separation: int = 6) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	_add(parent, box)
	return box


## Sección con marco interior oscuro y título opcional. Devuelve la columna donde va el contenido.
static func section(parent: Node, title: String = "") -> VBoxContainer:
	return _framed(parent, SteamSkin.inset_style(), title)


## Recuadro de pergamino (fichas, citas, lore). Devuelve la columna interior.
static func parchment(parent: Node, title: String = "") -> VBoxContainer:
	return _framed(parent, SteamSkin.parchment_style(), title)


## Grilla de dos columnas (título: valor).
static func stat_grid(parent: Node, columns: int = 2) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	_add(parent, grid)
	return grid


## Fila "título  valor" en una grilla. Devuelve el Label del valor para actualizarlo después.
static func stat_row(grid: GridContainer, title: String, value: String = "", value_role: String = "body") -> Label:
	label(grid, title, "dim")
	var val: Label = label(grid, value, value_role)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return val


## Pestañas que ocupan el alto disponible. Las páginas se agregan con `tab()`.
static func tabs(parent: Node) -> TabContainer:
	var tc: TabContainer = TabContainer.new()
	tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(parent, tc)
	SteamSkin._skin_tabs(tc)
	tc.set_meta(SKINNED, true)
	return tc


## Página de una pestaña. Devuelve la columna de la página.
static func tab(tabs_node: TabContainer, title: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = title
	page.add_theme_constant_override("separation", 6)
	tabs_node.add_child(page)
	return page


## Lista desplazable vertical. Devuelve la columna interior.
static func scroll_list(parent: Node, separation: int = 4) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_add(parent, scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", separation)
	scroll.add_child(column)
	return column


## Vista maestro-detalle: lista a la izquierda (ancho fijo) y ficha a la derecha, cada una con scroll.
## Devuelve {"list": VBoxContainer, "detail": VBoxContainer}.
static func list_detail(parent: Node, list_width: float = 190.0) -> Dictionary:
	var row: HBoxContainer = hbox(parent, 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left: VBoxContainer = section(row)
	var left_panel: Control = left.get_parent() as Control
	left_panel.custom_minimum_size.x = list_width
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list: VBoxContainer = scroll_list(left, 2)
	var right: VBoxContainer = section(row)
	var right_panel: Control = right.get_parent() as Control
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var detail: VBoxContainer = scroll_list(right, 6)
	return {"list": list, "detail": detail}


# ==============================================================================
# Controles
# ==============================================================================

## Botón de placa. `kind`: "copper", "dark" o "plate" (texturas del tema).
static func button(parent: Node, text: String, on_pressed: Callable = Callable(), kind: String = "copper") -> Button:
	var btn: Button = Button.new()
	btn.text = text
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(state, SteamSkin.button_style(kind, state))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_text_colors(btn)
	btn.set_meta(SKINNED, true)
	if on_pressed.is_valid():
		btn.pressed.connect(on_pressed)
	_add(parent, btn)
	return btn


## Fila seleccionable de una lista (ícono + texto). Las filas de un mismo `list` se excluyen entre sí.
## `locked` = sin descubrir: ícono en silueta y texto apagado.
static func list_entry(list: Node, text: String, icon: Texture2D, on_pressed: Callable, locked: bool = false, text_color: Color = Color(0, 0, 0, 0)) -> Button:
	var t: Resource = theme()
	var btn: Button = Button.new()
	btn.toggle_mode = true
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.icon = icon
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 24)
	btn.custom_minimum_size.y = 28.0
	btn.clip_text = true
	var group: ButtonGroup = list.get_meta(&"ui_kit_group") as ButtonGroup if list.has_meta(&"ui_kit_group") else null
	if group == null:
		group = ButtonGroup.new()
		list.set_meta(&"ui_kit_group", group)
	btn.button_group = group
	var idle: StyleBoxFlat = StyleBoxFlat.new()
	idle.bg_color = Color(0, 0, 0, 0)
	idle.content_margin_left = 4.0
	idle.content_margin_right = 4.0
	var hover: StyleBoxFlat = idle.duplicate() as StyleBoxFlat
	hover.bg_color = Color(t.selected.r, t.selected.g, t.selected.b, t.selected.a * 0.5)
	var picked: StyleBoxFlat = idle.duplicate() as StyleBoxFlat
	picked.bg_color = t.selected
	picked.border_color = t.gold
	picked.border_width_left = 2
	btn.add_theme_stylebox_override("normal", idle)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", picked)
	btn.add_theme_stylebox_override("hover_pressed", picked)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_text_colors(btn)
	var color: Color = t.text_dim if locked else (text_color if text_color.a > 0.0 else t.text)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_pressed_color", t.gold if not locked else t.text_dim)
	btn.add_theme_font_size_override("font_size", t.size_body)
	if locked:
		btn.add_theme_color_override("icon_normal_color", t.locked)
		btn.add_theme_color_override("icon_hover_color", t.locked)
		btn.add_theme_color_override("icon_pressed_color", t.locked)
		btn.add_theme_color_override("icon_hover_pressed_color", t.locked)
	btn.set_meta(SKINNED, true)
	if on_pressed.is_valid():
		btn.pressed.connect(on_pressed)
	_add(list, btn)
	return btn


## Imagen centrada de tamaño fijo. `silhouette` la tiñe con el color de bloqueado del tema.
static func image(parent: Node, texture: Texture2D, box_size: Vector2, silhouette: bool = false) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = box_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if silhouette:
		rect.modulate = theme().locked
	_add(parent, rect)
	return rect


## Barra de progreso lisa (0..1) con el color pedido (por defecto, el dorado del tema).
static func bar(parent: Node, ratio: float, color: Color = Color(0, 0, 0, 0), height: float = 6.0) -> ProgressBar:
	var pb: ProgressBar = ProgressBar.new()
	pb.show_percentage = false
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = clampf(ratio, 0.0, 1.0)
	pb.custom_minimum_size = Vector2(0.0, height)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(2)
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = color if color.a > 0.0 else theme().gold
	fg.set_corner_radius_all(2)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	pb.set_meta(SKINNED, true)
	_add(parent, pb)
	return pb


static func separator(parent: Node) -> HSeparator:
	var sep: HSeparator = HSeparator.new()
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = Color(theme().copper, 0.8)
	line.thickness = 2
	sep.add_theme_stylebox_override("separator", line)
	sep.set_meta(SKINNED, true)
	_add(parent, sep)
	return sep


## Espacio vacío; `expand` empuja lo que sigue al final de la fila o columna.
static func spacer(parent: Node, expand: bool = true, min_size: float = 4.0) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(min_size, min_size)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add(parent, gap)
	return gap


## Borra todos los hijos (para reconstruir una ficha o lista).
static func clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Vacía una lista de `list_entry` para volver a llenarla (filas y grupo de selección).
static func reset_list(list: Node) -> void:
	clear(list)
	if list.has_meta(&"ui_kit_group"):
		list.remove_meta(&"ui_kit_group")


## Color de rareza (0 = común .. 4 = legendaria), el mismo de tooltips y casilleros.
static func rarity_color(rarity: int) -> Color:
	return ItemTooltip.RARITY_COLORS.get(rarity, theme().text) as Color


# ==============================================================================
# Internos
# ==============================================================================

static func _framed(parent: Node, box: StyleBox, title: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box)
	panel.set_meta(SKINNED, true)
	_add(parent, panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	if not title.is_empty():
		label(column, title, "header")
	return column


static func _text_colors(btn: Button) -> void:
	var t: Resource = theme()
	btn.add_theme_color_override("font_color", t.text)
	btn.add_theme_color_override("font_hover_color", t.title)
	btn.add_theme_color_override("font_pressed_color", t.gold)
	btn.add_theme_color_override("font_disabled_color", t.text_dim)
	btn.add_theme_color_override("font_outline_color", t.outline)
	btn.add_theme_constant_override("outline_size", 2)


static func _add(parent: Node, child: Node) -> void:
	if parent != null:
		parent.add_child(child)
