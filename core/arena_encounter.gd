class_name ArenaEncounter
extends Area2D
## Encuentro de arena: al entrar el jugador se cierran las barreras y arrancan las rondas
## del WaveManager hijo. Al superar la última ronda las barreras se abren.
## Si el jugador es derrotado, el encuentro se reinicia para poder repetirse desde el checkpoint.

signal encounter_started
signal encounter_cleared

@export var wave_manager_path: NodePath = ^"WaveManager"
@export var barriers_path: NodePath = ^"Barriers"
@export var status_label_path: NodePath = ^"StatusLabel"

var _wave_manager: WaveManager = null
var _status_label: Label = null
var _barriers: Array[StaticBody2D] = []
var _started: bool = false
var _cleared: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player
	body_entered.connect(_on_body_entered)

	_status_label = get_node_or_null(status_label_path) as Label

	var barriers_root: Node = get_node_or_null(barriers_path)
	if barriers_root != null:
		for child: Node in barriers_root.get_children():
			if child is StaticBody2D:
				_barriers.append(child as StaticBody2D)
	_set_barriers_locked(false)

	_wave_manager = get_node_or_null(wave_manager_path) as WaveManager
	if _wave_manager != null:
		_wave_manager.round_started.connect(_on_round_started)
		_wave_manager.round_cleared.connect(_on_round_cleared)
		_wave_manager.all_rounds_cleared.connect(_on_all_rounds_cleared)

	var gm: GameManager = GameManager.get_instance() as GameManager
	if gm != null and not gm.game_over_triggered.is_connected(_on_player_defeated):
		gm.game_over_triggered.connect(_on_player_defeated)

	_set_status_text("")


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player) or _started or _cleared or _wave_manager == null:
		return

	_started = true
	_set_barriers_locked(true)
	encounter_started.emit()
	print("[ArenaEncounter] %s iniciada: barreras cerradas." % name)
	# Diferido: body_entered ocurre durante el flush de física y no se pueden instanciar cuerpos ahí
	_wave_manager.start.call_deferred()


func _on_round_started(round_number: int, enemy_count: int) -> void:
	var total_rounds: int = _wave_manager.round_sizes.size() if _wave_manager != null else 1
	_set_status_text("OLEADA %d/%d — %d enemigos" % [round_number, total_rounds, enemy_count])


func _on_round_cleared(round_number: int) -> void:
	var total_rounds: int = _wave_manager.round_sizes.size() if _wave_manager != null else 1
	if round_number < total_rounds:
		_set_status_text("Oleada superada. Preparate...")


func _on_all_rounds_cleared() -> void:
	_cleared = true
	_set_barriers_locked(false)
	_set_status_text("¡ZONA DESPEJADA! El paso está libre.")
	encounter_cleared.emit()
	print("[ArenaEncounter] %s despejada: barreras abiertas." % name)


## Reinicia el encuentro si el jugador cae en combate, para que no quede trabado tras reaparecer.
func _on_player_defeated() -> void:
	if not _started or _cleared:
		return

	if _wave_manager != null:
		_wave_manager.stop_and_clear()
	_started = false
	_set_barriers_locked(false)
	_set_status_text("")
	print("[ArenaEncounter] %s reiniciada tras la derrota del jugador." % name)


func _set_barriers_locked(locked: bool) -> void:
	for barrier in _barriers:
		if barrier.visible != locked:
			GameFeel.sfx(self, &"barrier_close" if locked else &"barrier_open", global_position)
			break
	for barrier in _barriers:
		barrier.visible = locked
		barrier.set_deferred("collision_layer", 1 if locked else 0)


func _set_status_text(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
		_status_label.visible = not text.is_empty()
