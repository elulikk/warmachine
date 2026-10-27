extends Control
## Estado del equipo, chico y discreto, arriba del contador de munición (abajo a la derecha).
## - Arrojadizo equipado: ícono, una balita por carga y "disponibles / máximas"; con cooldown (gancho, baliza,
##   boomerang) una barra que se llena hasta quedar listo.
## - Jetpack: ícono y barra de combustible; solo si hay uno equipado.
## Mismo estilo que el contador de munición (texto con borde, balitas). Sin class_name a propósito:
## lo instancia ui/hud.gd por preload.

const ItemIconsScript = preload("res://ui/components/item_icons.gd")

const MARGIN: float = 20.0
## Distancia desde abajo: deja libre el contador de munición.
const BOTTOM_OFFSET: float = 190.0
const MAX_PIPS: int = 10
const COLOR_TEXT: Color = Color(0.96, 0.94, 0.88, 1.0)
const COLOR_DIM: Color = Color(0.72, 0.74, 0.8, 0.85)
const COLOR_LOW: Color = Color(1.0, 0.62, 0.15, 1.0)
const COLOR_CRITICAL: Color = Color(1.0, 0.2, 0.15, 1.0)
const PIP_ON: Color = Color(0.45, 0.85, 1.0, 1.0)
const PIP_PARTIAL: Color = Color(0.45, 0.85, 1.0, 0.4)
const PIP_OFF: Color = Color(0.25, 0.25, 0.3, 0.7)
const FUEL_COLOR: Color = Color(1.0, 0.55, 0.15, 1.0)

var _player: Player = null
var _box: VBoxContainer = null

var _throw_row: HBoxContainer = null
var _throw_icon: TextureRect = null
var _throw_pips: HBoxContainer = null
var _throw_bar: ProgressBar = null
var _throw_label: Label = null
var _throw_item: ItemData = null
var _pip_count: int = 0
var _last_pips_key: String = ""

var _fuel_row: HBoxContainer = null
var _fuel_icon: TextureRect = null
var _fuel_bar: ProgressBar = null
var _fuel_label: Label = null
var _fuel_item: ItemData = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 4)
	_box.anchor_left = 1.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_right = -MARGIN
	_box.offset_bottom = -BOTTOM_OFFSET
	_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_box)

	# Arrojadizo: [balitas o barra] [n / max] [ícono]
	_throw_row = _row()
	_throw_pips = HBoxContainer.new()
	_throw_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_throw_pips.add_theme_constant_override("separation", 2)
	_throw_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_throw_row.add_child(_throw_pips)
	_throw_bar = _bar(54.0, PIP_ON)
	_throw_row.add_child(_throw_bar)
	_throw_label = _label(15)
	_throw_row.add_child(_throw_label)
	_throw_icon = _icon()
	_throw_row.add_child(_throw_icon)

	# Jetpack: [barra] [%] [ícono]
	_fuel_row = _row()
	_fuel_bar = _bar(54.0, FUEL_COLOR)
	_fuel_row.add_child(_fuel_bar)
	_fuel_label = _label(15)
	_fuel_row.add_child(_fuel_label)
	_fuel_icon = _icon()
	_fuel_row.add_child(_fuel_icon)

	_throw_row.visible = false
	_fuel_row.visible = false


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	_refresh_throwable()
	_refresh_fuel()


func _refresh_throwable() -> void:
	var tm: ThrowableManager = _player.get_node_or_null("ThrowableManager") as ThrowableManager
	var item: ItemData = tm.equipped_throwable if tm != null else null
	if item == null:
		_throw_row.visible = false
		_throw_item = null
		return
	_throw_row.visible = true
	if item != _throw_item:
		_throw_item = item
		_throw_icon.texture = ItemIconsScript.get_icon_for(item)
		_throw_icon.visible = _throw_icon.texture != null
		_last_pips_key = ""

	if tm.uses_charges(item):
		var maxc: int = tm.max_charges
		var charges: float = tm.get_charges(item)
		var whole: int = int(floor(charges + 0.0001))
		var partial: float = charges - float(whole)
		var key: String = "%d|%d|%d" % [maxc, whole, int(partial * 8.0)]
		_throw_pips.visible = true
		_throw_bar.visible = false
		if key != _last_pips_key:
			_last_pips_key = key
			_set_pips(mini(maxc, MAX_PIPS), whole, partial > 0.0)
		_throw_label.text = "%d / %d" % [whole, maxc]
		_throw_label.add_theme_color_override("font_color", COLOR_CRITICAL if whole == 0 else (COLOR_LOW if whole == 1 else COLOR_TEXT))
	else:
		_throw_pips.visible = false
		_throw_bar.visible = true
		var ratio: float = 1.0 - tm.get_cooldown_ratio()
		_throw_bar.value = ratio
		_throw_label.text = "LISTO" if ratio >= 1.0 else "..."
		_throw_label.add_theme_color_override("font_color", COLOR_TEXT if ratio >= 1.0 else COLOR_LOW)


func _refresh_fuel() -> void:
	if not _player.has_jetpack:
		_fuel_row.visible = false
		return
	_fuel_row.visible = true
	var em: EquipmentManager = _player.get_node_or_null("EquipmentManager") as EquipmentManager
	var item: ItemData = em.get_equipped_item(EquipmentManager.SLOT_BACK) if em != null else null
	if item != _fuel_item:
		_fuel_item = item
		_fuel_icon.texture = ItemIconsScript.get_icon_for(item)
		_fuel_icon.visible = _fuel_icon.texture != null
	var ratio: float = clampf(_player.jetpack_fuel / maxf(_player.max_jetpack_fuel, 1.0), 0.0, 1.0)
	_fuel_bar.value = ratio
	_fuel_label.text = "%d%%" % int(round(ratio * 100.0))
	var color: Color = COLOR_TEXT
	if ratio <= 0.15:
		color = COLOR_CRITICAL
	elif ratio <= 0.3:
		color = COLOR_LOW
	_fuel_label.add_theme_color_override("font_color", color)


## `partial`: la carga siguiente está a medio recargar y se dibuja tenue.
func _set_pips(size: int, filled: int, partial: bool) -> void:
	if size != _pip_count:
		for child: Node in _throw_pips.get_children():
			child.queue_free()
		_pip_count = size
		for i in range(size):
			var pip: ColorRect = ColorRect.new()
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.custom_minimum_size = Vector2(7.0, 12.0)
			_throw_pips.add_child(pip)
	var kids: Array[Node] = _throw_pips.get_children()
	for i in range(mini(kids.size(), size)):
		var color: Color = PIP_OFF
		if i < filled:
			color = PIP_ON
		elif i == filled and partial:
			color = PIP_PARTIAL
		(kids[i] as ColorRect).color = color


func _row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_theme_constant_override("separation", 6)
	_box.add_child(row)
	return row


func _icon() -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(22.0, 22.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func _bar(width: float, fill_color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(width, 6.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 1.0
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_corner_radius_all(2)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _label(font_size: int) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	return label
