class_name LevelBase
extends Node2D
## Controlador base para todos los niveles de expedición y campaña.
## Gestiona el spawn del jugador, la carga de datos del slot, la cámara,
## el HUD, la detección de caída al vacío y el enlace con la ExitGate.

const LevelSkinScript = preload("res://levels/level_skin.gd")
const CityAmbienceScript = preload("res://levels/city_ambience.gd")
## Exteriores del presente (P-1, P-2, P-4, P-5, P-8). Los interiores (alcantarilla, hotel, discoteca) no
## llevan tráfico ni gente de la calle, y el 4-9 y 4-10 son otro contenido (Ciudadela Blindada).
const CITY_EXTERIOR_IDS: Array[String] = ["4_01", "4_02", "4_04", "4_05", "4_08"]
## Prefijo del flag del slot que marca un arma garantizada ya entregada al personaje.
const GRANTED_FLAG_PREFIX: String = "weapon_granted:"

@export var level_id: String = "1_01"
@export var level_title: String = "Sector 01"
@export var chapter_number: int = 1
## Fondo pintado propio del nivel (archivo dentro de `assets/art/bg/`); vacío = el del capítulo.
@export var backdrop_file: String = ""
@export var next_level_path: String = ""
## Pista base del nivel cuando no es la de exploración (si el .ogg todavía no existe, queda la de exploración).
@export var base_music: StringName = &"explore"
@export var abyss_threshold: float = 950.0

## Evento de los Agentes del Tiempo (helicóptero o destello): probabilidad por nivel de que ocurra (0 = nunca).
## `agent_events_enabled` lo apaga por nivel sin tocar la probabilidad. `agent_event_style`: "helicopter" o "portal".
@export_group("Agentes del Tiempo")
@export var agent_events_enabled: bool = true
@export_range(0.0, 1.0) var agent_event_chance: float = 0.0
@export var agent_event_style: String = "helicopter"
@export_group("")

## Tier del botín de equipo que sueltan los enemigos de este nivel (0 = no sueltan equipo).
## Sube la probabilidad (+50% por tier) y las rarezas posibles. Ver LootTable.roll_gear().
@export var gear_loot_tier: int = 0

## Rutas de armas que el jugador debe tener al entrar. Solo se agregan las que falten (sin duplicar).
@export var guaranteed_weapon_paths: Array[String] = []

## Equipo de prueba: para probar el nivel desde su escena (F6) sin pasar por el Campamento.
## Agrega las armas y monedas en memoria, sin marcar flags de entrega. Si después se guarda la partida, el equipo queda guardado.
@export_group("Equipo de prueba")
@export var test_loadout_enabled: bool = false
@export var test_weapon_paths: Array[String] = []
@export var test_coins: int = 0
## Consumibles de prueba: id del consumible (`health_potion`, `speed_potion`, `no_reload_potion`) → cantidad.
@export var test_consumables: Dictionary = {}

@onready var player: Player = get_node_or_null("Player") as Player
@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint") as Marker2D
@onready var exit_gate: ExitGate = get_node_or_null("ExitGate") as ExitGate

var initial_spawn_position: Vector2 = Vector2(160, 545)


func _ready() -> void:
	LevelSkinScript.apply(self, chapter_number, backdrop_file)
	GameFeel.music_start_level(self)
	if base_music != &"explore" and FileAccess.file_exists("res://ost/%s.ogg" % String(base_music)):
		GameFeel.music_set_base(self, base_music)
	if CITY_EXTERIOR_IDS.has(level_id):
		add_child(CityAmbienceScript.new() as Node)
	if spawn_point != null:
		initial_spawn_position = spawn_point.global_position
	elif player != null:
		initial_spawn_position = player.global_position
	
	if player != null:
		player.global_position = initial_spawn_position
		
		# Cargar datos de progresión e inventario del personaje activo
		var sm: SaveManager = SaveManager.get_instance()
		if sm != null:
			var preview: Dictionary = sm.get_slot_preview(sm.current_slot)
			if bool(preview.get("exists", false)):
				sm.load_from_disk(sm.current_slot)
			
			var hud: HUD = get_tree().get_first_node_in_group(&"hud") as HUD
			if hud == null:
				hud = get_node_or_null("HUD") as HUD
			if hud != null:
				hud.setup_with_player(player)
	
	var sector_hud: HUD = get_tree().get_first_node_in_group(&"hud") as HUD
	if sector_hud == null:
		sector_hud = get_node_or_null("HUD") as HUD
	if sector_hud != null:
		sector_hud.set_sector(level_title)

	_grant_guaranteed_weapons()
	if agent_events_enabled and agent_event_chance > 0.0 and randf() < agent_event_chance:
		var event: Node = (load("res://levels/agent_event.gd") as GDScript).new() as Node
		event.set("style", agent_event_style)
		add_child(event)
	if test_loadout_enabled:
		_apply_test_loadout()
	SaveManager.set_respawn_point(initial_spawn_position)

	# Conectar ExitGate con el siguiente nivel si existe
	if exit_gate != null and not next_level_path.is_empty():
		exit_gate.set_meta("next_level_path", next_level_path)
	
	print("[%s] %s inicializado. Spawn: %s" % [level_id, level_title, initial_spawn_position])


## Agrega al arsenal las armas de `guaranteed_weapon_paths`, una sola vez por personaje.
## La entrega queda marcada en los flags del slot (`weapon_granted:<ruta>`): si el jugador después la vende
## o la guarda, el nivel no se la devuelve. Si ya la posee al llegar (partidas anteriores), solo se marca.
func _grant_guaranteed_weapons() -> void:
	if player == null or player.weapon_manager == null:
		return

	var wm: WeaponManager = player.weapon_manager
	for path in guaranteed_weapon_paths:
		var flag: String = GRANTED_FLAG_PREFIX + path
		if SaveManager.has_world_flag(flag):
			continue
		if _player_has_weapon(path):
			SaveManager.set_world_flag(flag)
			continue
		if not ResourceLoader.exists(path):
			continue
		var weapon: WeaponData = load(path) as WeaponData
		if weapon != null:
			wm.add_weapon(weapon, false)
			SaveManager.set_world_flag(flag)
			# La marca se guarda al instante: si el jugador sale sin guardar, el arma no vuelve a entregarse
			var sm: SaveManager = SaveManager.get_instance()
			if sm != null:
				sm.save_to_disk()

	if wm.current_weapon == null and not wm.weapons.is_empty():
		wm.select_weapon(0)


## Equipo de prueba: agrega `test_weapon_paths` al arsenal, `test_consumables` y `test_coins` al jugador. No marca flags de entrega.
func _apply_test_loadout() -> void:
	if player == null:
		return
	if player.weapon_manager != null:
		for path in test_weapon_paths:
			if not ResourceLoader.exists(path):
				continue
			var weapon: WeaponData = load(path) as WeaponData
			if weapon != null:
				player.weapon_manager.add_weapon(weapon, false)
		if player.weapon_manager.current_weapon == null and not player.weapon_manager.weapons.is_empty():
			player.weapon_manager.select_weapon(0)
	if player.consumable_manager != null:
		for id in test_consumables:
			player.consumable_manager.add(str(id), int(test_consumables[id]))
	if player.stats_manager != null and test_coins > 0:
		player.stats_manager.coins += test_coins
		player.stats_manager.coins_changed.emit(player.stats_manager.coins)
	print("[%s] Equipo de prueba: %d armas, %d consumibles, %d monedas." % [level_id, test_weapon_paths.size(), test_consumables.size(), test_coins])


## true si el jugador posee el arma en el arsenal, la mochila o el baúl del campamento.
## Dejarla guardada en el baúl es una decisión del jugador: el nivel no se la devuelve.
func _player_has_weapon(path: String) -> bool:
	for existing: WeaponData in player.weapon_manager.weapons:
		if existing != null and existing.source_resource_path == path:
			return true
	if player.inventory_manager != null:
		for stored: Resource in player.inventory_manager.backpack:
			var stored_weapon: WeaponData = stored as WeaponData
			if stored_weapon == null:
				continue
			var stored_path: String = stored_weapon.resource_path if not stored_weapon.resource_path.is_empty() else stored_weapon.source_resource_path
			if stored_path == path:
				return true
	var sm: SaveManager = SaveManager.get_instance()
	return sm != null and sm.stash_has_path(path)


func _physics_process(_delta: float) -> void:
	if player != null and player.global_position.y > abyss_threshold:
		_on_player_fell_into_abyss()


func _on_player_fell_into_abyss() -> void:
	print("[%s] Jugador cayó al abismo." % level_id)
	var gm: GameManager = GameManager.get_instance() if GameManager != null else null
	if gm != null:
		gm.on_player_died(player)
	else:
		respawn_player()


func respawn_player() -> void:
	if player != null:
		var target_pos: Vector2 = SaveManager.get_respawn_point(initial_spawn_position)
		player.respawn(target_pos)
		print("[%s] Jugador reaparecido en: %s" % [level_id, target_pos])


func set_respawn_position(pos: Vector2) -> void:
	initial_spawn_position = pos
