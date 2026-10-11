class_name ExitGate
extends Area2D
## Compuerta de salida y extracción de sector.
## Monitorea la presencia de enemigos en la arena final:
## Permanece cerrada con luz roja mientras haya enemigos con vida.
## Al morir el último custodio, la luz se torna verde y se desbloquea la barrera.
## Cuando el jugador ingresa con la compuerta abierta, activa GameManager.complete_level().

const PropSkin = preload("res://entities/props/prop_skin.gd")
signal gate_opened

@export var monitored_enemies: Array[NodePath] = []
@export var enemy_group: StringName = &"arena_enemies"

## Texto del arma desbloqueada que muestra la pantalla de victoria (vacío = sin recompensa).
@export var reward_weapon_text: String = ""

## Flag de mundo que se activa al extraer (vacío = ninguno).
@export var reward_world_flag: String = ""

@onready var status_light: ColorRect = get_node_or_null("Visuals/StatusLight") as ColorRect
@onready var barrier: ColorRect = get_node_or_null("Visuals/Barrier") as ColorRect
@onready var prompt_label: Label = get_node_or_null("Visuals/PromptLabel") as Label
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("Visuals/AnimatedSprite2D") as AnimatedSprite2D

var is_open: bool = false
var _enemies_alive: int = 0
var _completed: bool = false
var _tracked_nodes: Array[Node] = []


func _ready() -> void:
	PropSkin.swap_frames(anim_sprite, ["gate_closed.png", "gate_open.png"] as Array[String])
	collision_layer = 0
	collision_mask = 2 # Player
	
	body_entered.connect(_on_body_entered)
	_setup_monitored_enemies.call_deferred()


func _setup_monitored_enemies() -> void:
	_tracked_nodes.clear()
	_enemies_alive = 0
	
	# 1. Recopilar enemigos especificados explícitamente por NodePath
	for path in monitored_enemies:
		var node: Node = get_node_or_null(path)
		if node != null and is_instance_valid(node) and not _tracked_nodes.has(node):
			_track_enemy(node)
	
	# 2. Si no se especificaron rutas explícitas, recopilar por grupo
	if _tracked_nodes.is_empty():
		for node in get_tree().get_nodes_in_group(enemy_group):
			if node != null and is_instance_valid(node) and not _tracked_nodes.has(node):
				_track_enemy(node)
	
	# 3. Establecer estado visual inicial
	if _enemies_alive <= 0:
		open_gate()
	else:
		_set_closed_visuals()
	
	print("[ExitGate] Custodiada por %d enemigo(s)." % _enemies_alive)


func _track_enemy(enemy: Node) -> void:
	_tracked_nodes.append(enemy)
	_enemies_alive += 1
	
	if enemy.has_signal(&"died"):
		enemy.connect(&"died", _on_enemy_died.bind(enemy))
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))


func _on_enemy_died(enemy: Node) -> void:
	_handle_enemy_elimination(enemy)


func _on_enemy_tree_exited(enemy: Node) -> void:
	_handle_enemy_elimination(enemy)


func _handle_enemy_elimination(enemy: Node) -> void:
	if not _tracked_nodes.has(enemy):
		return
	
	_tracked_nodes.erase(enemy)
	_enemies_alive = maxi(0, _enemies_alive - 1)
	print("[ExitGate] Custodio eliminado. Restan: %d" % _enemies_alive)
	
	if _enemies_alive == 0 and not is_open:
		open_gate()


func open_gate() -> void:
	if is_open:
		return
	is_open = true
	gate_opened.emit()
	_set_open_visuals()
	GameFeel.sfx(self, &"gate_open", global_position)
	print("[ExitGate] ¡Compuerta DESBLOQUEADA! Acceso de extracción permitido.")
	
	# Si el jugador ya se encontraba en el área al momento de la apertura
	for body in get_overlapping_bodies():
		if body is Player:
			_trigger_extraction(body as Player)
			break


func _set_closed_visuals() -> void:
	if anim_sprite != null:
		anim_sprite.frame = 0
	if status_light != null:
		status_light.color = Color(1.0, 0.22, 0.22, 1.0) # Rojo
	if barrier != null:
		barrier.color = Color(1.0, 0.2, 0.2, 0.6)
	if prompt_label != null:
		prompt_label.text = "BLOQUEADO"
		prompt_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))


func _set_open_visuals() -> void:
	if anim_sprite != null:
		anim_sprite.frame = 1
	if status_light != null:
		status_light.color = Color(0.2, 1.0, 0.45, 1.0) # Verde
		var tw: Tween = create_tween().set_loops(3)
		tw.tween_property(status_light, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_SINE)
		tw.tween_property(status_light, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	if barrier != null:
		barrier.color = Color(0.2, 1.0, 0.45, 0.2)
	if prompt_label != null:
		prompt_label.text = "EXTRACCIÓN"
		prompt_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if is_open:
			_trigger_extraction(body as Player)
		else:
			print("[ExitGate] Acceso bloqueado. Quedan %d enemigo(s) activos." % _enemies_alive)


func _trigger_extraction(player: Player) -> void:
	if _completed:
		return
	_completed = true
	
	if not reward_world_flag.is_empty():
		SaveManager.set_world_flag(reward_world_flag, true)
		print("[ExitGate] Flag de recompensa '%s' activado." % reward_world_flag)

	var coins: int = 0
	var level: int = 1
	if player != null and player.stats_manager != null:
		coins = player.stats_manager.coins
		level = player.stats_manager.level
	
	var sector_name: String = "Sector 1"
	var cur_scene: Node = get_tree().current_scene
	if cur_scene != null and "level_title" in cur_scene:
		sector_name = str(cur_scene.level_title)
	
	var stats: Dictionary = {
		"sector": sector_name,
		"coins": coins,
		"level": level,
		"unlocked_weapon": reward_weapon_text
	}
	
	var sm: SaveManager = SaveManager.get_instance()
	if sm != null:
		if has_meta("next_level_path"):
			var next_p: String = str(get_meta("next_level_path"))
			if not next_p.is_empty() and not sm.unlocked_levels.has(next_p):
				sm.unlocked_levels.append(next_p)
			# La pantalla de victoria ofrece pasar directo al siguiente sector si ya tiene contenido
			if not next_p.is_empty() and LevelRegistry.is_implemented(next_p):
				stats["next_level_path"] = next_p
		sm.save_to_disk()
		print("[ExitGate] Autoguardado a disco completado antes de retornar al Campamento Base.")
	
	if GameManager != null and GameManager.has_method("complete_level"):
		GameManager.call("complete_level", stats)
	else:
		get_tree().change_scene_to_file("res://scenes/hub/base_camp.tscn")

