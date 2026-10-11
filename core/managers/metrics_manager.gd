extends Node
## Gestor Central de Telemetría Global y Registro Histórico.
## Autoload (Singleton) con process_mode = PROCESS_MODE_ALWAYS.
## Rastrea estadísticas acumulativas de combate, economía, supervivencia y tiempo jugado.

signal metrics_updated

var total_enemies_killed: int = 0
var kills_by_type: Dictionary[String, int] = {}
var total_coins_collected: int = 0
var total_coins_spent: int = 0
var total_player_deaths: int = 0
var time_played_seconds: float = 0.0
var contracts_completed: int = 0

static var instance: MetricsManager = null


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_archetypes()


static func get_instance() -> MetricsManager:
	return instance


func _init_archetypes() -> void:
	if not kills_by_type.has("BasicRunner"):
		kills_by_type["BasicRunner"] = 0
	if not kills_by_type.has("ArmoredBrute"):
		kills_by_type["ArmoredBrute"] = 0
	if not kills_by_type.has("ShieldedSentinel"):
		kills_by_type["ShieldedSentinel"] = 0
	if not kills_by_type.has("SniperTurret"):
		kills_by_type["SniperTurret"] = 0


func _process(delta: float) -> void:
	# Acumular tiempo cuando se esté en una partida activa (no en menús estáticos principales)
	if _is_game_active():
		time_played_seconds += delta


func _is_game_active() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var cur: Node = tree.current_scene
	if cur == null:
		return false
	if cur is MainMenu:
		return false
	var path: String = cur.scene_file_path
	if path.ends_with("main_menu.tscn"):
		return false
	return true


func record_kill(enemy_type: String) -> void:
	total_enemies_killed += 1
	var current_count: int = kills_by_type.get(enemy_type, 0)
	kills_by_type[enemy_type] = current_count + 1
	metrics_updated.emit()
	print("[MetricsManager] Baja registrada: %s (Total: %d, Tipo: %d)" % [enemy_type, total_enemies_killed, kills_by_type[enemy_type]])


func record_coin_collected(amount: int) -> void:
	if amount <= 0:
		return
	total_coins_collected += amount
	metrics_updated.emit()


func record_coin_spent(amount: int) -> void:
	if amount <= 0:
		return
	total_coins_spent += amount
	metrics_updated.emit()
	print("[MetricsManager] Gasto de monedas registrado: -%d (Total gastado: %d)" % [amount, total_coins_spent])


func record_player_death() -> void:
	total_player_deaths += 1
	metrics_updated.emit()
	print("[MetricsManager] Muerte del jugador registrada (Total: %d)" % total_player_deaths)


func record_contract_completed() -> void:
	contracts_completed += 1
	metrics_updated.emit()
	print("[MetricsManager] Contrato completado registrado (Total: %d)" % contracts_completed)


func reset_metrics() -> void:
	total_enemies_killed = 0
	kills_by_type.clear()
	_init_archetypes()
	total_coins_collected = 0
	total_coins_spent = 0
	total_player_deaths = 0
	time_played_seconds = 0.0
	contracts_completed = 0
	metrics_updated.emit()


func serialize() -> Dictionary:
	var kills_dict: Dictionary = {}
	for k in kills_by_type.keys():
		kills_dict[k] = kills_by_type[k]
	return {
		"total_enemies_killed": total_enemies_killed,
		"kills_by_type": kills_dict,
		"total_coins_collected": total_coins_collected,
		"total_coins_spent": total_coins_spent,
		"total_player_deaths": total_player_deaths,
		"time_played_seconds": time_played_seconds,
		"contracts_completed": contracts_completed
	}


func deserialize(data: Dictionary) -> void:
	total_enemies_killed = int(data.get("total_enemies_killed", 0))
	var raw_kills: Dictionary = data.get("kills_by_type", {})
	kills_by_type.clear()
	_init_archetypes()
	for k in raw_kills.keys():
		kills_by_type[str(k)] = int(raw_kills[k])
	
	total_coins_collected = int(data.get("total_coins_collected", 0))
	total_coins_spent = int(data.get("total_coins_spent", 0))
	total_player_deaths = int(data.get("total_player_deaths", 0))
	time_played_seconds = float(data.get("time_played_seconds", 0.0))
	contracts_completed = int(data.get("contracts_completed", 0))
	metrics_updated.emit()


func get_formatted_time_played() -> String:
	var total_sec: int = int(time_played_seconds)
	var hours: int = total_sec / 3600
	var minutes: int = (total_sec % 3600) / 60
	var seconds: int = total_sec % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]
