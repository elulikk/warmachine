class_name ArenaEncounter
extends Area2D
## Encuentro de arena: al entrar el jugador la cámara se congela en la zona y aparecen paredes invisibles
## en los bordes de la pantalla; arrancan las rondas del WaveManager hijo. Al superar la última ronda
## la cámara vuelve a seguir al jugador.
## Si el jugador es derrotado, el encuentro se reinicia para poder repetirse desde el checkpoint.

signal encounter_started
signal encounter_cleared

## Mitad del grosor de las paredes (12 px en el .tscn): la cara interior queda justo en el borde de la pantalla.
const WALL_HALF_WIDTH: float = 6.0
## Capa de las paredes (capa 6). Solo el jugador y las balas la tienen en la máscara: los enemigos la atraviesan
## para entrar desde fuera de la pantalla.
const WALL_LAYER: int = 32

@export var wave_manager_path: NodePath = ^"WaveManager"
@export var barriers_path: NodePath = ^"Barriers"
@export var status_label_path: NodePath = ^"StatusLabel"

var _wave_manager: WaveManager = null
var _status_label: Label = null
var _wall_left: StaticBody2D = null
var _wall_right: StaticBody2D = null
var _started: bool = false
var _cleared: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player
	body_entered.connect(_on_body_entered)

	_status_label = get_node_or_null(status_label_path) as Label

	var barriers_root: Node = get_node_or_null(barriers_path)
	if barriers_root != null:
		_wall_left = barriers_root.get_node_or_null("BarrierLeft") as StaticBody2D
		_wall_right = barriers_root.get_node_or_null("BarrierRight") as StaticBody2D
	_set_walls_active(false)

	_wave_manager = get_node_or_null(wave_manager_path) as WaveManager
	if _wave_manager != null:
		# Los enemigos nacen fuera de la pantalla y se acercan: así no aparecen de la nada
		_wave_manager.spawn_offscreen = true
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
	_lock_camera()
	_set_walls_active(true)
	encounter_started.emit()
	print("[ArenaEncounter] %s iniciada: cámara bloqueada." % name)
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
	_set_walls_active(false)
	_unlock_camera()
	_set_status_text("¡ZONA DESPEJADA! El paso está libre.")
	encounter_cleared.emit()
	print("[ArenaEncounter] %s despejada: cámara liberada." % name)


## Reinicia el encuentro si el jugador cae en combate, para que no quede trabado tras reaparecer.
func _on_player_defeated() -> void:
	if not _started or _cleared:
		return

	if _wave_manager != null:
		_wave_manager.stop_and_clear()
	_started = false
	_set_walls_active(false)
	_unlock_camera()
	_set_status_text("")
	print("[ArenaEncounter] %s reiniciada tras la derrota del jugador." % name)


## Congela la cámara en el centro de la arena y pone las paredes en los bordes de lo que se ve.
func _lock_camera() -> void:
	var camera: CameraFollow = get_tree().get_first_node_in_group(&"game_camera") as CameraFollow
	var trigger: CollisionShape2D = get_node_or_null(^"TriggerShape") as CollisionShape2D
	if camera == null or trigger == null or _wall_left == null or _wall_right == null:
		return

	var view_edges: Vector2 = camera.lock_horizontal(trigger.global_position.x)
	_wall_left.set_deferred("global_position", Vector2(view_edges.x - WALL_HALF_WIDTH, _wall_left.global_position.y))
	_wall_right.set_deferred("global_position", Vector2(view_edges.y + WALL_HALF_WIDTH, _wall_right.global_position.y))


func _unlock_camera() -> void:
	var camera: CameraFollow = get_tree().get_first_node_in_group(&"game_camera") as CameraFollow
	if camera != null:
		camera.unlock_horizontal()


func _set_walls_active(active: bool) -> void:
	if _wall_left == null or _wall_right == null:
		return
	if (_wall_left.collision_layer != 0) != active:
		GameFeel.sfx(self, &"barrier_close" if active else &"barrier_open", global_position)
	for wall: StaticBody2D in [_wall_left, _wall_right]:
		wall.set_deferred("collision_layer", WALL_LAYER if active else 0)


func _set_status_text(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
		_status_label.visible = not text.is_empty()
