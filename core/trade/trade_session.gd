extends RefCounted
## Lógica de una sesión de comercio entre el jugador y un comerciante (`trader_data.gd`).
## No toca la interfaz: la ventana (`ui/trade_window.gd`) solo muestra y dispara estas operaciones.
## Valida, cobra, mueve el ítem entre contenedores, mantiene stock limitado y recompra, y persiste.
## Sin class_name a propósito: se carga por `preload` (ver class-name-cache-gotcha).
##
## Todas las operaciones devuelven un `TradeResult`; nunca modifican nada si `ok` es false.
## Una operación que requiere confirmación devuelve `code == NEEDS_CONFIRM` con `confirm_text` y no
## cambia el estado hasta que se repite con `confirmed = true`.
##
## Decisiones:
## - Vender el equipo puesto lo desequipa solo (con confirmación); igual que con el baúl, el último
##   arma puede venderse (con confirmación: el personaje queda desarmado).
## - Comprar sigue la regla clásica del mercader: la armadura va a su ranura si está libre, las armas
##   al arsenal si hay lugar (máx. 3), y si no, a la mochila. Lo que ya se posee no se vuelve a comprar.
## - Las monedas de una venta no cuentan como "monedas recogidas" en las métricas.

const ConsumableManagerScript = preload("res://core/consumables/consumable_manager.gd")
const ConsumableDataScript = preload("res://core/consumables/consumable_data.gd")

enum TradeCode {
	OK,
	NEEDS_CONFIRM,
	NO_FUNDS,
	BAG_FULL,
	STACK_FULL,
	ALREADY_OWNED,
	OUT_OF_STOCK,
	NOT_SELLABLE,
	NOT_BUYING,
	NO_VALUE,
	INVALID,
}

const CAT_WEAPON: String = "WEAPON"
const CAT_RUNE: String = "RUNE"
const CAT_CONSUMABLE: String = "CONSUMABLE"
const CAT_OTHER: String = "OTHER"

## Una por casillero de la barra de acceso rápido (ver ui/hotbar.gd).
const MAX_ARSENAL: int = 9
const TAG_UNSELLABLE: Array[String] = ["QUEST", "KEY_ITEM"]


## Resultado tipado de una operación.
class TradeResult:
	var ok: bool = false
	var code: int = 0
	var message: String = ""
	## Monedas que cambian: positivo = gana el jugador, negativo = gasta.
	var coins_delta: int = 0
	var quantity: int = 0
	var confirm_text: String = ""

	func is_confirmation() -> bool:
		return not ok and not confirm_text.is_empty()


var trader: Resource = null
var player: Player = null

## Ofertas del comerciante: {path, res, consumable: bool, limit: int (-1 = infinito), remaining: int}.
var stock: Array[Dictionary] = []
## Ventas recientes recomprables: {kind: "gear", entry: Variant, price: int, _res: Resource}
## o {kind: "consumable", id: String, qty: int, price: int (por unidad)}.
var buyback: Array[Dictionary] = []

var _last_restock_unix: int = 0


func _init(trader_data: Resource, player_node: Player) -> void:
	trader = trader_data
	player = player_node
	_last_restock_unix = int(Time.get_unix_time_from_system())
	_build_stock()


# ==============================================================================
# Estado persistido (SaveManager.trade_state[trader_id])
# ==============================================================================

func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return

	var raw_stock: Variant = state.get("stock", {})
	if typeof(raw_stock) == TYPE_DICTIONARY:
		for offer: Dictionary in stock:
			var limit: int = int(offer["limit"])
			var path: String = str(offer["path"])
			if limit >= 0 and (raw_stock as Dictionary).has(path):
				offer["remaining"] = clampi(int((raw_stock as Dictionary)[path]), 0, limit)

	_last_restock_unix = int(state.get("restock_at", _last_restock_unix))

	buyback.clear()
	var raw_buyback: Variant = state.get("buyback", [])
	if typeof(raw_buyback) == TYPE_ARRAY:
		for raw: Variant in raw_buyback as Array:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = raw as Dictionary
			var kind: String = str(entry.get("kind", ""))
			if kind == "gear":
				var gear_entry: Variant = entry.get("entry", null)
				if gear_entry != null and SaveManager.stash_entry_to_resource(gear_entry) != null:
					buyback.append({"kind": "gear", "entry": gear_entry, "price": int(entry.get("price", 0))})
			elif kind == "consumable":
				var consumable_id: String = str(entry.get("id", ""))
				if _find_consumable(consumable_id) != null and int(entry.get("qty", 0)) > 0:
					buyback.append({
						"kind": "consumable",
						"id": consumable_id,
						"qty": int(entry.get("qty", 0)),
						"price": int(entry.get("price", 0))
					})
	_trim_buyback()
	_restock_if_due()


func serialize_state() -> Dictionary:
	var stock_state: Dictionary = {}
	for offer: Dictionary in stock:
		if int(offer["limit"]) >= 0:
			stock_state[str(offer["path"])] = int(offer["remaining"])
	var buyback_state: Array = []
	for entry: Dictionary in buyback:
		if str(entry["kind"]) == "gear":
			buyback_state.append({"kind": "gear", "entry": entry["entry"], "price": int(entry["price"])})
		else:
			buyback_state.append({
				"kind": "consumable",
				"id": str(entry["id"]),
				"qty": int(entry["qty"]),
				"price": int(entry["price"])
			})
	return {"stock": stock_state, "buyback": buyback_state, "restock_at": _last_restock_unix}


func _persist() -> void:
	var sm: SaveManager = SaveManager.get_instance()
	if sm == null:
		return
	sm.trade_state[str(trader.get("trader_id"))] = serialize_state()
	sm.save_to_disk()


# ==============================================================================
# Stock
# ==============================================================================

func _build_stock() -> void:
	stock.clear()
	var limits: Dictionary = trader.get("stock_limits") as Dictionary
	for path: String in trader.get("consumable_paths") as Array:
		_add_offer(path, true, limits)
	for path: String in trader.get("gear_paths") as Array:
		_add_offer(path, false, limits)


func _add_offer(path: String, is_consumable: bool, limits: Dictionary) -> void:
	if not ResourceLoader.exists(path):
		return
	var res: Resource = load(path) as Resource
	if res == null:
		return
	var limit: int = int(limits.get(path, -1))
	stock.append({
		"path": path,
		"res": res,
		"consumable": is_consumable,
		"limit": limit,
		"remaining": limit
	})


func _restock_if_due() -> void:
	var interval: float = float(trader.get("restock_seconds"))
	if interval <= 0.0:
		return
	var now: int = int(Time.get_unix_time_from_system())
	if float(now - _last_restock_unix) < interval:
		return
	for offer: Dictionary in stock:
		if int(offer["limit"]) >= 0:
			offer["remaining"] = int(offer["limit"])
	_last_restock_unix = now


# ==============================================================================
# Consultas de objeto (también las usa la interfaz para filtrar y ordenar)
# ==============================================================================

static func display_name_of(res: Resource) -> String:
	if res is ItemData:
		return (res as ItemData).item_name
	if res is WeaponData:
		return (res as WeaponData).weapon_name
	if res is RuneData:
		return (res as RuneData).rune_name
	if res is ConsumableDataScript:
		return (res as ConsumableDataScript).display_name
	return "Objeto"


static func rarity_of(res: Resource) -> int:
	var value: Variant = res.get(&"rarity") if res != null else null
	return clampi(int(value), 0, 4) if value != null else 0


## "WEAPON", "RUNE", "CONSUMABLE", la ranura de equipo ("HEAD", ..., "TACTICAL") u "OTHER".
static func category_of(res: Resource) -> String:
	if res is WeaponData:
		return CAT_WEAPON
	if res is RuneData:
		return CAT_RUNE
	if res is ConsumableDataScript:
		return CAT_CONSUMABLE
	if res is ItemData:
		var slot: String = (res as ItemData).equip_slot.to_upper()
		if slot != "NONE" and not slot.is_empty():
			return slot
	return CAT_OTHER


## Valor base en monedas (sin multiplicadores). Las armas suman el valor de sus runas engarzadas.
static func base_value_of(res: Resource) -> int:
	if res is WeaponData:
		var weapon: WeaponData = res as WeaponData
		var total: int = weapon.gold_value
		for rune: RuneData in weapon.socketed_runes:
			if rune != null:
				total += rune.gold_value
		return total
	if res is ItemData:
		return (res as ItemData).gold_value
	if res is RuneData:
		return (res as RuneData).gold_value
	if res is ConsumableDataScript:
		return (res as ConsumableDataScript).price
	return 0


## Precio por unidad que paga el jugador por un objeto del comerciante.
func buy_price_of(res: Resource) -> int:
	var base: int = base_value_of(res)
	if base <= 0:
		return 0
	return maxi(1, roundi(float(base) * float(trader.get("sale_price_multiplier"))))


## Precio por unidad que cobra el jugador al vender el objeto.
func sell_price_of(res: Resource) -> int:
	var base: int = base_value_of(res)
	if base <= 0:
		return 0
	return maxi(1, roundi(float(base) * float(trader.get("purchase_price_multiplier"))))


func buys_category(res: Resource) -> bool:
	if not bool(trader.get("buys_items")):
		return false
	var categories: Array = trader.get("buys_categories") as Array
	return categories.is_empty() or categories.has(category_of(res))


## Motivo por el que el objeto no se puede vender ("" si se puede), sin mirar dónde está.
## Devuelve [código, texto]; el código es TradeCode.OK si se puede.
func sell_block(res: Resource) -> Array:
	if res == null:
		return [TradeCode.INVALID, "No hay nada que vender."]
	if not bool(trader.get("buys_items")):
		return [TradeCode.NOT_BUYING, "Este comerciante no compra nada."]
	if not buys_category(res):
		return [TradeCode.NOT_BUYING, "No compro ese tipo de objeto."]
	if res is ItemData:
		for tag: String in (res as ItemData).tags:
			if TAG_UNSELLABLE.has(tag.to_upper()):
				return [TradeCode.NOT_SELLABLE, "Es un objeto clave: no se vende."]
	if not (res is ConsumableDataScript) and SaveManager.stash_resource_to_entry(res) == null:
		return [TradeCode.NOT_SELLABLE, "No se puede vender este objeto."]
	if sell_price_of(res) <= 0:
		return [TradeCode.NO_VALUE, "No vale nada."]
	return [TradeCode.OK, ""]


# ==============================================================================
# Inventario del jugador (lo que muestra la columna izquierda)
# ==============================================================================

## Todo lo del jugador: mochila, arsenal, equipo puesto y consumibles.
## Cada entrada: {res, context: "backpack"|"weapon"|"equipment"|"consumable", index, slot_type, count}.
func get_player_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if player == null:
		return entries

	if player.inventory_manager != null:
		for i in range(player.inventory_manager.backpack.size()):
			var stored: Resource = player.inventory_manager.backpack[i]
			if stored != null:
				entries.append({"res": stored, "context": "backpack", "index": i, "slot_type": "ANY", "count": 1})

	if player.weapon_manager != null:
		for i in range(player.weapon_manager.weapons.size()):
			var weapon: WeaponData = player.weapon_manager.weapons[i]
			if weapon != null:
				entries.append({"res": weapon, "context": "weapon", "index": i, "slot_type": "WEAPON", "count": 1})

	if player.equipment_manager != null:
		for slot: String in EquipmentManager.VALID_SLOTS:
			var worn: ItemData = player.equipment_manager.get_equipped_item(slot)
			if worn != null:
				entries.append({"res": worn, "context": "equipment", "index": -1, "slot_type": slot, "count": 1})

	if player.consumable_manager != null:
		for data: ConsumableDataScript in ConsumableManagerScript.get_catalog():
			var owned: int = player.consumable_manager.get_count(data.consumable_id)
			if owned > 0:
				entries.append({"res": data, "context": "consumable", "index": -1, "slot_type": "ANY", "count": owned})

	return entries


## Recompras para mostrar: {res, price (por unidad), qty, index, kind}.
func get_buyback_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in range(buyback.size()):
		var entry: Dictionary = buyback[i]
		var res: Resource = _buyback_resource(entry)
		if res == null:
			continue
		entries.append({
			"res": res,
			"price": int(entry["price"]),
			"qty": int(entry["qty"]) if str(entry["kind"]) == "consumable" else 1,
			"index": i,
			"kind": str(entry["kind"])
		})
	return entries


func _buyback_resource(entry: Dictionary) -> Resource:
	if str(entry["kind"]) == "consumable":
		return _find_consumable(str(entry["id"]))
	if not entry.has("_res"):
		entry["_res"] = SaveManager.stash_entry_to_resource(entry["entry"])
	return entry["_res"] as Resource


func _find_consumable(consumable_id: String) -> ConsumableDataScript:
	for data: ConsumableDataScript in ConsumableManagerScript.get_catalog():
		if data.consumable_id == consumable_id:
			return data
	return null


func coins() -> int:
	if player == null or player.stats_manager == null:
		return 0
	return player.stats_manager.coins


## true si el jugador ya posee este equipo (equipado, en arsenal, en mochila o en el baúl).
func player_owns(path: String) -> bool:
	if player == null or path.is_empty():
		return false

	if player.equipment_manager != null:
		for equipped: Variant in player.equipment_manager.equipped_items.values():
			var equipped_item: ItemData = equipped as ItemData
			if equipped_item != null and equipped_item.resource_path == path:
				return true

	if player.weapon_manager != null:
		for weapon: WeaponData in player.weapon_manager.weapons:
			if weapon != null and weapon.source_resource_path == path:
				return true

	if player.inventory_manager != null:
		for stored: Resource in player.inventory_manager.backpack:
			if stored == null:
				continue
			var stored_path: String = stored.resource_path
			var stored_weapon: WeaponData = stored as WeaponData
			if stored_weapon != null and stored_path.is_empty():
				stored_path = stored_weapon.source_resource_path
			if stored_path == path:
				return true

	var sm: SaveManager = SaveManager.get_instance()
	return sm != null and sm.stash_has_path(path)


# ==============================================================================
# Compra
# ==============================================================================

## Valida una compra sin tocar nada: cuántas unidades se pueden comprar ahora y, si ninguna, por qué.
func can_buy(offer: Dictionary, quantity: int = 1) -> TradeResult:
	if player == null or player.stats_manager == null or offer.is_empty():
		return _fail(TradeCode.INVALID, "No se puede comerciar ahora.")

	var res: Resource = offer["res"] as Resource
	var is_consumable: bool = bool(offer["consumable"])
	var price: int = buy_price_of(res)
	var wanted: int = maxi(1, quantity) if is_consumable else 1

	if int(offer["limit"]) >= 0:
		if int(offer["remaining"]) <= 0:
			return _fail(TradeCode.OUT_OF_STOCK, "Se agotó: %s." % display_name_of(res))
		wanted = mini(wanted, int(offer["remaining"]))

	if is_consumable:
		var data: ConsumableDataScript = res as ConsumableDataScript
		var room: int = ConsumableManagerScript.MAX_STACK - player.consumable_manager.get_count(data.consumable_id)
		if room <= 0:
			return _fail(TradeCode.STACK_FULL, "Ya tenés el máximo de %s (%d)." % [data.display_name, ConsumableManagerScript.MAX_STACK])
		wanted = mini(wanted, room)
	else:
		if player_owns(str(offer["path"])):
			return _fail(TradeCode.ALREADY_OWNED, "Ya tenés ese equipo.")
		if _gear_destination(res).is_empty():
			return _fail(TradeCode.BAG_FULL, "Mochila llena. Liberá un casillero.")

	if price > 0:
		var affordable: int = coins() / price
		if affordable <= 0:
			return _fail(TradeCode.NO_FUNDS, "No te alcanzan las monedas.")
		wanted = mini(wanted, affordable)

	var result: TradeResult = TradeResult.new()
	result.ok = true
	result.code = TradeCode.OK
	result.quantity = wanted
	result.coins_delta = -price * wanted
	return result


## Compra `quantity` unidades (consumibles; el equipo siempre es 1) de una oferta del stock.
func buy(offer: Dictionary, quantity: int = 1, confirmed: bool = false) -> TradeResult:
	var check: TradeResult = can_buy(offer, quantity)
	if not check.ok:
		return check

	var res: Resource = offer["res"] as Resource
	var total: int = -check.coins_delta

	if not confirmed:
		var reason: String = _buy_confirm_reason(res, total)
		if not reason.is_empty():
			return _confirmation("Comprar %s por %d monedas. %s" % [display_name_of(res), total, reason])

	if not player.stats_manager.spend_coins(total):
		return _fail(TradeCode.NO_FUNDS, "No te alcanzan las monedas.")

	var message: String = ""
	if bool(offer["consumable"]):
		var data: ConsumableDataScript = res as ConsumableDataScript
		player.consumable_manager.add(data.consumable_id, check.quantity)
		if check.quantity > 1:
			message = "Compraste %d× %s." % [check.quantity, data.display_name]
		else:
			message = "Compraste: %s." % data.display_name
	else:
		message = _give_gear(res, str(offer["path"]), "Compraste")

	if int(offer["limit"]) >= 0:
		offer["remaining"] = maxi(0, int(offer["remaining"]) - check.quantity)

	_persist()
	check.message = message
	return check


func _buy_confirm_reason(res: Resource, total: int) -> String:
	var rarity_limit: int = int(trader.get("confirm_rarity"))
	if rarity_limit <= 4 and rarity_of(res) >= rarity_limit and not (res is ConsumableDataScript):
		return "Es un objeto de rareza alta."
	var fraction: float = float(trader.get("confirm_coin_fraction"))
	if fraction > 0.0 and total >= int(trader.get("confirm_min_price")) and float(total) > float(coins()) * fraction:
		return "Es más de la mitad de tus monedas."
	return ""


## "equip" (ranura libre), "arsenal" (hay lugar), "backpack" o "" si no hay dónde ponerlo.
func _gear_destination(res: Resource) -> String:
	var item: ItemData = res as ItemData
	var weapon: WeaponData = res as WeaponData
	if item != null and player.equipment_manager != null:
		var target_slot: String = player.equipment_manager.get_target_slot_for_item(item)
		if not target_slot.is_empty() and player.equipment_manager.get_equipped_item(target_slot) == null:
			return "equip"
	elif weapon != null and player.weapon_manager != null and player.weapon_manager.weapons.size() < MAX_ARSENAL:
		return "arsenal"
	if player.inventory_manager != null and player.inventory_manager.has_free_space():
		return "backpack"
	return ""


## Entrega el equipo al jugador (ya cobrado) y devuelve el mensaje para mostrar.
func _give_gear(res: Resource, source_path: String, verb: String) -> String:
	var item: ItemData = res as ItemData
	var weapon: WeaponData = res as WeaponData
	var display_name: String = display_name_of(res)
	match _gear_destination(res):
		"equip":
			var target_slot: String = player.equipment_manager.get_target_slot_for_item(item)
			player.equipment_manager.equip_item(target_slot, item)
			return "%s y equipaste: %s." % [verb, display_name]
		"arsenal":
			player.weapon_manager.add_weapon(weapon, player.weapon_manager.weapons.is_empty())
			return "%s: %s (en tu arsenal)." % [verb, display_name]
		_:
			if weapon != null:
				var instance: WeaponData = weapon.duplicate() as WeaponData
				var path: String = source_path if not source_path.is_empty() else weapon.source_resource_path
				instance.source_resource_path = path
				player.inventory_manager.add_item(instance)
			else:
				player.inventory_manager.add_item(res)
			return "%s: %s (en la mochila)." % [verb, display_name]


# ==============================================================================
# Recompra
# ==============================================================================

func can_rebuy(buyback_index: int, quantity: int = 1) -> TradeResult:
	if player == null or player.stats_manager == null:
		return _fail(TradeCode.INVALID, "No se puede comerciar ahora.")
	if buyback_index < 0 or buyback_index >= buyback.size():
		return _fail(TradeCode.INVALID, "Ya no está disponible.")
	var entry: Dictionary = buyback[buyback_index]
	var res: Resource = _buyback_resource(entry)
	if res == null:
		return _fail(TradeCode.INVALID, "Ya no está disponible.")

	var price: int = int(entry["price"])
	var wanted: int = 1
	if str(entry["kind"]) == "consumable":
		var data: ConsumableDataScript = res as ConsumableDataScript
		var room: int = ConsumableManagerScript.MAX_STACK - player.consumable_manager.get_count(data.consumable_id)
		if room <= 0:
			return _fail(TradeCode.STACK_FULL, "Ya tenés el máximo de %s (%d)." % [data.display_name, ConsumableManagerScript.MAX_STACK])
		wanted = mini(maxi(1, quantity), mini(int(entry["qty"]), room))
	elif _gear_destination(res).is_empty():
		return _fail(TradeCode.BAG_FULL, "Mochila llena. Liberá un casillero.")

	if price > 0:
		var affordable: int = coins() / price
		if affordable <= 0:
			return _fail(TradeCode.NO_FUNDS, "No te alcanzan las monedas.")
		wanted = mini(wanted, affordable)

	var result: TradeResult = TradeResult.new()
	result.ok = true
	result.code = TradeCode.OK
	result.quantity = wanted
	result.coins_delta = -price * wanted
	return result


## Recompra un objeto vendido antes, al mismo precio al que se vendió.
func rebuy(buyback_index: int, quantity: int = 1) -> TradeResult:
	var check: TradeResult = can_rebuy(buyback_index, quantity)
	if not check.ok:
		return check

	var entry: Dictionary = buyback[buyback_index]
	var res: Resource = _buyback_resource(entry)
	var total: int = -check.coins_delta
	if not player.stats_manager.spend_coins(total):
		return _fail(TradeCode.NO_FUNDS, "No te alcanzan las monedas.")

	if str(entry["kind"]) == "consumable":
		var data: ConsumableDataScript = res as ConsumableDataScript
		player.consumable_manager.add(data.consumable_id, check.quantity)
		entry["qty"] = int(entry["qty"]) - check.quantity
		if int(entry["qty"]) <= 0:
			buyback.remove_at(buyback_index)
		check.message = "Recompraste %d× %s." % [check.quantity, data.display_name]
	else:
		var source_path: String = ""
		var weapon: WeaponData = res as WeaponData
		if weapon != null:
			source_path = weapon.source_resource_path
		check.message = _give_gear(res, source_path, "Recompraste")
		buyback.remove_at(buyback_index)

	_persist()
	return check


# ==============================================================================
# Venta
# ==============================================================================

## Valida la venta sin tocar nada. `quantity` solo cuenta para consumibles.
func can_sell(entry: Dictionary, quantity: int = 1) -> TradeResult:
	if player == null or player.stats_manager == null:
		return _fail(TradeCode.INVALID, "No se puede comerciar ahora.")
	var res: Resource = entry.get("res") as Resource
	var block: Array = sell_block(res)
	if int(block[0]) != TradeCode.OK:
		return _fail(int(block[0]), str(block[1]))
	if not _entry_is_valid(entry):
		return _fail(TradeCode.INVALID, "Ese objeto ya no está ahí.")

	var wanted: int = 1
	if str(entry.get("context", "")) == "consumable":
		var data: ConsumableDataScript = res as ConsumableDataScript
		wanted = clampi(quantity, 1, player.consumable_manager.get_count(data.consumable_id))

	var result: TradeResult = TradeResult.new()
	result.ok = true
	result.code = TradeCode.OK
	result.quantity = wanted
	result.coins_delta = sell_price_of(res) * wanted
	return result


## Vende al comerciante un objeto del jugador (entrada de `get_player_entries`).
func sell(entry: Dictionary, quantity: int = 1, confirmed: bool = false) -> TradeResult:
	var check: TradeResult = can_sell(entry, quantity)
	if not check.ok:
		return check

	var res: Resource = entry["res"] as Resource
	var context: String = str(entry["context"])

	if not confirmed:
		var reason: String = _sell_confirm_reason(entry)
		if not reason.is_empty():
			return _confirmation("Vender %s por %d monedas. %s" % [display_name_of(res), check.coins_delta, reason])

	# La entrada de recompra se arma antes de quitar el ítem (el arma conserva sus runas)
	var buyback_entry: Dictionary = {}
	if context == "consumable":
		var data: ConsumableDataScript = res as ConsumableDataScript
		buyback_entry = {"kind": "consumable", "id": data.consumable_id, "qty": check.quantity, "price": sell_price_of(res)}
	else:
		buyback_entry = {"kind": "gear", "entry": SaveManager.stash_resource_to_entry(res), "price": sell_price_of(res), "_res": res}

	if not _remove_from_player(entry, check.quantity):
		return _fail(TradeCode.INVALID, "Ese objeto ya no está ahí.")

	# Cobrar sin pasar por add_coins: una venta no es botín recogido para las métricas
	player.stats_manager.coins += check.coins_delta
	player.stats_manager.coins_changed.emit(player.stats_manager.coins)

	_push_buyback(buyback_entry)
	if context == "consumable":
		check.message = "Vendiste %d× %s por %d monedas." % [check.quantity, display_name_of(res), check.coins_delta]
	else:
		check.message = "Vendiste %s por %d monedas." % [display_name_of(res), check.coins_delta]

	_persist()
	return check


## Texto de confirmación (o "" si la venta no la requiere), sin vender nada.
func sell_confirm_reason(entry: Dictionary) -> String:
	return _sell_confirm_reason(entry)


func _sell_confirm_reason(entry: Dictionary) -> String:
	var res: Resource = entry["res"] as Resource
	var context: String = str(entry["context"])
	var reasons: Array[String] = []
	if context == "equipment":
		reasons.append("Está equipado: se desequipará.")
	if context == "weapon" and player.weapon_manager != null and player.weapon_manager.weapons.size() <= 1:
		reasons.append("Es tu última arma: quedarás desarmado.")
	var weapon: WeaponData = res as WeaponData
	if weapon != null and not weapon.socketed_runes.is_empty():
		reasons.append("Tiene %d runa(s) engarzada(s), incluidas en el precio." % weapon.socketed_runes.size())
	var rarity_limit: int = int(trader.get("confirm_rarity"))
	if rarity_limit <= 4 and rarity_of(res) >= rarity_limit and context != "consumable":
		reasons.append("Es de rareza alta.")
	return " ".join(reasons)


func _entry_is_valid(entry: Dictionary) -> bool:
	var res: Resource = entry.get("res") as Resource
	var index: int = int(entry.get("index", -1))
	match str(entry.get("context", "")):
		"backpack":
			return player.inventory_manager != null and player.inventory_manager.get_item_at(index) == res
		"weapon":
			return player.weapon_manager != null and index >= 0 and index < player.weapon_manager.weapons.size() and player.weapon_manager.weapons[index] == res
		"equipment":
			return player.equipment_manager != null and player.equipment_manager.get_equipped_item(str(entry.get("slot_type", ""))) == res
		"consumable":
			var data: ConsumableDataScript = res as ConsumableDataScript
			return data != null and player.consumable_manager != null and player.consumable_manager.get_count(data.consumable_id) > 0
	return false


func _remove_from_player(entry: Dictionary, quantity: int) -> bool:
	var res: Resource = entry["res"] as Resource
	var index: int = int(entry.get("index", -1))
	match str(entry["context"]):
		"backpack":
			if player.inventory_manager.get_item_at(index) != res:
				return false
			player.inventory_manager.remove_item_at(index)
			return true
		"weapon":
			var manager: WeaponManager = player.weapon_manager
			if index < 0 or index >= manager.weapons.size() or manager.weapons[index] != res:
				return false
			var holding: WeaponData = manager.current_weapon
			manager.weapons.remove_at(index)
			manager.weapon_magazines.erase(res as WeaponData)
			if manager.weapons.is_empty():
				manager.select_weapon(0)
			elif holding != null and holding != res and manager.weapons.has(holding):
				manager.select_weapon(manager.weapons.find(holding))
			else:
				manager.select_weapon(0)
			return true
		"equipment":
			var slot: String = str(entry["slot_type"])
			if player.equipment_manager.get_equipped_item(slot) != res:
				return false
			player.equipment_manager.unequip_item(slot)
			return true
		"consumable":
			var data: ConsumableDataScript = res as ConsumableDataScript
			if data == null:
				return false
			var owned: int = player.consumable_manager.get_count(data.consumable_id)
			if owned < quantity:
				return false
			player.consumable_manager.counts[data.consumable_id] = owned - quantity
			player.consumable_manager.counts_changed.emit()
			return true
	return false


func _push_buyback(entry: Dictionary) -> void:
	# Los consumibles iguales se juntan en una sola entrada (al mismo precio unitario)
	if str(entry["kind"]) == "consumable":
		for existing: Dictionary in buyback:
			if str(existing["kind"]) == "consumable" and str(existing["id"]) == str(entry["id"]) and int(existing["price"]) == int(entry["price"]):
				existing["qty"] = int(existing["qty"]) + int(entry["qty"])
				return
	buyback.push_front(entry)
	_trim_buyback()


func _trim_buyback() -> void:
	var limit: int = maxi(1, int(trader.get("buyback_limit")))
	while buyback.size() > limit:
		buyback.pop_back()


# ==============================================================================
# Resultados
# ==============================================================================

func _fail(code: int, message: String) -> TradeResult:
	var result: TradeResult = TradeResult.new()
	result.ok = false
	result.code = code
	result.message = message
	return result


func _confirmation(text: String) -> TradeResult:
	var result: TradeResult = TradeResult.new()
	result.ok = false
	result.code = TradeCode.NEEDS_CONFIRM
	result.confirm_text = text
	result.message = text
	return result
