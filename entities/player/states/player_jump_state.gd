class_name PlayerJumpState
extends PlayerState
## Estado de salto ascendente del Jugador.
## Aplica el impulso inicial de salto e implementa la mecánica de
## 'altura de salto variable' cortando la velocidad vertical si el botón
## de salto se suelta antes de alcanzar el ápice.


func enter() -> void:
	if not player.has_magic_flight:
		player.execute_jump()


func exit() -> void:
	if player != null:
		player.is_using_jetpack = false
		if player.jetpack_particles != null:
			player.jetpack_particles.emitting = false


func physics_update(delta: float) -> void:
	# 0. Vuelo Mágico Omnidireccional:
	if player.has_magic_flight:
		var vert_input: float = player.get_vertical_input()
		player.velocity.y = vert_input * player.get_current_move_speed()
		var input_dir: float = player.get_horizontal_input()
		apply_horizontal_movement(delta, input_dir, true)
		player.move_and_slide()
		if player.is_on_floor() and vert_input >= 0.0:
			if absf(input_dir) > 0.05:
				transitioned.emit(self, &"move")
			else:
				transitioned.emit(self, &"idle")
		return

	# Rebote en Paredes (Wall Jump) en pleno ascenso si toca pared
	if player.can_wall_jump and not player.is_on_floor() and player.is_on_wall():
		if player.is_jump_just_pressed():
			var wall_norm: Vector2 = player.get_wall_normal()
			player.velocity.x = wall_norm.x * 320.0
			player.velocity.y = -380.0
			player.update_facing_direction(signf(wall_norm.x))
			return

	# Alas de Aleteo durante ascenso
	if player.has_wings and not player.is_on_floor() and player.is_jump_just_pressed():
		if player.current_flaps > 0:
			player.velocity.y = -320.0
			player.current_flaps -= 1
			_trigger_flap_visual()
			return

	# Jetpack durante ascenso
	if player.has_jetpack and not player.is_on_floor() and player.is_jump_pressed():
		if player.jetpack_fuel > 0.0:
			player.velocity.y = -260.0
			player.jetpack_fuel = maxf(0.0, player.jetpack_fuel - 45.0 * delta)
			player.is_using_jetpack = true
			_trigger_jetpack_visual()
		else:
			player.is_using_jetpack = false
	else:
		if not player.is_jump_pressed():
			player.is_using_jetpack = false

	# Doble salto reactivo en pleno ascenso si dispone de saltos aéreos:
	if player.can_air_jump() and player.is_jump_just_pressed():
		player.execute_jump()
		return
	
	# Altura de salto variable:
	# Si el jugador suelta el botón de salto mientras aún va subiendo,
	# se reduce la velocidad vertical a la mitad para permitir saltos cortos y controlados.
	if player.is_jump_just_released() and player.velocity.y < 0.0:
		player.cut_jump()
	
	# Aplicar gravedad de fase ascendente
	apply_gravity(delta, false)
	
	# Control horizontal aéreo
	var input_dir: float = player.get_horizontal_input()
	apply_horizontal_movement(delta, input_dir, true)
	
	player.move_and_slide()
	
	# Si la velocidad vertical deja de ser negativa, se alcanzó el ápice -> pasar a Fall
	if player.velocity.y >= 0.0:
		transitioned.emit(self, &"fall")
		return
	
	# Si por alguna razón colisiona con el suelo durante el salto (ej. rampas o plataformas móviles)
	if player.is_on_floor() and player.velocity.y >= 0.0:
		if absf(input_dir) > 0.05:
			transitioned.emit(self, &"move")
		else:
			transitioned.emit(self, &"idle")


func _trigger_jetpack_visual() -> void:
	if player.visuals != null:
		var body_rect: ColorRect = player.visuals.get_node_or_null("Body") as ColorRect
		if body_rect != null:
			body_rect.color = Color(1.0, 0.65, 0.2, 1.0)
			var tw: Tween = player.create_tween()
			tw.tween_property(body_rect, "color", Color(0.18, 0.55, 0.95, 1.0), 0.08)


func _trigger_flap_visual() -> void:
	if player.visuals != null:
		var tw: Tween = player.create_tween()
		tw.tween_property(player.visuals, "scale:y", 0.75, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(player.visuals, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
