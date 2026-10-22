extends VBoxContainer
## Grupo de una pestaña de la cinta (`ribbon.gd`): una o más columnas de controles con el título abajo, como en Office.
## Sin class_name a propósito: se crea desde `Ribbon.add_group()`.
##
## Cada control se identifica con un `id` (para sincronizarlo desde código con `ribbon.set_value(id, valor)`) y recibe
## un diccionario `opts` opcional:
##   tip       texto del tooltip
##   key       tecla (`Key`) que lo activa desde cualquier lado; la cinta la despacha y la lista en la pestaña de atajos
##   hint      texto de atajo cuando la tecla la maneja otro (por ejemplo una acción del Input Map)
##   icon      nombre de ícono (ver ribbon_theme.gd)
##   variant   "primary" | "danger" para botones
##   min_width ancho mínimo en px
## Los controles nuevos se apilan en la columna actual; `column()` abre otra. Los botones grandes ocupan toda la altura.

const RibbonTheme = preload("res://ui/debug/ribbon_theme.gd")

## Filas que caben en una columna del cuerpo de la cinta.
const COLUMN_ROWS: int = 3

var ribbon: Node = null
var tab_id: String = ""
var title: String = ""

var _body: HBoxContainer = null
var _column: VBoxContainer = null


func _init(owner_ribbon: Node = null, owner_tab: String = "", group_title: String = "") -> void:
	ribbon = owner_ribbon
	tab_id = owner_tab
	title = group_title
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 2)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)
	var caption: Label = Label.new()
	caption.text = group_title.to_upper()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", RibbonTheme.TEXT_DIM)
	add_child(caption)
	column()


## Abre una columna nueva a la derecha de la actual.
func column(min_width: float = 0.0) -> VBoxContainer:
	_column = VBoxContainer.new()
	_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.custom_minimum_size.x = min_width
	_column.add_theme_constant_override("separation", 3)
	_body.add_child(_column)
	return _column


# ==============================================================================
# Controles
# ==============================================================================

## Botón grande (ocupa toda la altura de la columna), con ícono arriba y texto debajo.
func big_button(text: String, on_pressed: Callable, opts: Dictionary = {}) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.x = float(opts.get("min_width", 84.0))
	button.icon = RibbonTheme.icon(str(opts.get("icon", "")))
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.expand_icon = false
	_apply_variant(button, opts)
	button.pressed.connect(on_pressed)
	_finish(button, str(opts.get("id", "")), opts, text, on_pressed)
	var hint: String = _hint_of(opts)
	if not hint.is_empty():
		button.text += "\n[%s]" % hint
	_column.add_child(button)
	return button


## Botón compacto de una fila.
func button(text: String, on_pressed: Callable, opts: Dictionary = {}) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.x = float(opts.get("min_width", 0.0))
	var icon_name: String = str(opts.get("icon", ""))
	if not icon_name.is_empty():
		b.icon = RibbonTheme.icon(icon_name, 0.62)
	_apply_variant(b, opts)
	b.pressed.connect(on_pressed)
	_finish(b, str(opts.get("id", "")), opts, text, on_pressed)
	_add_row(b, opts)
	return b


## Casilla de verificación. `on_toggled(on: bool)`.
func toggle(id: String, text: String, initial: bool, on_toggled: Callable, opts: Dictionary = {}) -> CheckBox:
	var check: CheckBox = CheckBox.new()
	check.text = text
	check.button_pressed = initial
	check.focus_mode = Control.FOCUS_NONE
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	check.toggled.connect(on_toggled)
	var flip: Callable = func() -> void: check.button_pressed = not check.button_pressed
	_finish(check, id, opts, text, flip)
	_add_row(check, opts)
	return check


## Desplegable con rótulo a la izquierda. `on_selected(index: int)`.
func choice(id: String, caption: String, items: Array, selected: int, on_selected: Callable, opts: Dictionary = {}) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.fit_to_longest_item = false
	option.clip_text = true
	option.custom_minimum_size.x = float(opts.get("min_width", 118.0))
	for item: Variant in items:
		option.add_item(str(item))
	option.select(selected)
	option.item_selected.connect(on_selected)
	_finish(option, id, opts, caption, Callable())
	_add_row(_captioned(caption, option), opts, false)
	return option


## Selector segmentado: una fila de opciones excluyentes. `on_selected(index: int)`.
func segmented(id: String, caption: String, items: Array, selected: int, on_selected: Callable, opts: Dictionary = {}) -> HBoxContainer:
	var holder: HBoxContainer = HBoxContainer.new()
	holder.add_theme_constant_override("separation", 2)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button_group: ButtonGroup = ButtonGroup.new()
	for i: int in range(items.size()):
		var chip: Button = Button.new()
		chip.theme_type_variation = &"RibbonChip"
		chip.toggle_mode = true
		chip.button_group = button_group
		chip.text = str(items[i])
		chip.focus_mode = Control.FOCUS_NONE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.button_pressed = i == selected
		chip.pressed.connect(on_selected.bind(i))
		holder.add_child(chip)
	_finish(holder, id, opts, caption, Callable())
	_add_row(_captioned(caption, holder), opts, false)
	return holder


## Texto que se refresca solo (4 veces por segundo). `provider() -> String`; `color_provider() -> Color` es opcional.
func readout(provider: Callable, opts: Dictionary = {}) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", RibbonTheme.TEXT_DIM)
	label.custom_minimum_size.x = float(opts.get("min_width", 0.0))
	label.text = str(provider.call())
	if opts.has("tip"):
		label.tooltip_text = str(opts["tip"])
		label.mouse_filter = Control.MOUSE_FILTER_STOP
	ribbon.call("register_live", label, provider, opts.get("color", Callable()))
	_add_row(label, opts)
	return label


## Fila de la pestaña de atajos: tecla en una chapita y su descripción.
func shortcut_row(key_text: String, description: String) -> void:
	if _column.get_child_count() >= COLUMN_ROWS:
		column()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var badge: Label = _badge(key_text)
	badge.custom_minimum_size.x = 44.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(badge)
	var label: Label = Label.new()
	label.text = description
	row.add_child(label)
	_column.add_child(row)


# ==============================================================================
# Internos
# ==============================================================================

func _apply_variant(b: Button, opts: Dictionary) -> void:
	match str(opts.get("variant", "")):
		"primary":
			b.theme_type_variation = &"RibbonPrimary"
		"danger":
			b.theme_type_variation = &"RibbonDanger"


## Registra el control en la cinta (para `set_value`), engancha su tecla y arma el tooltip.
func _finish(control: Control, id: String, opts: Dictionary, label_text: String, key_action: Callable) -> void:
	var key: int = int(opts.get("key", KEY_NONE))
	var tip: String = str(opts.get("tip", ""))
	var hint: String = _hint_of(opts)
	if not hint.is_empty():
		tip = ("%s  [%s]" % [tip, hint]).strip_edges()
	if not tip.is_empty():
		control.tooltip_text = tip
	if not id.is_empty():
		ribbon.call("register_control", id, control)
	if key != KEY_NONE and key_action.is_valid():
		ribbon.call("bind_key", key, key_action, label_text.replace("\n", " "), tab_id, str(opts.get("hint", "")))
	elif key == KEY_NONE and opts.has("hint"):
		ribbon.call("add_hint", tab_id, str(opts["hint"]), label_text.replace("\n", " "))


func _hint_of(opts: Dictionary) -> String:
	if opts.has("hint"):
		return str(opts["hint"])
	var key: int = int(opts.get("key", KEY_NONE))
	return OS.get_keycode_string(key as Key) if key != KEY_NONE else ""


## Agrega el control a la columna actual; si tiene atajo, le suma la chapita a la derecha.
func _add_row(control: Control, opts: Dictionary, with_badge: bool = true) -> void:
	var hint: String = _hint_of(opts)
	if _column.get_child_count() >= COLUMN_ROWS:
		column()
	if hint.is_empty() or not with_badge:
		_column.add_child(control)
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(control)
	row.add_child(_badge(hint))
	_column.add_child(row)


func _captioned(caption: String, control: Control) -> Control:
	if caption.is_empty():
		return control
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label: Label = Label.new()
	label.text = caption
	label.custom_minimum_size.x = 56.0
	label.add_theme_color_override("font_color", RibbonTheme.TEXT_DIM)
	row.add_child(label)
	row.add_child(control)
	return row


func _badge(text: String) -> Label:
	var badge: Label = Label.new()
	badge.text = text
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", RibbonTheme.TEXT_DIM)
	badge.add_theme_stylebox_override("normal", RibbonTheme.box(RibbonTheme.BG_DEEP, RibbonTheme.BORDER, 1, 3, Vector4(5, 1, 5, 1)))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return badge
