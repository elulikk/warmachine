extends BasicRunner
## Fantasma: flota hacia el jugador en cualquier dirección, ondulando, y atraviesa muros y suelos.
## Hereda de `BasicRunner` (vida, botín, parpadeo de impacto, estados) y reemplaza solo el movimiento.
## Sin class_name a propósito: `run.bat` no regenera el registro de clases globales; se instancia por su escena.
## El daño por contacto lo aplica la hurtbox del jugador leyendo `contact_damage`.

@export var hover_amplitude: float = 7.0
@export var hover_speed: float = 2.6
## Altura del centro del cuerpo sobre los pies, hacia donde apunta (px).
const BODY_CENTER_Y: float = -32.0

var _hover_time: float = 0.0


func _physics_process(delta: float) -> void:
	_hover_time += delta
	if target_player == null or not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group(&"player") as Player

	var effective_speed: float = move_speed
	if status_receiver != null:
		effective_speed *= status_receiver.get_speed_multiplier()
	effective_speed *= ZoneModifierManager.get_world_mult("enemy_speed_mult", 1.0)

	var desired: Vector2 = Vector2.ZERO
	if target_player != null and is_instance_valid(target_player):
		var aim: Vector2 = (target_player.global_position + Vector2(0.0, BODY_CENTER_Y)) - (global_position + Vector2(0.0, BODY_CENTER_Y))
		if target_player.is_invisible:
			is_aggroed = false
		elif aim.length() <= aggro_range:
			is_aggroed = true
		if is_aggroed and aim.length() > 18.0:
			desired = aim.normalized() * effective_speed
			desired.y += cos(_hover_time * hover_speed) * hover_amplitude * hover_speed
			if visuals != null and absf(aim.x) > 6.0:
				visuals.scale.x = signf(aim.x)
		elif is_aggroed:
			desired.y = cos(_hover_time * hover_speed) * hover_amplitude * hover_speed

	velocity = velocity.move_toward(desired, 520.0 * delta)
	move_and_slide()
