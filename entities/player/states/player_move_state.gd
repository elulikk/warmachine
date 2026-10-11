class_name PlayerMoveState
extends PlayerState
## Estado de desplazamiento horizontal en el suelo del Jugador.
## Maneja la aceleración, giro de orientación y transiciones hacia
## reposo (Idle), salto (Jump) o caída (Fall).


func enter() -> void:
	pass


func physics_update(delta: float) -> void:
	# 1. Chequeo de caída (si camina fuera de un borde; Coyote Time empezará a correr)
	if not player.is_on_floor():
		transitioned.emit(self, &"fall")
		return
	
	# 2. Chequeo de salto (directo o por buffer) o ascenso en vuelo mágico
	if player.has_buffered_jump() or player.is_jump_just_pressed():
		transitioned.emit(self, &"jump")
		return
	
	if player.has_magic_flight and player.get_vertical_input() < -0.05:
		transitioned.emit(self, &"jump")
		return
	
	var input_dir: float = player.get_horizontal_input()
	
	# 3. Si no hay entrada analógica y la velocidad es baja, volver a reposo
	if absf(input_dir) <= 0.05 and absf(player.velocity.x) < 5.0:
		player.velocity.x = 0.0
		transitioned.emit(self, &"idle")
		return
	
	# Aplicar aceleración o fricción con tracción de suelo
	apply_horizontal_movement(delta, input_dir, false)
	player.move_and_slide()
