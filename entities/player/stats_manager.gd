class_name StatsManager
extends Node
## Gestor dinámico de estadísticas, progresión de nivel y modificadores de ítems para el Jugador.
## Calcula estadísticas finales usando la fórmula: (Base + Suma_Plana) * (1.0 + Suma_Porcentual).

signal health_changed(current: float, max: float)
signal exp_changed(current: float, max: float)
signal leveled_up(new_level: int)
## Se emite solo cuando el nivel se gana jugando (no al cargar una partida).
signal level_gained(new_level: int)
signal coins_changed(new_coins: int)
signal stats_recalculated

## Nivel máximo del prototipo.
const MAX_LEVEL: int = 10
## Vida máxima extra por cada nivel sobre el 1.
const HEALTH_PER_LEVEL: float = 10.0
## Multiplicador de daño extra por cada nivel sobre el 1 (0.03 = +3%).
const DAMAGE_PER_LEVEL: float = 0.03

@export_group("Estadísticas Base")
@export var base_max_health: float = 100.0
@export var base_move_speed: float = 140.0
@export var base_max_jumps: int = 1
@export var base_damage_multiplier: float = 1.0
@export var base_crit_chance: float = 0.15 # 15% probabilidad de impacto crítico base
@export var base_crit_multiplier: float = 1.5 # 150% multiplicador de daño crítico base

@export_group("Progresión")
@export var level: int = 1
@export var current_exp: float = 0.0
@export var exp_to_next_level: float = 150.0

var current_health: float = 100.0
var coins: int = 0

# Diccionarios de modificadores acumulativos
var flat_modifiers: Dictionary = {
	"move_speed": 0.0,
	"max_health": 0.0,
	"max_jumps": 0.0,
	"damage_multiplier": 0.0,
	"crit_chance": 0.0,
	"crit_multiplier": 0.0,
	"armor": 0.0
}

var percent_modifiers: Dictionary = {
	"move_speed": 0.0,
	"max_health": 0.0,
	"damage_multiplier": 0.0,
	"crit_chance": 0.0,
	"crit_multiplier": 0.0
}


func _ready() -> void:
	current_health = get_max_health()
	health_changed.emit(current_health, get_max_health())
	exp_changed.emit(current_exp, exp_to_next_level)
	coins_changed.emit(coins)



# ==============================================================================
# Fórmulas de Estadísticas Finales: (Base + Flat) * (1.0 + Percent)
# ==============================================================================

## Retorna la salud máxima calculada con modificadores planos y porcentuales.
func get_max_health() -> float:
	var flat: float = flat_modifiers.get("max_health", 0.0)
	var pct: float = percent_modifiers.get("max_health", 0.0)
	var level_bonus: float = HEALTH_PER_LEVEL * float(maxi(0, level - 1))
	return maxf(1.0, (base_max_health + level_bonus + flat) * (1.0 + pct))


## Retorna la velocidad horizontal calculada.
func get_move_speed() -> float:
	var flat: float = flat_modifiers.get("move_speed", 0.0)
	var pct: float = percent_modifiers.get("move_speed", 0.0)
	return maxf(50.0, (base_move_speed + flat) * (1.0 + pct))


## Retorna la cantidad máxima de saltos disponibles (ej: 1 normal, 2 doble salto).
func get_max_jumps() -> int:
	var flat: float = flat_modifiers.get("max_jumps", 0.0)
	return maxi(1, int(base_max_jumps + flat))


## Retorna el multiplicador global de daño del jugador.
func get_damage_multiplier() -> float:
	var flat: float = flat_modifiers.get("damage_multiplier", 0.0)
	var pct: float = percent_modifiers.get("damage_multiplier", 0.0)
	var level_bonus: float = DAMAGE_PER_LEVEL * float(maxi(0, level - 1))
	return maxf(0.1, (base_damage_multiplier + level_bonus + flat) * (1.0 + pct))


## Retorna la armadura total del jugador (suma de ítems equipados). Mitiga daño recibido: 100 / (100 + armadura).
func get_armor() -> float:
	var flat: float = flat_modifiers.get("armor", 0.0)
	var pct: float = percent_modifiers.get("armor", 0.0)
	return maxf(0.0, flat * (1.0 + pct))


## Retorna el porcentaje de daño recibido que absorbe la armadura actual (0 a 100).
func get_armor_mitigation_percent() -> float:
	var armor_val: float = get_armor()
	return armor_val / (100.0 + armor_val) * 100.0


## Retorna la probabilidad final de impacto crítico (0.0 a 1.0).
func get_crit_chance() -> float:
	var flat: float = flat_modifiers.get("crit_chance", 0.0)
	var pct: float = percent_modifiers.get("crit_chance", 0.0)
	return clampf((base_crit_chance + flat) * (1.0 + pct), 0.0, 1.0)


## Retorna el multiplicador de daño crítico (mínimo 1.0).
func get_crit_multiplier() -> float:
	var flat: float = flat_modifiers.get("crit_multiplier", 0.0)
	var pct: float = percent_modifiers.get("crit_multiplier", 0.0)
	return maxf(1.0, (base_crit_multiplier + flat) * (1.0 + pct))


# ==============================================================================
# Sistema de Modificadores Externos (Ítems / Buffs)
# ==============================================================================

## Agrega un modificador plano o porcentual a una estadística específica.
func add_modifier(stat_name: String, value: float, is_percent: bool = false) -> void:
	if is_percent:
		percent_modifiers[stat_name] = percent_modifiers.get(stat_name, 0.0) + value
	else:
		flat_modifiers[stat_name] = flat_modifiers.get(stat_name, 0.0) + value
	
	# Ajustar salud actual si la salud máxima cambió
	current_health = minf(current_health, get_max_health())
	stats_recalculated.emit()
	health_changed.emit(current_health, get_max_health())


## Retira un modificador plano o porcentual de una estadística específica.
func remove_modifier(stat_name: String, value: float, is_percent: bool = false) -> void:
	if is_percent:
		percent_modifiers[stat_name] = percent_modifiers.get(stat_name, 0.0) - value
	else:
		flat_modifiers[stat_name] = flat_modifiers.get(stat_name, 0.0) - value
	
	# Ajustar salud actual si la salud máxima disminuyó
	current_health = minf(current_health, get_max_health())
	stats_recalculated.emit()
	health_changed.emit(current_health, get_max_health())



# ==============================================================================
# Sistema de Experiencia y Nivel
# ==============================================================================

## Acumula experiencia y gestiona la subida de nivel con mejoras automáticas.
func add_experience(amount: float) -> void:
	if level >= MAX_LEVEL:
		return
	current_exp += amount

	while current_exp >= exp_to_next_level and level < MAX_LEVEL:
		current_exp -= exp_to_next_level
		level += 1

		# Las mejoras por nivel (vida y daño) se derivan de `level` en get_max_health() y
		# get_damage_multiplier(), así sobreviven al guardado y carga de la partida.
		# Curación completa de regalo al subir de nivel
		current_health = get_max_health()

		# Progresión geométrica de experiencia para la siguiente meta
		exp_to_next_level = roundf(exp_to_next_level * 1.5)

		GameFeel.sfx(self, &"levelup", Vector2.INF, -2.0)
		leveled_up.emit(level)
		level_gained.emit(level)
		stats_recalculated.emit()
		health_changed.emit(current_health, get_max_health())
		print("[StatsManager] ¡SUBIDA DE NIVEL! Nivel alcanzado: %d. Salud restaurada al máximo (%.0f)." % [level, current_health])

	# En el nivel máximo la barra queda llena y la experiencia deja de acumularse
	if level >= MAX_LEVEL:
		current_exp = exp_to_next_level

	exp_changed.emit(current_exp, exp_to_next_level)


# ==============================================================================
# Gestión de Salud y Daño
# ==============================================================================

## Aplica daño recibido a la salud actual del jugador.
func take_damage(amount: float) -> void:
	var prev_health: float = current_health
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, get_max_health())
	print("[StatsManager] Jugador recibió %.1f de daño. Salud restante: %.1f / %.1f" % [amount, current_health, get_max_health()])


## Restaura salud sin sobrepasar el máximo.
func heal(amount: float) -> void:
	current_health = minf(get_max_health(), current_health + amount)
	health_changed.emit(current_health, get_max_health())


## Añade monedas a la reserva del jugador y notifica al HUD.
func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	var metrics_mgr: MetricsManager = MetricsManager.get_instance()
	if metrics_mgr != null:
		metrics_mgr.record_coin_collected(amount)
	coins_changed.emit(coins)


## Descuenta monedas de la reserva del jugador y registra la telemetría de gasto.
func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
	if coins < amount:
		return false
	coins -= amount
	var metrics_mgr: MetricsManager = MetricsManager.get_instance()
	if metrics_mgr != null:
		metrics_mgr.record_coin_spent(amount)
	coins_changed.emit(coins)
	print("[StatsManager] -%d moneda(s) gastada(s). Restante: %d" % [amount, coins])
	return true

