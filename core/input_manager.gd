class_name InputSetup
extends RefCounted
## Configura programáticamente el InputMap para soportar Teclado, Mouse y Gamepad en simultáneo.
## Garantiza que todas las acciones de movimiento, combate, armas, debug y UI existan
## sin depender exclusivamente de la recarga del archivo project.godot.

static func setup_inputs() -> void:
	# 1. Movimiento básico y salto
	_configure_action("move_left", 0.2, [
		_create_key_event(KEY_A),
		_create_key_event(KEY_LEFT),
		_create_joy_button_event(JOY_BUTTON_DPAD_LEFT),
		_create_joy_motion_event(JOY_AXIS_LEFT_X, -1.0)
	])
	
	_configure_action("move_right", 0.2, [
		_create_key_event(KEY_D),
		_create_key_event(KEY_RIGHT),
		_create_joy_button_event(JOY_BUTTON_DPAD_RIGHT),
		_create_joy_motion_event(JOY_AXIS_LEFT_X, 1.0)
	])
	
	# Zona muerta amplia en el eje horizontal: la deriva de un stick gastado no debe dejar al personaje deslizando
	for action_name: StringName in [&"move_left", &"move_right"]:
		InputMap.action_set_deadzone(action_name, 0.35)

	_configure_action("move_up", 0.2, [
		_create_key_event(KEY_W),
		_create_key_event(KEY_UP),
		_create_joy_button_event(JOY_BUTTON_DPAD_UP),
		_create_joy_motion_event(JOY_AXIS_LEFT_Y, -1.0)
	])
	
	_configure_action("move_down", 0.2, [
		_create_key_event(KEY_S),
		_create_key_event(KEY_DOWN),
		_create_joy_button_event(JOY_BUTTON_DPAD_DOWN),
		_create_joy_motion_event(JOY_AXIS_LEFT_Y, 1.0)
	])
	
	# Salto estrictamente dedicado: Únicamente Barra Espaciadora y Botón Inferior A / Cruz
	_enforce_action_events("jump", 0.2, [
		_create_key_event(KEY_SPACE),
		_create_joy_button_event(JOY_BUTTON_A) # Botón A (Xbox) / Cruz (PS)
	])

	_configure_action("attack", 0.2, [
		_create_mouse_button_event(MOUSE_BUTTON_LEFT),
		_create_joy_motion_event(JOY_AXIS_TRIGGER_RIGHT, 1.0) # R2 / RT
	])

	# Mano secundaria: clic derecho (o R3 en el mando). Con un arma en la mano secundaria el clic derecho dispara
	# esa arma en vez de usar la herramienta (ver ThrowableManager). La herramienta sigue en F y L1.
	_configure_action("attack_secondary", 0.2, [
		_create_mouse_button_event(MOUSE_BUTTON_RIGHT),
		_create_joy_button_event(JOY_BUTTON_RIGHT_STICK) # R3
	])

	# Dash: solo funciona con el Módulo de Dash equipado (ver Player.can_dash).
	_configure_action("dash", 0.2, [
		_create_key_event(KEY_SHIFT),
		_create_joy_button_event(JOY_BUTTON_B) # B (Xbox) / Círculo (PS)
	])

	_configure_action("reload", 0.2, [
		_create_key_event(KEY_R),
		_create_joy_button_event(JOY_BUTTON_X) # X (Xbox) / Cuadrado (PS)
	])

	# 3. Barra de acceso rápido: teclas 1 a 9 eligen casillero (ver ui/hotbar.gd)
	var hotbar_keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
	for i in range(hotbar_keys.size()):
		_enforce_action_events("hotbar_%d" % (i + 1), 0.2, [
			_create_key_event(hotbar_keys[i])
		])

	_configure_action("weapon_prev", 0.2, [
		_create_mouse_button_event(MOUSE_BUTTON_WHEEL_UP),
		_create_joy_button_event(JOY_BUTTON_LEFT_SHOULDER) # L1 / LB
	])

	_configure_action("weapon_next", 0.2, [
		_create_mouse_button_event(MOUSE_BUTTON_WHEEL_DOWN),
		_create_joy_button_event(JOY_BUTTON_RIGHT_SHOULDER) # R1 / RB
	])

	_configure_action("weapon_toggle", 0.2, [
		_create_key_event(KEY_Q),
		_create_joy_button_event(JOY_BUTTON_Y) # Y (Xbox) / Triángulo (PS)
	])

	# 4. Atajos de Debug
	_configure_action("debug_infinite_ammo", 0.2, [
		_create_key_event(KEY_F1)
	])

	_configure_action("debug_respawn", 0.2, [
		_create_key_event(KEY_F3)
	])

	# Atajos del Sandbox: spawnear enemigos frente al jugador, limpiar arena y curar
	_configure_action("debug_spawn_runner", 0.2, [
		_create_key_event(KEY_N)
	])

	_configure_action("debug_spawn_brute", 0.2, [
		_create_key_event(KEY_B)
	])

	_configure_action("debug_spawn_sentinel", 0.2, [
		_create_key_event(KEY_M)
	])

	_configure_action("debug_spawn_zombie", 0.2, [
		_create_key_event(KEY_Z)
	])

	_configure_action("debug_spawn_ghost", 0.2, [
		_create_key_event(KEY_V)
	])

	_configure_action("debug_kill_all", 0.2, [
		_create_key_event(KEY_K)
	])

	_configure_action("debug_heal", 0.2, [
		_create_key_event(KEY_L)
	])

	# 5. Interfaz y Ayuda
	_configure_action("toggle_help", 0.2, [
		_create_key_event(KEY_H),
		_create_key_event(KEY_TAB),
		_create_joy_button_event(JOY_BUTTON_BACK) # Select / Back / View
	])

	# 6. Interacción en el mundo (ej: Contratar aliados con [E])
	_configure_action("interact", 0.2, [
		_create_key_event(KEY_E),
		_create_joy_button_event(JOY_BUTTON_X) # Botón X (Xbox) / Cuadrado (PS)
	])

	# Despedir a mercenarios contratados y drones de apoyo ([T]); ver AllyDismisser
	_configure_action("dismiss_allies", 0.2, [
		_create_key_event(KEY_T)
	])

	# 7. Firma de Contratos de Zona en Checkpoints ([F])
	_configure_action("contract_sign", 0.2, [
		_create_key_event(KEY_F),
		_create_joy_button_event(JOY_BUTTON_Y) # Botón Y (Xbox) / Triángulo (PS)
	])

	# 8. Inventario y Mochila ([I])
	_configure_action("toggle_inventory", 0.2, [
		_create_key_event(KEY_I),
		_create_joy_button_event(JOY_BUTTON_START) # Start / Menú en Gamepad
	])

	# 9. Ventana Modular de Estadísticas ([C])
	_configure_action("toggle_stats_window", 0.2, [
		_create_key_event(KEY_C),
		_create_joy_button_event(JOY_BUTTON_BACK) # Back / Select en Gamepad
	])

	# 10. Arrojadizos Tácticos ([G], clic central de la ruedita, gatillo izquierdo). Mantener para apuntar
	# y cargar alcance; soltar para lanzar (ver ThrowableManager). Los botones laterales del ratón
	# quedaron reservados para los consumibles (ver sección 12).
	_configure_action("throw_tactical", 0.5, [
		_create_key_event(KEY_G),
		_create_mouse_button_event(MOUSE_BUTTON_MIDDLE),
		_create_joy_motion_event(JOY_AXIS_TRIGGER_LEFT, 1.0) # L2 / LT
	])

	# 11. Herramientas de Movilidad Táctica (gancho): Ratón 5 (XBUTTON2) / [F] / L1
	_enforce_action_events("use_tool", 0.5, [
		_create_mouse_button_event(MOUSE_BUTTON_XBUTTON2),
		_create_key_event(KEY_F),
		_create_joy_button_event(JOY_BUTTON_LEFT_SHOULDER) # L1 / LB
	])


	# 12. Consumibles rápidos: M4 = consumible 1, [X] = consumible 2 (M5 quedó para el gancho).
	# Las teclas 4 / 5 / 6 eligen casillero de la barra.
	_enforce_action_events("consumable_1", 0.2, [
		_create_mouse_button_event(MOUSE_BUTTON_XBUTTON1)
	])

	_enforce_action_events("consumable_2", 0.2, [
		_create_key_event(KEY_X)
	])


static func _enforce_action_events(action_name: StringName, deadzone: float, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, deadzone)
	else:
		InputMap.action_erase_events(action_name)
	for new_event in events:
		InputMap.action_add_event(action_name, new_event)


static func _configure_action(action_name: StringName, deadzone: float, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, deadzone)
	
	var existing_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	
	for new_event in events:
		var already_exists: bool = false
		for ev in existing_events:
			if _are_events_equivalent(ev, new_event):
				already_exists = true
				break
		if not already_exists:
			InputMap.action_add_event(action_name, new_event)


static func _create_key_event(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _create_mouse_button_event(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	return event


static func _create_joy_button_event(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _create_joy_motion_event(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event


static func _are_events_equivalent(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode or a.keycode == b.physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false
