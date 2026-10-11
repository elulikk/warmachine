extends Node
## Gestor de consumibles del jugador (hijo de Player).
## Guarda las cantidades (máximo MAX_STACK por tipo) y aplica los efectos al usarlos.
## Se usan desde la barra de acceso rápido (ui/hotbar.gd) o con los botones laterales del ratón (M4 / M5).
## Sin class_name a propósito: se referencia por preload desde otros scripts.

signal counts_changed
signal effect_started(consumable_id: String, duration: float)
signal effect_ended(consumable_id: String)
## Mensaje corto para el jugador (la barra lo muestra sobre sí misma).
signal message_posted(text: String)

const ConsumableDataScript = preload("res://core/consumables/consumable_data.gd")

const MAX_STACK: int = 5
const CATALOG_PATHS: Array[String] = [
	"res://data/consumables/health_potion.tres",
	"res://data/consumables/no_reload_potion.tres",
	"res://data/consumables/speed_potion.tres",
]

static var _catalog: Array[ConsumableDataScript] = []

## consumable_id (String) -> cantidad (int)
var counts: Dictionary = {}

var _active: Dictionary = {}
var _player: Player = null
var _applied_speed_bonus: float = 0.0


## Catálogo ordenado de consumibles (el índice es el orden en la barra de acceso rápido).
static func get_catalog() -> Array[ConsumableDataScript]:
	if _catalog.is_empty():
		for path in CATALOG_PATHS:
			var data: ConsumableDataScript = load(path) as ConsumableDataScript
			if data != null:
				_catalog.append(data)
	return _catalog


func _ready() -> void:
	_player = get_parent() as Player
	for data in get_catalog():
		if not counts.has(data.consumable_id):
			counts[data.consumable_id] = 0


func _exit_tree() -> void:
	for id in _active.keys():
		_end_effect(str(id), false)


func _unhandled_input(event: InputEvent) -> void:
	# Botones laterales del ratón: M4 usa el consumible 1 y M5 el 2 (sin pasar por la barra)
	for i in range(2):
		if event.is_action_pressed("consumable_%d" % (i + 1)):
			get_viewport().set_input_as_handled()
			use_slot(i)
			return


func _process(delta: float) -> void:
	if _active.is_empty():
		return

	for id in _active.keys():
		var remaining: float = float(_active[id]) - delta
		if remaining <= 0.0:
			_end_effect(str(id), true)
		else:
			_active[id] = remaining


# ==============================================================================
# Cantidades
# ==============================================================================

func get_count(consumable_id: String) -> int:
	return int(counts.get(consumable_id, 0))


func is_full(consumable_id: String) -> bool:
	return get_count(consumable_id) >= MAX_STACK


## Segundos que le quedan a un efecto temporizado activo (0 si no está activo).
func get_remaining(consumable_id: String) -> float:
	return float(_active.get(consumable_id, 0.0))


func is_active(consumable_id: String) -> bool:
	return _active.has(consumable_id)


## Agrega unidades respetando el máximo. Retorna cuántas se agregaron realmente.
func add(consumable_id: String, amount: int = 1) -> int:
	var current: int = get_count(consumable_id)
	var added: int = clampi(amount, 0, MAX_STACK - current)
	if added > 0:
		counts[consumable_id] = current + added
		counts_changed.emit()
	return added


func serialize() -> Dictionary:
	var out: Dictionary = {}
	for data in get_catalog():
		out[data.consumable_id] = get_count(data.consumable_id)
	return out


func deserialize(raw: Dictionary) -> void:
	counts.clear()
	for data in get_catalog():
		counts[data.consumable_id] = clampi(int(raw.get(data.consumable_id, 0)), 0, MAX_STACK)
	counts_changed.emit()


# ==============================================================================
# Uso y efectos
# ==============================================================================

## Usa el consumible del casillero indicado. Retorna true si se consumió una unidad.
func use_slot(slot_index: int) -> bool:
	var catalog: Array[ConsumableDataScript] = get_catalog()
	if slot_index < 0 or slot_index >= catalog.size():
		return false
	return use_consumable(catalog[slot_index].consumable_id)


## Usa una unidad del consumible indicado (lo llama la barra de acceso rápido). Retorna true si se consumió.
func use_consumable(consumable_id: String) -> bool:
	var data: ConsumableDataScript = _find_data(consumable_id)
	if data == null:
		return false
	if get_count(data.consumable_id) <= 0:
		_show_message("Sin %s" % data.display_name)
		return false

	if not _apply_effect(data):
		return false

	counts[data.consumable_id] = get_count(data.consumable_id) - 1
	counts_changed.emit()
	_show_message("%s usada" % data.display_name)
	GameFeel.sfx(self, &"potion", Vector2.INF, -3.0)
	return true


func _apply_effect(data: ConsumableDataScript) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false

	match data.effect:
		ConsumableDataScript.Effect.HEAL:
			var stats: StatsManager = _player.stats_manager
			if stats == null:
				return false
			if stats.current_health >= stats.get_max_health() - 0.01:
				_show_message("Ya tenés la vida completa")
				return false
			stats.heal(data.magnitude)
			return true

		ConsumableDataScript.Effect.NO_RELOAD:
			if _player.weapon_manager == null:
				return false
			_player.weapon_manager.set_free_ammo(true)
			_start_timed_effect(data)
			return true

		ConsumableDataScript.Effect.SPEED_BOOST:
			var stats_speed: StatsManager = _player.stats_manager
			if stats_speed == null:
				return false
			# Si ya estaba activo solo se renueva la duración (no se apila el bonus)
			if not _active.has(data.consumable_id):
				stats_speed.add_modifier("move_speed", data.magnitude, true)
				_applied_speed_bonus = data.magnitude
			_start_timed_effect(data)
			return true

	return false


func _start_timed_effect(data: ConsumableDataScript) -> void:
	_active[data.consumable_id] = data.duration
	effect_started.emit(data.consumable_id, data.duration)


func _end_effect(consumable_id: String, notify: bool) -> void:
	_active.erase(consumable_id)

	var data: ConsumableDataScript = _find_data(consumable_id)
	if data != null and _player != null and is_instance_valid(_player):
		match data.effect:
			ConsumableDataScript.Effect.NO_RELOAD:
				if _player.weapon_manager != null:
					_player.weapon_manager.set_free_ammo(false)
			ConsumableDataScript.Effect.SPEED_BOOST:
				if _player.stats_manager != null and _applied_speed_bonus != 0.0:
					_player.stats_manager.remove_modifier("move_speed", _applied_speed_bonus, true)
					_applied_speed_bonus = 0.0

	if notify:
		effect_ended.emit(consumable_id)


func _find_data(consumable_id: String) -> ConsumableDataScript:
	for data in get_catalog():
		if data.consumable_id == consumable_id:
			return data
	return null


func _show_message(text: String) -> void:
	message_posted.emit(text)
