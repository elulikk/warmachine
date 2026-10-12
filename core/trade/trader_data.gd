extends Resource
## Definición de un comerciante (mercader, herrero que vende, etc.). Es solo datos: la lógica vive en
## `TradeSession` y la interfaz en `ui/trade_window.gd`.
## Sin class_name a propósito: se carga por `preload` / ruta de recurso (ver class-name-cache-gotcha).

## Identificador estable: clave del estado persistido (stock limitado y recompra) en el guardado.
@export var trader_id: String = "merchant"
@export var display_name: String = "MERCADER"
@export_multiline var greeting: String = ""

@export_group("Stock")
## Consumibles a la venta (rutas a ConsumableData `.tres`), en orden de aparición.
@export var consumable_paths: Array[String] = []
## Armas y equipo a la venta (rutas a WeaponData / ItemData / RuneData `.tres`), en orden de aparición.
@export var gear_paths: Array[String] = []
## Unidades disponibles por ruta. Lo que no figura acá es infinito (comportamiento clásico del mercader).
@export var stock_limits: Dictionary = {}
## Segundos (reloj real) tras los que el stock limitado se repone. 0 = nunca se repone.
@export var restock_seconds: float = 0.0
## MODO PRUEBA: vende todo lo que existe en `data/` (armas, equipo, runas, consumibles) sin límite de cantidad,
## ignorando `gear_paths`, `consumable_paths` y `stock_limits`. Apagarlo para volver al stock normal.
@export var sell_everything: bool = false

@export_group("Precios")
## Multiplicador sobre el valor del objeto al que el comerciante VENDE (lo que paga el jugador).
@export var sale_price_multiplier: float = 1.0
## Multiplicador sobre el valor del objeto al que el comerciante COMPRA (lo que cobra el jugador).
@export var purchase_price_multiplier: float = 0.4

@export_group("Compra al jugador")
## Si es false, el comerciante solo vende.
@export var buys_items: bool = true
## Categorías que acepta comprar ("WEAPON", "RUNE", "CONSUMABLE", "HEAD", "CHEST", "GLOVES", "BOOTS",
## "BACK", "ACCESSORY", "TACTICAL", "OTHER"). Vacío = acepta todo.
@export var buys_categories: Array[String] = []
## Cuántas ventas recientes quedan disponibles para recomprar.
@export var buyback_limit: int = 12

@export_group("Confirmaciones")
## Rareza (0-4) desde la que se pide confirmación al comprar o vender. 5 = nunca.
@export var confirm_rarity: int = 3
## Se confirma cuando la compra supera esta fracción de las monedas del jugador (0 = nunca).
@export var confirm_coin_fraction: float = 0.5
## Piso: las compras baratas no piden confirmación aunque superen la fracción.
@export var confirm_min_price: int = 40
