class_name PlayerState
extends State
## Estado base especializado para el Player.
## Provee acceso fuertemente tipado a la instancia del Player y helpers
## compartidos para el manejo de física horizontal, gravedad y orientación.

## Referencia tipada al nodo Player propietario.
var player: Player = null


func _ready() -> void:
	if player == null:
		_resolve_player()


func _resolve_player() -> void:
	if owner is Player:
		player = owner as Player
	else:
		var node: Node = get_parent()
		while node != null:
			if node is Player:
				player = node as Player
				break
			node = node.get_parent()
	assert(player != null, "[PlayerState] No se pudo encontrar el nodo ancestro de tipo Player para '%s'." % name)


## Helper para calcular y aplicar aceleración o desaceleración horizontal.
func apply_horizontal_movement(delta: float, input_dir: float, is_airborne: bool = false) -> void:
	if player == null or player.movement_data == null:
		return
	
	# Empujón por contacto con enemigo: se conserva la velocidad que dio el golpe hasta que termine.
	if player.is_knocked_back():
		return
	if player.is_dashing():
		player.velocity.x = player.get_dash_velocity()
		return

	var effective_speed: float = player.get_current_move_speed()
	
	if player.has_magic_flight:
		var target_speed: float = input_dir * effective_speed
		player.velocity.x = target_speed
		if input_dir != 0.0:
			player.update_facing_direction(signf(input_dir))
		return
	
	var data: PlayerMovementData = player.movement_data
	var target_speed: float = input_dir * effective_speed
	var accel_rate: float
	
	if input_dir != 0.0:
		accel_rate = data.air_acceleration if is_airborne else data.acceleration
		player.update_facing_direction(signf(input_dir))
	else:
		accel_rate = data.air_friction if is_airborne else data.friction
	
	player.velocity.x = move_toward(player.velocity.x, target_speed, accel_rate * delta)


## Helper para aplicar gravedad estándar o acelerada en caída con mutadores de contratos.
func apply_gravity(delta: float, is_falling: bool = false) -> void:
	if player == null or player.movement_data == null:
		return
	
	if player.has_magic_flight:
		return
	
	if player.is_dashing():
		player.velocity.y = 0.0
		return
	
	var data: PlayerMovementData = player.movement_data
	var gravity_value: float = player.get_effective_gravity(is_falling)
	
	player.velocity.y = move_toward(player.velocity.y, data.max_fall_speed, gravity_value * delta)
