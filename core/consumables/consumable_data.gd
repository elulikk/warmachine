extends Resource
## Definición de un consumible (poción) comprable en la tienda y usable con los atajos 4, 5 y 6.
## El orden en el catálogo de ConsumableManager determina su casillero.
## Sin class_name a propósito: se referencia por preload desde otros scripts.

enum Effect {
	HEAL,         ## Cura instantánea de `magnitude` puntos de vida.
	NO_RELOAD,    ## Durante `duration` s los disparos no consumen munición ni requieren recarga.
	SPEED_BOOST,  ## Durante `duration` s suma `magnitude` (0.2 = +20%) a la velocidad de movimiento.
}

@export var consumable_id: String = ""
@export var display_name: String = "Consumible"
@export var short_name: String = "ITEM"
@export_multiline var description: String = ""
@export var price: int = 10
@export var effect: Effect = Effect.HEAL
@export var magnitude: float = 0.0
@export var duration: float = 0.0
@export var color: Color = Color.WHITE
