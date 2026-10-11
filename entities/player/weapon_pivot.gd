class_name WeaponPivot
extends Node2D
## Pivote de apuntado continuo 360° para el Jugador.
## Detecta tanto la posición del mouse como la inclinación analógica del stick derecho del joystick.
## Ajusta la rotación y orientación vertical del arma para evitar inversión visual.

@export var stick_deadzone: float = 0.25

var last_aim_direction: Vector2 = Vector2.RIGHT
var player: Player = null


func _ready() -> void:
	player = owner as Player


func _process(_delta: float) -> void:
	_update_aim()


func _update_aim() -> void:
	# 1. Leer el stick derecho del primer joystick conectado
	var right_stick: Vector2 = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	
	var aim_dir: Vector2 = last_aim_direction
	
	if right_stick.length() > stick_deadzone:
		aim_dir = right_stick.normalized()
		last_aim_direction = aim_dir
	else:
		# 2. Si el stick no tiene deflexión, apuntar hacia el cursor del mouse
		var mouse_pos: Vector2 = get_global_mouse_position()
		var diff: Vector2 = mouse_pos - global_position
		if diff.length_squared() > 4.0:
			aim_dir = diff.normalized()
			last_aim_direction = aim_dir
	
	# Aplicar rotación continua
	rotation = aim_dir.angle()
	
	# 3. Orientación visual: si apunta a la izquierda, invertir eje Y local para no quedar cabeza abajo
	if aim_dir.x < 0.0:
		scale.y = -1.0
		if player != null:
			player.update_facing_direction(-1.0)
	else:
		scale.y = 1.0
		if player != null:
			player.update_facing_direction(1.0)


## Devuelve el vector de dirección normalizado hacia el que apunta actualmente el arma.
func get_aim_direction() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)
