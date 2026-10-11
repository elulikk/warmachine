extends PanelContainer
## Casillero de la barra de acceso rápido (ui/hotbar.gd). Guarda una referencia: un arma del arsenal o un consumible.
## Implementa el protocolo de ítem en mano (ver item_drag_controller.gd) con métodos propios:
## - Como ORIGEN: se arrastra para mover o intercambiar dentro de la barra (sin clic-clic).
## - Como DESTINO (grupo "drop_targets"): la barra decide qué entra con `accept_filter`.
## Clic derecho quita el ítem. Sin class_name a propósito: lo crea ui/hotbar.gd por preload.

const ItemDragControllerScript = preload("res://ui/components/item_drag_controller.gd")
const ItemIconsScript = preload("res://ui/components/item_icons.gd")

signal dropped(payload: Dictionary, slot: PanelContainer)
signal right_clicked(slot: PanelContainer)

const COLOR_BG: Color = Color(0.06, 0.08, 0.12, 0.88)
const COLOR_DROP_OK: Color = Color(0.45, 1.0, 0.55, 1.0)
const COLOR_DROP_BAD: Color = Color(1.0, 0.35, 0.3, 1.0)

var index: int = 0
var slot_index: int = 0
var slot_type: String = "ANY"
var context_tag: String = "hotbar"
## Recurso guardado: WeaponData (del arsenal) o ConsumableData (del catálogo)
var item: Resource = null
## Filtro que decide si un ítem entra al casillero: func(res, payload, slot) -> bool
var accept_filter: Callable = Callable()

var _name_label: Label = null
var _count_label: Label = null
var _icon: TextureRect = null
var _border: Color = Color(0.3, 0.4, 0.55, 0.8)
var _border_width: int = 1
var _drop_state: int = ItemSlot.DROP_NONE
var _carried: bool = false


func _ready() -> void:
	slot_index = index
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(ItemDragControllerScript.TARGETS_GROUP)
	gui_input.connect(_on_gui_input)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	add_child(box)

	var key_label: Label = _make_text_label(9, Color(0.7, 0.78, 0.9, 1.0))
	key_label.text = str(index + 1)
	box.add_child(key_label)

	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = Vector2(20.0, 20.0)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_icon)

	_name_label = _make_text_label(9, Color.WHITE)
	box.add_child(_name_label)

	_count_label = _make_text_label(11, Color.WHITE)
	box.add_child(_count_label)

	_restyle()


## Pinta el casillero según lo que contiene y si está seleccionado (lo calcula ui/hotbar.gd).
func show_entry(name_text: String, count_text: String, accent: Color, icon_tex: Texture2D, border: Color, border_width: int) -> void:
	_name_label.text = name_text
	_name_label.add_theme_color_override("font_color", accent)
	_count_label.text = count_text
	_icon.texture = icon_tex
	_icon.visible = icon_tex != null
	_border = border
	_border_width = border_width
	_restyle()


func set_item(res: Resource) -> void:
	item = res


func _restyle() -> void:
	var width: int = _border_width
	var color: Color = _border
	match _drop_state:
		ItemSlot.DROP_HOVER_OK:
			color = COLOR_DROP_OK
			width = 2
		ItemSlot.DROP_HOVER_BAD:
			color = COLOR_DROP_BAD
			width = 2
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.set_corner_radius_all(4)
	style.set_border_width_all(width)
	style.border_color = color
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	add_theme_stylebox_override("panel", style)


# ==============================================================================
# Protocolo de ítem en mano: origen
# ==============================================================================

func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		right_clicked.emit(self)
	elif mb.button_index == MOUSE_BUTTON_LEFT and item != null:
		var controller: ItemDragControllerScript = ItemSlot.get_drag_controller(get_tree())
		if controller != null:
			# Solo se arrastra: un clic no levanta el ítem, así no choca con elegir casillero
			controller.begin_press(self, item, build_carry_payload(), false)


func build_carry_payload() -> Dictionary:
	var display_color: Color = Color(0.7, 0.7, 0.7, 1.0)
	var display_text: String = "ITM"
	var weapon: WeaponData = item as WeaponData
	if weapon != null:
		display_color = Color(0.35, 0.65, 0.95, 1.0) if weapon.weapon_type == WeaponData.WeaponType.RANGED else Color(0.95, 0.75, 0.25, 1.0)
		display_text = weapon.weapon_name.left(3).to_upper()
	return {
		"resource": item,
		"source_slot": self,
		"context_tag": context_tag,
		"slot_index": index,
		"slot_type": slot_type,
		"display_color": display_color,
		"display_text": display_text,
		"rarity_color": COLOR_BG,
		"icon": ItemIconsScript.get_icon_for(item)
	}


func get_item() -> Resource:
	return item


## Atenúa el casillero mientras su ítem está en mano.
func set_carried(carried: bool) -> void:
	_carried = carried
	modulate.a = 0.25 if carried else 1.0


# ==============================================================================
# Protocolo de ítem en mano: destino
# ==============================================================================

func can_accept_carried(res: Resource, payload: Dictionary) -> bool:
	if res == null or not accept_filter.is_valid():
		return false
	return bool(accept_filter.call(res, payload, self))


func receive_carried(payload: Dictionary) -> void:
	dropped.emit(payload, self)


func set_drop_state(state: int) -> void:
	if state == _drop_state:
		return
	_drop_state = state
	_restyle()


func _make_text_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
