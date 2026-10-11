class_name HelpOverlay
extends CanvasLayer
## Panel de interfaz que muestra los controles y atajos en tiempo real.
## Alterna su visibilidad con 'H', 'Tab' o botón Select/Back sin pausar el juego.

@onready var weapon_label: Label = get_node_or_null("%WeaponLabel")
@onready var debug_label: Label = get_node_or_null("%DebugLabel")

var player: Player = null


func _ready() -> void:
	visible = true
	
	# Conectar con el jugador para actualizar el HUD de armas y estado debug
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null and player.weapon_manager != null:
		player.weapon_manager.weapon_changed.connect(_on_weapon_changed)
		player.weapon_manager.infinite_ammo_toggled.connect(_on_infinite_ammo_toggled)
		if player.weapon_manager.current_weapon != null:
			_on_weapon_changed(player.weapon_manager.current_weapon, player.weapon_manager.current_weapon_index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		toggle_visibility()
		get_viewport().set_input_as_handled()


## Alterna la visibilidad del overlay.
func toggle_visibility() -> void:
	visible = not visible


func _on_weapon_changed(weapon: WeaponData, _index: int) -> void:
	if weapon_label != null and weapon != null:
		if weapon.weapon_type == WeaponData.WeaponType.MELEE:
			weapon_label.text = "Arma activa: %s  |  Daño: %.0f  |  Cadencia: %.1f tajos/s  |  Tipo: MELEE (Parry Balístico 0.06s)" % [
				weapon.weapon_name,
				weapon.damage,
				weapon.fire_rate
			]
		else:
			var mode_str: String = "Automática" if weapon.is_automatic else "Semiautomática"
			weapon_label.text = "Arma activa: %s  |  Daño: %.0f  |  Cadencia: %.1f tiros/s  |  Modo: %s" % [
				weapon.weapon_name,
				weapon.damage,
				weapon.fire_rate,
				mode_str
			]



func _on_infinite_ammo_toggled(is_infinite: bool) -> void:
	if debug_label != null:
		if is_infinite:
			debug_label.text = "[F1] Munición Infinita: ACTIVADA (Cooldown ultra rápido)"
			debug_label.modulate = Color(0.35, 1.0, 0.45, 1.0)
		else:
			debug_label.text = "[F1] Munición Infinita: DESACTIVADA (Cooldown estándar)"
			debug_label.modulate = Color(0.85, 0.85, 0.85, 1.0)
