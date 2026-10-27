class_name PlayerIdleState
extends PlayerState
## Estado de reposo del Jugador.
## Maneja la desaceleración por fricción en el suelo y transiciona hacia
## movimiento (Move), salto (Jump) o caída (Fall) según corresponda.


func enter() -> void:
	pass


func physics_update(delta: float) -> void:
	# 1. Chequeo de caída (si el suelo desaparece debajo)
	if not player.is_on_floor():
		transitioned.emit(self, &"fall")
		return
	
	# 2. Chequeo de salto (directo o por buffer)
	if player.has_buffered_jump() or player.is_jump_just_pressed():
		transitioned.emit(self, &"jump")
		return
	
	# 3. Chequeo de movimiento horizontal y vertical (vuelo mágico)
	var input_dir: float = player.get_horizontal_input()
	var vert_input: float = player.get_vertical_input() if player.has_magic_flight else 0.0
	
	if player.has_magic_flight and vert_input < -0.05:
		transitioned.emit(self, &"jump")
		return
	
	if absf(input_dir) > 0.05 or player.is_dashing():
		transitioned.emit(self, &"move")
		return
	
	# Aplicar fricción sobre el suelo hasta detenerse
	apply_horizontal_movement(delta, 0.0, false)
	player.move_and_slide()
