extends Node
## Ambiente sonoro de las alcantarillas (1-03): goteos sueltos que suenan a los costados del jugador, de cerca y de lejos.
## Sin archivos: la gota es el sonido sintetizado `drip` de Sfx. Para usar audio real, `Sfx.register_override(&"drip", stream)`.
## Sin class_name: lo crea LevelBase (`preload`).

const SfxScript = preload("res://core/sfx.gd")

## Tiempo entre una gota y la siguiente (s); a veces cae una segunda enseguida.
const GAP_MIN: float = 0.35
const GAP_MAX: float = 2.6
const DOUBLE_CHANCE: float = 0.22
## Distancia horizontal al jugador a la que nace cada gota (px).
const SIDE_MIN: float = 80.0
const SIDE_MAX: float = 900.0

var _timer: Timer = null


func _ready() -> void:
	SfxScript.ensure_buses()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	_timer.start(randf_range(0.2, 1.0))


func _on_timeout() -> void:
	_drip()
	if randf() < DOUBLE_CHANCE:
		get_tree().create_timer(randf_range(0.12, 0.35)).timeout.connect(_drip)
	_timer.start(randf_range(GAP_MIN, GAP_MAX))


func _drip() -> void:
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	var side: float = -1.0 if randf() < 0.5 else 1.0
	var pos: Vector2 = player.global_position + Vector2(side * randf_range(SIDE_MIN, SIDE_MAX), -80.0)
	SfxScript.play(self, &"drip", pos, randf_range(-9.0, -3.0), randf_range(0.7, 1.5))
