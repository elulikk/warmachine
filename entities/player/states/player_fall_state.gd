class_name PlayerFallState
extends PlayerState
## Estado de caída o descenso del Jugador.
## Gestiona la gravedad de caída acelerada, el Coyote Time (para saltar
## en el aire si se acaba de salir de una plataforma) y la resolución
## del Jump Buffer al aterrizar.


## Velocidad de caída mínima (px/s) para que el aterrizaje suene.
const LAND_SOUND_SPEED: float = 260.0


func enter() -> void:
	pass


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

	# 1. Chequeo de Rebote en Paredes (Wall Jump) y deslizamiento
	if player.can_wall_jump and not player.is_on_floor() and player.is_on_wall():
		# Deslizar por la pared con velocidad vertical reducida
		if player.velocity.y > 60.0:
			player.velocity.y = 60.0
		
		# Impulso diagonal al presionar salto
		if player.is_jump_just_pressed():
			var wall_norm: Vector2 = player.get_wall_normal()
			player.velocity.x = wall_norm.x * 320.0
			player.velocity.y = -380.0
			player.update_facing_direction(signf(wall_norm.x))
			transitioned.emit(self, &"jump")
			return

	# 2. Alas de Aleteo (is_action_just_pressed)
	if player.has_wings and not player.is_on_floor() and player.is_jump_just_pressed():
		if player.current_flaps > 0:
			player.velocity.y = -320.0
			player.current_flaps -= 1
			# Efecto visual breve de aleteo
			_trigger_flap_visual()
			transitioned.emit(self, &"jump")
			return

	# 3. Jetpack con combustible continuo (is_jump_pressed)
	if player.has_jetpack and not player.is_on_floor() and player.is_jump_pressed():
		if player.jetpack_fuel > 0.0:
			player.velocity.y = -260.0
			player.jetpack_fuel = maxf(0.0, player.jetpack_fuel - player.JETPACK_DRAIN * player.jetpack_drain_mult * delta)
			player.is_using_jetpack = true
			_trigger_jetpack_visual()
		else:
			player.is_using_jetpack = false
	else:
		if not player.is_jump_pressed():
			player.is_using_jetpack = false

	# 4. Chequeo de Coyote Time o Doble Salto en el aire estándar
	if player.can_coyote_jump() and (player.is_jump_just_pressed() or player.has_buffered_jump()):
		transitioned.emit(self, &"jump")
		return
	elif player.can_air_jump() and player.is_jump_just_pressed():
		transitioned.emit(self, &"jump")
		return
	
	# 5. Aplicar gravedad con multiplicador de caída para mayor peso/snappiness
	apply_gravity(delta, true)
	
	# 6. Control horizontal aéreo
	var horiz_dir: float = player.get_horizontal_input()
	apply_horizontal_movement(delta, horiz_dir, true)
	
	var fall_speed: float = player.velocity.y
	player.move_and_slide()
	
	# 7. Chequeo de aterrizaje
	if player.is_on_floor():
		if fall_speed > LAND_SOUND_SPEED:
			GameFeel.sfx(player, &"land", Vector2.INF, -6.0)
		# Jump Buffer: Si presionó salto hasta 0.10s antes de tocar el suelo, salta de inmediato
		if player.has_buffered_jump():
			transitioned.emit(self, &"jump")
			return
		
		# Si no hay salto en cola, pasar a Move o Idle según el input
		if absf(horiz_dir) > 0.05:
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
