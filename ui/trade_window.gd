extends DraggableWindow
## Ventana de comercio de dos columnas, reutilizable por cualquier comerciante (ver `TraderData`).
## Izquierda: lo del jugador (mochila, arsenal, equipo puesto, consumibles). Derecha: el stock del
## comerciante, con una pestaña de RECOMPRA con lo vendido. Se compra arrastrando del stock a la
## columna del jugador y se vende al revés; clic derecho = acción rápida (Mayús: lote de consumibles).
##
## La ventana solo muestra y dispara: toda la lógica (precios, reglas, cobro, persistencia) vive en
## `TradeSession` (core/trade/trade_session.gd). Los casilleros son `ItemSlot` de origen; los destinos
## son dos `TradeDropZone` que cubren cada columna, así se reutiliza el ítem en mano del proyecto.
## El contenido solo se reconstruye cuando no hay un ítem agarrado (si no, el origen desaparecería).
## Sin class_name a propósito: se referencia por la ruta de su escena.

const TradeSessionScript = preload("res://core/trade/trade_session.gd")
const TradeDropZoneScript = preload("res://ui/components/trade_drop_zone.gd")
const ConsumableManagerScript = preload("res://core/consumables/consumable_manager.gd")
const ConsumableDataScript = preload("res://core/consumables/consumable_data.gd")
const ItemSlotScene = preload("res://ui/components/item_slot.tscn")
const DefaultTrader = preload("res://data/traders/merchant.tres")

const WINDOW_SIZE: Vector2 = Vector2(920.0, 590.0)
const SLOT_SIZE: Vector2 = Vector2(54.0, 54.0)
const GRID_COLUMNS: int = 7

const CTX_PLAYER: String = "trade_player"
const CTX_STOCK: String = "trade_stock"
const CTX_BUYBACK: String = "trade_buyback"

const COLOR_GOLD: Color = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_NO_FUNDS: Color = Color(1.0, 0.38, 0.32, 1.0)
const COLOR_DIM: Color = Color(0.62, 0.58, 0.52, 1.0)
const COLOR_OK: Color = Color(0.5, 1.0, 0.65, 1.0)
const COLOR_WARN: Color = Color(1.0, 0.55, 0.4, 1.0)

## [clave de categoría de TradeSession, texto]. Clave vacía = todo.
const CATEGORY_FILTERS: Array = [
	["", "Todo"],
	["WEAPON", "Armas"],
	["HEAD", "Cabeza"],
	["CHEST", "Pecho"],
	["GLOVES", "Guantes"],
	["BOOTS", "Botas"],
	["BACK", "Espalda"],
	["ACCESSORY", "Accesorios"],
	["TACTICAL", "Tácticos"],
	["CONSUMABLE", "Consumibles"],
	["RUNE", "Runas"],
	["OTHER", "Otros"],
]
const SORT_LABELS: Array[String] = ["Orden original", "Precio: menor", "Precio: mayor", "Rareza", "Nombre"]
const SORT_ORIGINAL: int = 0
const SORT_PRICE_ASC: int = 1
const SORT_PRICE_DESC: int = 2
const SORT_RARITY: int = 3
const SORT_NAME: int = 4

## Milisegundos de espera tras soltar un ítem antes de reconstruir (dura más que la animación de vuelta).
const DROP_SETTLE_MSEC: int = 170

## Segundos que un casillero retirado de la grilla sigue vivo antes de liberarse.
const DETACHED_SLOT_LIFETIME: float = 0.6

const TAB_BUY: int = 0
const TAB_BUYBACK: int = 1


## Referencias a los controles de una columna (la ventana tiene dos).
class TradeColumn:
	var root: PanelContainer = null
	var title: Label = null
	var category: OptionButton = null
	var rarity: OptionButton = null
	var search: LineEdit = null
	var sort: OptionButton = null
	var grid: GridContainer = null
	var empty_label: Label = null
	var zone: Control = null


var player: Player = null

var _session: RefCounted = null
var _trader: Resource = null
var _player_col: TradeColumn = null
var _trader_col: TradeColumn = null
var _coins_label: Label = null
var _greeting_label: Label = null
var _status_label: Label = null
var _total_label: Label = null
var _confirm_bar: PanelContainer = null
var _confirm_label: Label = null
var _float_layer: Control = null
var _buy_tab_button: Button = null
var _buyback_tab_button: Button = null

var _tab: int = TAB_BUY
var _dirty: bool = false
var _player_view: Array[Dictionary] = []
var _stock_view: Array[Dictionary] = []
var _buyback_view: Array[Dictionary] = []
var _pending_action: Callable = Callable()
var _music_pushed: bool = false
var _last_busy_msec: int = -100000


func _ready() -> void:
	super._ready()
	window_title = "COMERCIO"
	visible = false
	custom_minimum_size = WINDOW_SIZE
	size = WINDOW_SIZE
	_build_ui()
	window_closed.connect(_on_window_closed)


func _process(_delta: float) -> void:
	if not visible:
		return
	# Con un ítem agarrado (o a punto de estarlo) no se tocan los casilleros: el origen debe sobrevivir
	var controller: Node = ItemSlot.get_drag_controller(get_tree())
	if controller != null and bool(controller.call(&"is_busy")):
		_last_busy_msec = Time.get_ticks_msec()
		return
	if not _dirty:
		return
	# Tras soltar, el ítem puede estar volando de vuelta a su casillero: se espera a que termine
	if Time.get_ticks_msec() - _last_busy_msec < DROP_SETTLE_MSEC:
		return
	_rebuild()


# ==============================================================================
# Apertura y cierre
# ==============================================================================

## Abre la ventana para un comerciante. Sin argumento usa el mercader por defecto.
func open_trade(trader_data: Resource = null) -> void:
	_bind_player()
	if player == null or player.stats_manager == null:
		return
	var data: Resource = trader_data if trader_data != null else DefaultTrader
	if data != _trader:
		_trader = data
		_reset_filters()
		_tab = TAB_BUY
	_open_session()

	window_title = str(_trader.get("display_name"))
	_greeting_label.text = str(_trader.get("greeting"))
	_say("", COLOR_OK)
	_cancel_pending()
	_rebuild()
	if not visible:
		if not _music_pushed:
			GameFeel.music_push(self, &"shop")
			_music_pushed = true
		super.open_window()
		_center_on_screen.call_deferred()


func open_window() -> void:
	open_trade(_trader)


## true si la ventana está abierta con ese comerciante.
func is_trading_with(trader_data: Resource) -> bool:
	return visible and _trader == trader_data


func _open_session() -> void:
	_session = TradeSessionScript.new(_trader, player)
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		var state: Variant = sm.trade_state.get(str(_trader.get("trader_id")), {})
		if typeof(state) == TYPE_DICTIONARY:
			_session.call(&"load_state", state as Dictionary)


func _center_on_screen() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	global_position = Vector2(
		maxf(10.0, (vp_size.x - size.x) * 0.5),
		maxf(10.0, (vp_size.y - size.y) * 0.5)
	)


func _on_window_closed() -> void:
	_cancel_pending()
	if _music_pushed:
		GameFeel.music_pop(self, &"shop")
		_music_pushed = false
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		sm.save_to_disk()


func _bind_player() -> void:
	var found: Player = get_tree().get_first_node_in_group(&"player") as Player
	if found == null or found == player:
		return
	player = found
	# Cualquier cambio externo (recoger un ítem, usar una poción) refresca las columnas
	if player.inventory_manager != null:
		player.inventory_manager.inventory_updated.connect(_on_player_changed)
	if player.stats_manager != null:
		player.stats_manager.coins_changed.connect(_on_player_changed)
	if player.consumable_manager != null:
		player.consumable_manager.counts_changed.connect(_on_player_changed)
	if player.weapon_manager != null:
		player.weapon_manager.weapon_changed.connect(_on_player_changed)
	if player.equipment_manager != null:
		player.equipment_manager.item_equipped.connect(_on_player_changed)
		player.equipment_manager.item_unequipped.connect(_on_player_changed)


func _on_player_changed(_a: Variant = null, _b: Variant = null) -> void:
	_dirty = true


# ==============================================================================
# Construcción de la interfaz
# ==============================================================================

func _build_ui() -> void:
	var content: Control = get_node("VBox/ContentContainer") as Control
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	content.add_child(root)

	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	root.add_child(top_bar)

	_coins_label = Label.new()
	_coins_label.text = "Monedas: 0"
	_coins_label.add_theme_font_size_override("font_size", 15)
	_coins_label.add_theme_color_override("font_color", COLOR_GOLD)
	top_bar.add_child(_coins_label)

	_greeting_label = Label.new()
	_greeting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_greeting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_greeting_label.clip_text = true
	_greeting_label.add_theme_font_size_override("font_size", 11)
	_greeting_label.add_theme_color_override("font_color", COLOR_DIM)
	top_bar.add_child(_greeting_label)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	root.add_child(columns)

	_player_col = _build_column("TUS PERTENENCIAS", false)
	_trader_col = _build_column("STOCK DEL COMERCIANTE", true)
	columns.add_child(_player_col.root)
	columns.add_child(_trader_col.root)

	_player_col.zone.set("accept_check", Callable(self, "_player_zone_accepts"))
	_player_col.zone.set("drop_handler", Callable(self, "_player_zone_drop"))
	_trader_col.zone.set("accept_check", Callable(self, "_trader_zone_accepts"))
	_trader_col.zone.set("drop_handler", Callable(self, "_trader_zone_drop"))

	_confirm_bar = PanelContainer.new()
	_confirm_bar.add_theme_stylebox_override("panel", SteamSkin.inset_style())
	_confirm_bar.visible = false
	root.add_child(_confirm_bar)
	var confirm_row: HBoxContainer = HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 10)
	_confirm_bar.add_child(confirm_row)
	_confirm_label = Label.new()
	_confirm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.add_theme_font_size_override("font_size", 12)
	_confirm_label.add_theme_color_override("font_color", COLOR_GOLD)
	confirm_row.add_child(_confirm_label)
	var accept_button: Button = Button.new()
	accept_button.text = "Confirmar"
	accept_button.custom_minimum_size = Vector2(100.0, 30.0)
	accept_button.pressed.connect(_on_confirm_pressed)
	confirm_row.add_child(accept_button)
	var cancel_button: Button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.custom_minimum_size = Vector2(100.0, 30.0)
	cancel_button.pressed.connect(_cancel_pending)
	confirm_row.add_child(cancel_button)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root.add_child(footer)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", COLOR_OK)
	footer.add_child(_status_label)
	_total_label = Label.new()
	_total_label.add_theme_font_size_override("font_size", 12)
	_total_label.add_theme_color_override("font_color", COLOR_GOLD)
	footer.add_child(_total_label)

	var hint: Label = Label.new()
	hint.text = "Arrastrá entre columnas, o clic derecho para comprar o vender. Mayús: lote de consumibles. Los números son precios en monedas."
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_DIM)
	root.add_child(hint)

	# Capa libre para el "+X / -X monedas" flotante (no participa del layout ni del ratón)
	_float_layer = Control.new()
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)


func _build_column(title_text: String, with_tabs: bool) -> TradeColumn:
	var col: TradeColumn = TradeColumn.new()
	col.root = PanelContainer.new()
	col.root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.root.add_theme_stylebox_override("panel", SteamSkin.inset_style())

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	col.root.add_child(box)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.custom_minimum_size = Vector2(0.0, 28.0) # misma altura con y sin pestañas: las columnas quedan alineadas
	box.add_child(header)
	col.title = Label.new()
	col.title.text = title_text
	col.title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.title.add_theme_font_size_override("font_size", 13)
	col.title.add_theme_color_override("font_color", COLOR_GOLD)
	header.add_child(col.title)
	if with_tabs:
		var group: ButtonGroup = ButtonGroup.new()
		_buy_tab_button = _make_tab_button("COMPRAR", group, TAB_BUY)
		_buyback_tab_button = _make_tab_button("RECOMPRA", group, TAB_BUYBACK)
		_buy_tab_button.button_pressed = true
		header.add_child(_buy_tab_button)
		header.add_child(_buyback_tab_button)

	var filters_a: HBoxContainer = HBoxContainer.new()
	filters_a.add_theme_constant_override("separation", 6)
	box.add_child(filters_a)
	col.category = OptionButton.new()
	col.category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.category.tooltip_text = "Filtrar por categoría"
	for entry: Array in CATEGORY_FILTERS:
		col.category.add_item(str(entry[1]))
	col.category.item_selected.connect(_on_filter_changed)
	filters_a.add_child(col.category)
	col.rarity = OptionButton.new()
	col.rarity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.rarity.tooltip_text = "Filtrar por rareza"
	col.rarity.add_item("Toda rareza")
	for rarity_idx in range(5):
		col.rarity.add_item(ItemTooltip.RARITY_NAMES[rarity_idx].capitalize())
	col.rarity.item_selected.connect(_on_filter_changed)
	filters_a.add_child(col.rarity)

	var filters_b: HBoxContainer = HBoxContainer.new()
	filters_b.add_theme_constant_override("separation", 6)
	box.add_child(filters_b)
	col.search = LineEdit.new()
	col.search.placeholder_text = "Buscar por nombre..."
	col.search.clear_button_enabled = true
	col.search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.search.text_changed.connect(_on_filter_changed)
	filters_b.add_child(col.search)
	col.sort = OptionButton.new()
	col.sort.tooltip_text = "Ordenar"
	for label: String in SORT_LABELS:
		col.sort.add_item(label)
	col.sort.item_selected.connect(_on_filter_changed)
	filters_b.add_child(col.sort)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, 300.0)
	box.add_child(scroll)

	var scroll_body: VBoxContainer = VBoxContainer.new()
	scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_body)

	col.grid = GridContainer.new()
	col.grid.columns = GRID_COLUMNS
	col.grid.add_theme_constant_override("h_separation", 4)
	col.grid.add_theme_constant_override("v_separation", 4)
	scroll_body.add_child(col.grid)

	col.empty_label = Label.new()
	col.empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.empty_label.add_theme_font_size_override("font_size", 11)
	col.empty_label.add_theme_color_override("font_color", COLOR_DIM)
	scroll_body.add_child(col.empty_label)

	# Último hijo: cubre toda la columna y queda debajo (en el orden de grupo) de cualquier casillero
	col.zone = TradeDropZoneScript.new() as Control
	col.root.add_child(col.zone)
	return col


func _make_tab_button(text: String, group: ButtonGroup, tab_id: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(92.0, 26.0)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(_on_tab_pressed.bind(tab_id))
	return button


func _reset_filters() -> void:
	for col: TradeColumn in [_player_col, _trader_col]:
		if col == null:
			continue
		col.category.select(0)
		col.rarity.select(0)
		col.sort.select(0)
		col.search.text = ""
	if _buy_tab_button != null:
		_buy_tab_button.button_pressed = true


func _on_filter_changed(_value: Variant = null) -> void:
	_dirty = true


func _on_tab_pressed(tab_id: int) -> void:
	_tab = tab_id
	_dirty = true


# ==============================================================================
# Reconstrucción de las columnas
# ==============================================================================

func _rebuild() -> void:
	_dirty = false
	if _session == null:
		return
	_coins_label.text = "Monedas: %d" % int(_session.call(&"coins"))
	_rebuild_player_column()
	_rebuild_trader_column()
	SteamSkin.skin_tree(self)


func _rebuild_player_column() -> void:
	_clear_grid(_player_col.grid)
	_player_view.clear()

	var entries: Array[Dictionary] = _session.call(&"get_player_entries")
	var order: int = 0
	var coins: int = int(_session.call(&"coins"))
	var views: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var res: Resource = entry["res"] as Resource
		if not _passes_filters(_player_col, res):
			continue
		var view: Dictionary = entry.duplicate()
		var block: Array = _session.call(&"sell_block", res)
		view["price"] = int(_session.call(&"sell_price_of", res))
		view["sellable"] = int(block[0]) == TradeSessionScript.TradeCode.OK
		view["reason"] = str(block[1])
		view["order"] = order
		order += 1
		views.append(view)
	_sort_views(views, _player_col.sort.selected)

	for i in range(views.size()):
		var view: Dictionary = views[i]
		_player_view.append(view)
		var res: Resource = view["res"] as Resource
		var context: String = str(view["context"])
		var sellable: bool = bool(view["sellable"])
		var count_text: String = ""
		if context == "consumable":
			count_text = "x%d" % int(view["count"])
		elif context == "equipment":
			count_text = "EQ"
		elif context == "weapon":
			count_text = "ARS"
		var price_text: String = str(int(view["price"])) if sellable else "—"
		var tip: String = "Venta: %d Monedas" % int(view["price"]) if sellable else ""
		var slot: ItemSlot = _make_slot(_player_col.grid, CTX_PLAYER, i, res, price_text, COLOR_GOLD if sellable else COLOR_DIM, count_text, tip)
		slot.modulate = Color(1, 1, 1, 1) if sellable else Color(1, 1, 1, 0.5)
		if res is ConsumableDataScript:
			slot.tooltip_text = _consumable_tooltip(res as ConsumableDataScript, "Venta", int(view["price"]), int(view["count"]), -1)
		elif not sellable:
			slot.tooltip_text = str(view["reason"])

	_player_col.empty_label.visible = views.is_empty()
	_player_col.empty_label.text = "No tenés nada con estos filtros." if not entries.is_empty() else "No llevás nada encima."


func _rebuild_trader_column() -> void:
	_clear_grid(_trader_col.grid)
	_stock_view.clear()
	_buyback_view.clear()
	_buyback_tab_button.text = "RECOMPRA (%d)" % (_session.get("buyback") as Array).size()
	if _tab == TAB_BUYBACK:
		_rebuild_buyback_view()
	else:
		_rebuild_stock_view()


func _rebuild_stock_view() -> void:
	var coins: int = int(_session.call(&"coins"))
	var views: Array[Dictionary] = []
	var order: int = 0
	for offer: Dictionary in (_session.get("stock") as Array):
		var res: Resource = offer["res"] as Resource
		if not _passes_filters(_trader_col, res):
			continue
		var view: Dictionary = {"offer": offer, "res": res, "order": order}
		view["price"] = int(_session.call(&"buy_price_of", res))
		order += 1
		views.append(view)
	_sort_views(views, _trader_col.sort.selected)

	for i in range(views.size()):
		var view: Dictionary = views[i]
		_stock_view.append(view)
		var offer: Dictionary = view["offer"]
		var res: Resource = view["res"] as Resource
		var price: int = int(view["price"])
		var is_consumable: bool = bool(offer["consumable"])
		var limited: bool = int(offer["limit"]) >= 0
		var remaining: int = int(offer["remaining"])

		var price_text: String = str(price)
		var price_color: Color = COLOR_GOLD if coins >= price else COLOR_NO_FUNDS
		var unavailable: bool = false
		var count_text: String = ""
		var native_tip: String = ""
		if is_consumable:
			var data: ConsumableDataScript = res as ConsumableDataScript
			var owned: int = player.consumable_manager.get_count(data.consumable_id)
			count_text = "%d/%d" % [owned, ConsumableManagerScript.MAX_STACK]
			if owned >= ConsumableManagerScript.MAX_STACK:
				price_text = "MÁX"
				price_color = COLOR_DIM
				unavailable = true
			native_tip = _consumable_tooltip(data, "Compra", price, owned, remaining if limited else -1)
		elif bool(_session.call(&"player_owns", str(offer["path"]))):
			price_text = "TENÉS"
			price_color = COLOR_DIM
			unavailable = true
		if limited:
			if remaining <= 0:
				price_text = "AGOTADO"
				price_color = COLOR_DIM
				unavailable = true
			elif not is_consumable:
				count_text = "x%d" % remaining
		var slot: ItemSlot = _make_slot(_trader_col.grid, CTX_STOCK, i, res, price_text, price_color, count_text, "Compra: %d Monedas" % price)
		slot.modulate = Color(1, 1, 1, 0.5) if unavailable else Color(1, 1, 1, 1)
		if not native_tip.is_empty():
			slot.tooltip_text = native_tip

	_trader_col.empty_label.visible = views.is_empty()
	_trader_col.empty_label.text = "Nada coincide con los filtros."


func _rebuild_buyback_view() -> void:
	var coins: int = int(_session.call(&"coins"))
	var entries: Array[Dictionary] = _session.call(&"get_buyback_entries")
	var views: Array[Dictionary] = []
	var order: int = 0
	for entry: Dictionary in entries:
		var res: Resource = entry["res"] as Resource
		if not _passes_filters(_trader_col, res):
			continue
		var view: Dictionary = entry.duplicate()
		view["order"] = order
		order += 1
		views.append(view)
	_sort_views(views, _trader_col.sort.selected)

	for i in range(views.size()):
		var view: Dictionary = views[i]
		_buyback_view.append(view)
		var res: Resource = view["res"] as Resource
		var price: int = int(view["price"])
		var qty: int = int(view["qty"])
		var price_color: Color = COLOR_GOLD if coins >= price else COLOR_NO_FUNDS
		var slot: ItemSlot = _make_slot(_trader_col.grid, CTX_BUYBACK, i, res, str(price), price_color, "x%d" % qty if qty > 1 else "", "Recompra: %d Monedas" % price)
		if res is ConsumableDataScript:
			slot.tooltip_text = _consumable_tooltip(res as ConsumableDataScript, "Recompra", price, -1, -1) + "\nDisponibles: %d" % qty

	_trader_col.empty_label.visible = views.is_empty()
	if _session.get("buyback").is_empty():
		_trader_col.empty_label.text = "Todavía no vendiste nada. Lo que vendas queda acá para recomprarlo."
	else:
		_trader_col.empty_label.text = "Nada coincide con los filtros."


func _clear_grid(grid: GridContainer) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		# Se liberan con demora: el ítem en mano puede estar volando de vuelta a este casillero
		get_tree().create_timer(DETACHED_SLOT_LIFETIME).timeout.connect(child.queue_free)


## Crea un casillero de origen (no es destino de soltado: eso lo hacen las zonas de cada columna).
func _make_slot(grid: GridContainer, context: String, index: int, res: Resource, price_text: String, price_color: Color, count_text: String, tooltip_price: String) -> ItemSlot:
	var slot: ItemSlot = ItemSlotScene.instantiate() as ItemSlot
	slot.slot_type = "ANY"
	slot.slot_index = index
	slot.context_tag = context
	slot.custom_minimum_size = SLOT_SIZE
	slot.slot_right_clicked.connect(_on_slot_right_clicked)
	grid.add_child(slot)
	slot.remove_from_group(&"drop_targets")
	slot.set_item(res)
	slot.set_trade_badges(price_text, price_color, count_text, tooltip_price)
	return slot


func _consumable_tooltip(data: ConsumableDataScript, price_label: String, price: int, owned: int, remaining: int) -> String:
	var lines: Array[String] = [data.display_name, data.description, "%s: %d Monedas" % [price_label, price]]
	if owned >= 0:
		lines.append("Tenés %d/%d" % [owned, ConsumableManagerScript.MAX_STACK])
	if remaining >= 0:
		lines.append("Stock: %d" % remaining)
	return "\n".join(lines)


# ==============================================================================
# Filtros y orden
# ==============================================================================

func _passes_filters(col: TradeColumn, res: Resource) -> bool:
	var category_key: String = str((CATEGORY_FILTERS[col.category.selected] as Array)[0])
	if not category_key.is_empty() and TradeSessionScript.category_of(res) != category_key:
		return false
	var rarity_idx: int = col.rarity.selected - 1
	if rarity_idx >= 0 and TradeSessionScript.rarity_of(res) != rarity_idx:
		return false
	var query: String = col.search.text.strip_edges().to_lower()
	if not query.is_empty() and not TradeSessionScript.display_name_of(res).to_lower().contains(query):
		return false
	return true


func _sort_views(views: Array[Dictionary], mode: int) -> void:
	match mode:
		SORT_PRICE_ASC:
			views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if int(a["price"]) != int(b["price"]):
					return int(a["price"]) < int(b["price"])
				return int(a["order"]) < int(b["order"]))
		SORT_PRICE_DESC:
			views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if int(a["price"]) != int(b["price"]):
					return int(a["price"]) > int(b["price"])
				return int(a["order"]) < int(b["order"]))
		SORT_RARITY:
			views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var ra: int = TradeSessionScript.rarity_of(a["res"] as Resource)
				var rb: int = TradeSessionScript.rarity_of(b["res"] as Resource)
				if ra != rb:
					return ra > rb
				return int(a["order"]) < int(b["order"]))
		SORT_NAME:
			views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var na: String = TradeSessionScript.display_name_of(a["res"] as Resource).to_lower()
				var nb: String = TradeSessionScript.display_name_of(b["res"] as Resource).to_lower()
				if na != nb:
					return na < nb
				return int(a["order"]) < int(b["order"]))
		_:
			views.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["order"]) < int(b["order"]))


# ==============================================================================
# Soltado entre columnas
# ==============================================================================

## Columna del jugador: recibe compras (del stock) y recompras.
func _player_zone_accepts(_res: Resource, payload: Dictionary) -> bool:
	if _session == null:
		return false
	var context: String = str(payload.get("context_tag", ""))
	var index: int = int(payload.get("slot_index", -1))
	if context == CTX_STOCK and index >= 0 and index < _stock_view.size():
		var offer: Dictionary = _stock_view[index]["offer"]
		return bool((_session.call(&"can_buy", offer, 1) as RefCounted).get("ok"))
	if context == CTX_BUYBACK and index >= 0 and index < _buyback_view.size():
		var buyback_index: int = int(_buyback_view[index]["index"])
		return bool((_session.call(&"can_rebuy", buyback_index, 1) as RefCounted).get("ok"))
	return false


func _player_zone_drop(payload: Dictionary) -> bool:
	var context: String = str(payload.get("context_tag", ""))
	var index: int = int(payload.get("slot_index", -1))
	var bulk: bool = Input.is_key_pressed(KEY_SHIFT)
	if context == CTX_STOCK and index >= 0 and index < _stock_view.size():
		if _stock_view[index]["res"] != payload.get("resource"):
			return false
		return _do_buy(_stock_view[index]["offer"], bulk)
	if context == CTX_BUYBACK and index >= 0 and index < _buyback_view.size():
		if _buyback_view[index]["res"] != payload.get("resource"):
			return false
		return _do_rebuy(int(_buyback_view[index]["index"]), bulk)
	return false


## Columna del comerciante: recibe ventas del jugador.
func _trader_zone_accepts(_res: Resource, payload: Dictionary) -> bool:
	if _session == null or str(payload.get("context_tag", "")) != CTX_PLAYER:
		return false
	var index: int = int(payload.get("slot_index", -1))
	if index < 0 or index >= _player_view.size():
		return false
	return bool((_session.call(&"can_sell", _player_view[index], 1) as RefCounted).get("ok"))


func _trader_zone_drop(payload: Dictionary) -> bool:
	var index: int = int(payload.get("slot_index", -1))
	if str(payload.get("context_tag", "")) != CTX_PLAYER or index < 0 or index >= _player_view.size():
		return false
	if _player_view[index]["res"] != payload.get("resource"):
		return false
	return _do_sell(_player_view[index], Input.is_key_pressed(KEY_SHIFT))


## Clic derecho: acción rápida según la columna de origen.
func _on_slot_right_clicked(slot: ItemSlot) -> void:
	if _session == null:
		return
	var index: int = slot.slot_index
	var bulk: bool = Input.is_key_pressed(KEY_SHIFT)
	match slot.context_tag:
		CTX_PLAYER:
			if index >= 0 and index < _player_view.size():
				_do_sell(_player_view[index], bulk)
		CTX_STOCK:
			if index >= 0 and index < _stock_view.size():
				_do_buy(_stock_view[index]["offer"], bulk)
		CTX_BUYBACK:
			if index >= 0 and index < _buyback_view.size():
				_do_rebuy(int(_buyback_view[index]["index"]), bulk)


# ==============================================================================
# Operaciones
# ==============================================================================

func _do_buy(offer: Dictionary, bulk: bool, confirmed: bool = false) -> bool:
	var quantity: int = ConsumableManagerScript.MAX_STACK if bulk and bool(offer["consumable"]) else 1
	var result: RefCounted = _session.call(&"buy", offer, quantity, confirmed)
	return _handle_result(result, func() -> void: _do_buy(offer, bulk, true))


func _do_rebuy(buyback_index: int, bulk: bool) -> bool:
	var quantity: int = ConsumableManagerScript.MAX_STACK if bulk else 1
	var result: RefCounted = _session.call(&"rebuy", buyback_index, quantity)
	return _handle_result(result, Callable())


func _do_sell(entry: Dictionary, bulk: bool, confirmed: bool = false) -> bool:
	var quantity: int = int(entry["count"]) if bulk and str(entry["context"]) == "consumable" else 1
	var result: RefCounted = _session.call(&"sell", entry, quantity, confirmed)
	return _handle_result(result, func() -> void: _do_sell(entry, bulk, true))


## Muestra el resultado de una operación. Devuelve true solo si se realizó.
func _handle_result(result: RefCounted, retry: Callable) -> bool:
	var ok: bool = bool(result.get("ok"))
	if ok:
		var delta: int = int(result.get("coins_delta"))
		_cancel_pending()
		_say(str(result.get("message")), COLOR_OK)
		_total_label.text = "Última operación: %+d monedas" % delta
		_float_coins(delta)
		GameFeel.sfx(self, &"coin" if delta > 0 else &"buy", Vector2.INF, -3.0)
		_dirty = true
		_coins_label.text = "Monedas: %d" % int(_session.call(&"coins"))
		_refresh_inventory_window()
		return true

	if bool(result.call(&"is_confirmation")) and retry.is_valid():
		_pending_action = retry
		_confirm_label.text = str(result.get("confirm_text"))
		_confirm_bar.visible = true
		_total_label.text = "Pendiente de confirmar"
		return false

	_cancel_pending()
	_say(str(result.get("message")), COLOR_WARN)
	GameFeel.sfx(self, &"deny", Vector2.INF, -4.0)
	return false


func _on_confirm_pressed() -> void:
	var action: Callable = _pending_action
	_pending_action = Callable()
	_confirm_bar.visible = false
	if action.is_valid():
		action.call()


func _cancel_pending() -> void:
	_pending_action = Callable()
	if _confirm_bar != null:
		_confirm_bar.visible = false
	if _total_label != null and _total_label.text == "Pendiente de confirmar":
		_total_label.text = ""


func _say(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


## "+X / -X monedas" que sube y se desvanece junto al contador.
func _float_coins(delta: int) -> void:
	if delta == 0 or _float_layer == null:
		return
	var label: Label = Label.new()
	label.text = "%+d monedas" % delta
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", COLOR_OK if delta > 0 else COLOR_NO_FUNDS)
	label.add_theme_color_override("font_outline_color", SteamSkin.COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(label)
	var origin: Vector2 = _coins_label.get_global_rect().position - _float_layer.get_global_rect().position
	label.position = origin + Vector2(_coins_label.size.x + 12.0, -2.0)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


## Mantiene sincronizada la mochila/arsenal si su ventana está abierta a la vez.
func _refresh_inventory_window() -> void:
	var inventory_window: InventoryWindow = get_tree().get_first_node_in_group(&"inventory_window") as InventoryWindow
	if inventory_window != null and inventory_window.visible:
		inventory_window.refresh_all()
