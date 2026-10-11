class_name ItemSlot
extends PanelContainer
## Casillero compacto de 40x40 px con marco metálico oscuro.
## Muestra íconos de recursos (ItemData, RuneData, WeaponData), proyecta tooltip estilizado,
## y participa del sistema de "ítem en mano" (ver item_drag_controller.gd):
## - Como ORIGEN: al presionar con el botón izquierdo sobre un ítem lo agarra (arrastrar, o clic y clic).
## - Como DESTINO (grupo "drop_targets"): informa si acepta un ítem, lo recibe y se resalta.
## El clic derecho sigue siendo la acción rápida (equipar / transferir) de cada ventana.

const ItemDragControllerScript = preload("res://ui/components/item_drag_controller.gd")
const ItemIconsScript = preload("res://ui/components/item_icons.gd")
const SteamSkin = preload("res://ui/components/steam_skin.gd")
const ConsumableDataScript = preload("res://core/consumables/consumable_data.gd")

signal slot_clicked(slot: ItemSlot, button_index: int)
signal slot_right_clicked(slot: ItemSlot)
signal item_dropped_on_slot(source_data: Dictionary, target_slot: ItemSlot)

const DROP_NONE: int = 0
const DROP_CANDIDATE: int = 1
const DROP_HOVER_OK: int = 2
const DROP_HOVER_BAD: int = 3

@export var slot_type: String = "ANY" # "ANY", "WEAPON", "RUNE", "HEAD", "CHEST", "GLOVES", "BOOTS", "BACK", "ACCESSORY_1", "ACCESSORY_2", "TACTICAL"
@export var slot_index: int = -1
@export var context_tag: String = "backpack" # "backpack", "equipment", "stash", "socket"
@export var is_read_only: bool = false
## Si es true, un clic sin mover levanta el ítem (y otro clic lo suelta). Las ranuras cuyo clic ya
## significa otra cosa (ej.: elegir arma en la barra rápida) lo desactivan y solo se arrastran.
@export var carry_on_click: bool = true
## Texto tenue que se muestra cuando el casillero está vacío (ej.: "CASCO").
@export var empty_hint: String = ""

## Filtro extra opcional para aceptar ítems: func(res: Resource, payload: Dictionary, slot: ItemSlot) -> bool.
## Las ventanas lo usan para reglas propias sin tocar este script.
var accept_filter: Callable = Callable()

@onready var texture_rect: TextureRect = $CenterContainer/TextureRect
@onready var fallback_color: ColorRect = $CenterContainer/FallbackColor
@onready var fallback_label: Label = $CenterContainer/FallbackLabel
@onready var center_container: CenterContainer = $CenterContainer
@onready var hint_label: Label = get_node_or_null("HintLabel") as Label

var item_resource: Resource = null
static var _shared_tooltip: ItemTooltip = null
static var _drag_controller: ItemDragControllerScript = null
var _is_highlighted: bool = false
var _normal_stylebox: StyleBox = null
var _rarity_border: Color = Color(0, 0, 0, 0)
var _drop_state: int = DROP_NONE
var _pulse_time: float = 0.0
var _is_carried: bool = false
## Datos de comercio (solo dibujo y tooltip): precio y cantidad que se muestran sobre el ícono.
var _price_text: String = ""
var _price_color: Color = Color(1.0, 0.85, 0.3, 1.0)
var _count_text: String = ""
var _tooltip_price_text: String = ""


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(40, 40)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	add_to_group(ItemDragControllerScript.TARGETS_GROUP)
	# Casillero de cuero; la rareza se dibuja como borde de color encima (ver _draw)
	_normal_stylebox = SteamSkin.slot_style()
	add_theme_stylebox_override("panel", _normal_stylebox)
	set_process(false)
	update_visuals()


func set_item(res: Resource) -> void:
	item_resource = res
	update_visuals()


func get_item() -> Resource:
	return item_resource


func clear_slot() -> void:
	item_resource = null
	update_visuals()


## Muestra precio (abajo a la derecha) y cantidad (arriba a la izquierda) sobre el ícono. Texto vacío los oculta.
## `tooltip_price` reemplaza el valor en monedas de la ficha del tooltip (ej.: "Compra: 120 Monedas").
func set_trade_badges(price_text: String, price_color: Color, count_text: String = "", tooltip_price: String = "") -> void:
	_price_text = price_text
	_price_color = price_color
	_count_text = count_text
	_tooltip_price_text = tooltip_price
	queue_redraw()


## Resalta visualmente el casillero (por ejemplo, para indicar el arma actualmente activa/equipada).
func set_highlight(active: bool) -> void:
	_is_highlighted = active
	queue_redraw()


## Actualiza el borde de color de rareza si tiene un ítem (se dibuja en `_draw`).
func _refresh_frame() -> void:
	_rarity_border = Color(0, 0, 0, 0)
	if item_resource != null:
		var rarity_value: Variant = item_resource.get(&"rarity")
		if rarity_value != null:
			_rarity_border = ItemTooltip.RARITY_COLORS[clampi(int(rarity_value), 0, 4)]
	queue_redraw()


## Color y texto de representación del recurso (usado por el casillero y por el ítem en mano).
func _get_display_info() -> Dictionary:
	var display_color: Color = Color(0.7, 0.7, 0.7, 1.0)
	var display_text: String = "ITM"
	if item_resource is ItemData:
		var item: ItemData = item_resource as ItemData
		display_color = item.item_color
		display_text = item.item_name.left(3).to_upper()
	elif item_resource is RuneData:
		var rune: RuneData = item_resource as RuneData
		display_color = rune.rune_color
		display_text = rune.rune_name.left(2).to_upper()
	elif item_resource is WeaponData:
		var weapon: WeaponData = item_resource as WeaponData
		display_color = Color(0.35, 0.65, 0.95, 1.0) if weapon.weapon_type == WeaponData.WeaponType.RANGED else Color(0.95, 0.75, 0.25, 1.0)
		display_text = weapon.weapon_name.left(3).to_upper()
	elif item_resource is ConsumableDataScript:
		var consumable: ConsumableDataScript = item_resource as ConsumableDataScript
		display_color = consumable.color
		display_text = consumable.short_name.left(3).to_upper()
	return {"color": display_color, "text": display_text}


func update_visuals() -> void:
	_refresh_frame()
	if not is_inside_tree():
		return

	if item_resource == null:
		if texture_rect != null:
			texture_rect.visible = false
			texture_rect.texture = null
		if fallback_color != null:
			fallback_color.visible = false
		if fallback_label != null:
			fallback_label.visible = false
			fallback_label.text = ""
		if hint_label != null:
			hint_label.text = empty_hint
			hint_label.visible = not empty_hint.is_empty()
		tooltip_text = ""
		return

	if hint_label != null:
		hint_label.visible = false

	var info: Dictionary = _get_display_info()
	var display_color: Color = info["color"]
	var display_text: String = str(info["text"])
	var tex: Texture2D = ItemIconsScript.get_icon_for(item_resource)

	if texture_rect != null and tex != null:
		texture_rect.texture = tex
		# Arte HD: filtro lineal; los íconos pixel art 16x16 de respaldo se amplían sin suavizado
		var is_art: bool = ItemIconsScript.get_art_icon(item_resource) != null
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if is_art else CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.visible = true
		if fallback_color != null:
			fallback_color.visible = false
		if fallback_label != null:
			fallback_label.visible = false
	else:
		if texture_rect != null:
			texture_rect.visible = false
		if fallback_color != null:
			fallback_color.visible = true
			fallback_color.color = display_color
		if fallback_label != null:
			fallback_label.visible = true
			fallback_label.text = display_text


# ==============================================================================
# Origen: agarrar el ítem
# ==============================================================================

func _on_gui_input(event: InputEvent) -> void:
	if is_read_only:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			slot_right_clicked.emit(self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(self, mb.button_index)
			if item_resource != null:
				_hide_custom_tooltip()
				var controller: ItemDragControllerScript = ItemSlot.get_drag_controller(get_tree())
				if controller != null:
					controller.begin_press(self, item_resource, _build_carry_payload(), carry_on_click)


func _build_carry_payload() -> Dictionary:
	var info: Dictionary = _get_display_info()
	var rarity_color: Color = Color(0.4, 0.5, 0.65, 1.0)
	var rarity_value: Variant = item_resource.get(&"rarity")
	if rarity_value != null:
		rarity_color = ItemTooltip.RARITY_COLORS[clampi(int(rarity_value), 0, 4)]
	return {
		"resource": item_resource,
		"source_slot": self,
		"context_tag": context_tag,
		"slot_index": slot_index,
		"slot_type": slot_type,
		"display_color": info["color"],
		"display_text": info["text"],
		"rarity_color": rarity_color,
		"icon": ItemIconsScript.get_icon_for(item_resource)
	}


## Atenúa el ícono mientras el ítem está en mano (protocolo de origen).
func set_carried(carried: bool) -> void:
	_is_carried = carried
	if center_container != null:
		center_container.modulate.a = 0.25 if carried else 1.0
	if hint_label != null:
		hint_label.modulate.a = 0.25 if carried else 1.0


# ==============================================================================
# Destino: recibir un ítem
# ==============================================================================

## Valida si este casillero puede recibir el recurso (protocolo de destino).
func can_accept_carried(res: Resource, payload: Dictionary) -> bool:
	if is_read_only or res == null or not is_resource_compatible(res):
		return false
	if accept_filter.is_valid():
		return bool(accept_filter.call(res, payload, self))
	return true


## Ejecuta la transferencia: las ventanas resuelven el movimiento real al escuchar la señal.
func receive_carried(payload: Dictionary) -> void:
	item_dropped_on_slot.emit(payload, self)


## Estado visual de destino: 0 ninguno, 1 candidato, 2 sobre válido, 3 sobre inválido.
func set_drop_state(state: int) -> void:
	if state == _drop_state:
		return
	_drop_state = state
	_pulse_time = 0.0
	set_process(state == DROP_CANDIDATE)
	queue_redraw()


func play_drop_pop() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(1.2, 1.2)
	var pop: Tween = create_tween()
	pop.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if _is_highlighted:
		draw_style_box(_border_box(Color(1.0, 0.85, 0.2, 1.0), 3), rect.grow(-1.0))
	elif _rarity_border.a > 0.0:
		draw_style_box(_border_box(_rarity_border, 2), rect.grow(-1.0))
	match _drop_state:
		DROP_CANDIDATE:
			var pulse: float = 0.5 + 0.5 * sin(_pulse_time * 6.0)
			draw_rect(rect, Color(0.3, 1.0, 0.5, 0.08 + 0.08 * pulse))
			draw_rect(rect, Color(0.3, 1.0, 0.5, 0.5 + 0.4 * pulse), false, 2.0)
		DROP_HOVER_OK:
			draw_rect(rect, Color(0.4, 1.0, 0.6, 0.3))
			draw_rect(rect, Color(0.65, 1.0, 0.75, 1.0), false, 3.0)
		DROP_HOVER_BAD:
			draw_rect(rect, Color(1.0, 0.25, 0.2, 0.25))
			draw_rect(rect, Color(1.0, 0.3, 0.25, 1.0), false, 2.0)
	if item_resource != null:
		_draw_badge(_price_text, _price_color, false)
		_draw_badge(_count_text, Color(0.9, 0.95, 1.0, 1.0), true)


## Placa pequeña con texto en una esquina del casillero (precio abajo a la derecha, cantidad arriba a la izquierda).
func _draw_badge(text: String, color: Color, top_left: bool) -> void:
	if text.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 10
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var plate_size: Vector2 = Vector2(text_size.x + 6.0, text_size.y + 1.0)
	var plate_pos: Vector2 = Vector2(2.0, 2.0) if top_left else Vector2(size.x - plate_size.x - 2.0, size.y - plate_size.y - 2.0)
	draw_rect(Rect2(plate_pos, plate_size), Color(0.04, 0.04, 0.06, 0.82))
	draw_string(font, plate_pos + Vector2(3.0, plate_size.y - 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _border_box(color: Color, width: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	return box


func is_resource_compatible(res: Resource) -> bool:
	if slot_type == "ANY":
		return true
	if slot_type == "WEAPON":
		return res is WeaponData
	if slot_type == "RUNE":
		return res is RuneData
	if slot_type in ["HEAD", "CHEST", "GLOVES", "BOOTS", "BACK", "TACTICAL", "ACCESSORY_1", "ACCESSORY_2"]:
		if res is ItemData:
			var item: ItemData = res as ItemData
			# Los accesorios comparten la categoría "ACCESSORY" y entran en cualquiera de sus dos ranuras
			if slot_type.begins_with("ACCESSORY"):
				return item.equip_slot.to_upper() == EquipmentManager.SLOT_ACCESSORY
			return item.equip_slot.to_upper() == slot_type
		return false
	return false


# ==============================================================================
# Tooltip
# ==============================================================================

func _on_mouse_entered() -> void:
	if item_resource == null or ItemSlot.is_carrying_item():
		return
	_show_custom_tooltip()


func _on_mouse_exited() -> void:
	_hide_custom_tooltip()


static func get_shared_tooltip(tree: SceneTree) -> ItemTooltip:
	if _shared_tooltip != null and is_instance_valid(_shared_tooltip):
		return _shared_tooltip

	var tooltip_scene: PackedScene = preload("res://ui/components/item_tooltip.tscn")
	_shared_tooltip = tooltip_scene.instantiate() as ItemTooltip

	if tree != null and tree.root != null:
		var canvas: CanvasLayer = tree.root.get_node_or_null("TooltipCanvasLayer") as CanvasLayer
		if canvas == null:
			canvas = CanvasLayer.new()
			canvas.name = "TooltipCanvasLayer"
			canvas.layer = 120
			tree.root.add_child(canvas)
		canvas.add_child(_shared_tooltip)

	return _shared_tooltip


## Controlador global del ítem en mano (se crea la primera vez que se necesita).
static func get_drag_controller(tree: SceneTree) -> ItemDragControllerScript:
	if _drag_controller != null and is_instance_valid(_drag_controller):
		return _drag_controller
	if tree == null or tree.root == null:
		return null
	_drag_controller = ItemDragControllerScript.new()
	_drag_controller.name = "ItemDragController"
	tree.root.add_child(_drag_controller)
	return _drag_controller


## true si hay un ítem levantado (sirve para suprimir tooltips y otras interacciones de UI).
static func is_carrying_item() -> bool:
	return _drag_controller != null and is_instance_valid(_drag_controller) and _drag_controller.is_carrying()


func _show_custom_tooltip() -> void:
	# El tooltip solo describe equipo; los consumibles (paleta del inventario) no tienen ficha
	if item_resource == null or item_resource is ConsumableDataScript:
		_hide_custom_tooltip()
		return
	var tt: ItemTooltip = ItemSlot.get_shared_tooltip(get_tree())
	if tt != null:
		tt.display_resource(item_resource, get_global_mouse_position())
		if not _tooltip_price_text.is_empty():
			tt.set_price_text(_tooltip_price_text)


func _hide_custom_tooltip() -> void:
	if _shared_tooltip != null and is_instance_valid(_shared_tooltip):
		_shared_tooltip.hide_tooltip()


func _exit_tree() -> void:
	_hide_custom_tooltip()
