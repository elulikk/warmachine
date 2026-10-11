class_name Level01
extends Node2D
## Controlador del Sector 1 (Campaña Principal).
## Administra la progresión continua del sector a través de 4 zonas:
## 1. Salida (Descenso de plataformas y 3 runners)
## 2. Puesto Avanzado (Mercenario esqueleto y Runa en pedestal)
## 3. Punto Crítico (Terminal de Checkpoint y Contrato de Zona)
## 4. Arena de Extracción (4 custodios hostiles y Compuerta de Salida)

@onready var player: Player = $Player

var initial_spawn_position: Vector2 = Vector2(140, 545)


func _ready() -> void:
	if player != null:
		initial_spawn_position = player.global_position
		# Si existe una ranura activa con datos guardados, aplicar su inventario y stats
		var sm: SaveManager = SaveManager.get_instance()
		if sm != null:
			var preview: Dictionary = sm.get_slot_preview(sm.current_slot)
			if bool(preview.get("exists", false)):
				sm.load_from_disk(sm.current_slot)
			
			var hud: HUD = get_tree().get_first_node_in_group(&"hud") as HUD
			if hud == null:
				hud = get_node_or_null("HUD") as HUD
			if hud != null and player != null:
				hud.setup_with_player(player)
	
	# Establecer punto inicial de reaparición en SaveManager
	SaveManager.set_respawn_point(initial_spawn_position)
	print("[Level01] Sector 1 inicializado. Spawn configurado en: %s" % initial_spawn_position)


func _physics_process(_delta: float) -> void:
	# Detección de caída al abismo
	if player != null and player.global_position.y > 920.0:
		_on_player_fell_into_abyss()


func _on_player_fell_into_abyss() -> void:
	print("[Level01] Jugador cayó al vacío.")
	var gm: GameManager = GameManager.get_instance() if GameManager != null else null
	if gm != null:
		gm.on_player_died(player)
	else:
		respawn_player()


## Reaparece al jugador en el último checkpoint o posición inicial.
func respawn_player() -> void:
	if player != null:
		var target_pos: Vector2 = SaveManager.get_respawn_point(initial_spawn_position)
		player.respawn(target_pos)
		print("[Level01] Jugador reaparecido en: %s" % target_pos)


## Permite actualizar la posición de reaparición dinámicamente.
func set_respawn_position(pos: Vector2) -> void:
	initial_spawn_position = pos
	SaveManager.set_respawn_point(pos)
