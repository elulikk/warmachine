extends Control
## Zona de soltado grande para el comercio: cubre una columna entera de la ventana de comercio.
## Sin class_name a propósito: se carga por `preload` (ver class-name-cache-gotcha).
##
## Habla el protocolo de destino del `ItemDragController` (ver su cabecera), pero en vez de guardar un
## ítem delega la decisión en dos Callables de la ventana:
##   accept_check: func(res: Resource, payload: Dictionary) -> bool   (¿se puede soltar acá?)
##   drop_handler: func(payload: Dictionary) -> bool                  (ejecuta la operación; true = hecha)
## Es transparente al ratón (el controlador la busca por rectángulo) y debe ser el último hijo de la
## columna: así los casilleros —que no son destinos en esta ventana— no la tapan.

const ItemDragControllerScript = preload("res://ui/components/item_drag_controller.gd")

var accept_check: Callable = Callable()
var drop_handler: Callable = Callable()

var _drop_state: int = 0
var _pulse_time: float = 0.0
## Ítem confirmado por la operación en curso: el controlador pregunta `get_item()` justo después de
## `receive_carried` para saber si el soltado tuvo éxito.
var _acknowledged: Resource = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(ItemDragControllerScript.TARGETS_GROUP)
	set_process(false)


func get_item() -> Resource:
	return _acknowledged


func can_accept_carried(res: Resource, payload: Dictionary) -> bool:
	return accept_check.is_valid() and bool(accept_check.call(res, payload))


func receive_carried(payload: Dictionary) -> void:
	if not drop_handler.is_valid():
		return
	if bool(drop_handler.call(payload)):
		_acknowledged = payload.get("resource") as Resource
		_clear_acknowledgement.call_deferred()


func _clear_acknowledgement() -> void:
	_acknowledged = null


## El ítem en mano sigue al cursor sobre esta zona (no salta al centro de la columna).
func wants_cursor_ghost() -> bool:
	return true


func set_drop_state(state: int) -> void:
	if state == _drop_state:
		return
	_drop_state = state
	_pulse_time = 0.0
	set_process(state == ItemDragControllerScript.DROP_CANDIDATE)
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	match _drop_state:
		ItemDragControllerScript.DROP_CANDIDATE:
			var pulse: float = 0.5 + 0.5 * sin(_pulse_time * 6.0)
			draw_rect(rect, Color(0.3, 1.0, 0.5, 0.04 + 0.05 * pulse))
			draw_rect(rect, Color(0.3, 1.0, 0.5, 0.35 + 0.35 * pulse), false, 2.0)
		ItemDragControllerScript.DROP_HOVER_OK:
			draw_rect(rect, Color(0.4, 1.0, 0.6, 0.16))
			draw_rect(rect, Color(0.65, 1.0, 0.75, 1.0), false, 3.0)
		ItemDragControllerScript.DROP_HOVER_BAD:
			draw_rect(rect, Color(1.0, 0.25, 0.2, 0.14))
			draw_rect(rect, Color(1.0, 0.3, 0.25, 1.0), false, 2.0)
