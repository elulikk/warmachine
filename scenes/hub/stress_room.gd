extends Node2D
## Sala de Estrés: arena larga del campamento con un generador infinito de enemigos para medir el rendimiento.
## Sin class_name a propósito (ver class-name-cache-gotcha). Se entra por la puerta del Campamento Base.
##
## - Cinta de opciones (F4 la oculta, doble clic en una pestaña la contrae): `ui/debug/ribbon.gd` es el widget genérico y
##   `scenes/hub/stress_room_ui.gd` declara su contenido (pestañas Enemigos, Aparición, Jugador, Efectos, Arena,
##   Diagnóstico y Atajos). Esta sala solo expone el estado y los métodos públicos que esos controles llaman:
##   `set_*`, `queue_batch`, `kill_all`, `hurt_all`, `remove_all_silently`, `clear_debris`, `teleport_to`...
##   Los controles se sincronizan con `ribbon.set_value(id, valor)` cuando el estado cambia por otro camino.
## - `PerfMonitor` (core/debug/perf_monitor.gd) siempre activo: panel arriba a la derecha y registro en
##   `user://logs/rendimiento/sala_<fecha>.csv/.txt`. Acá se anotan los pedidos, los cambios de opciones y
##   cuánto tarda instanciar cada tanda; el monitor agrega picos, censo de nodos y resumen al salir.
## - La cinta ocupa el borde de arriba: la sala corre el HUD y la cámara para que no queden tapados (`_on_ribbon_layout`).
## - Nada de lo que pasa adentro se guarda: `SaveManager.saving_suspended` mientras la sala existe; al volver,
##   el campamento recarga el slot del disco.
##
## Teclas fijas (las de la cinta están en su pestaña Atajos): N/Z/V/B/M lote de corredor/zombi/fantasma/bruto/centinela ·
## K matar todos · L curar.

const LevelSkinScript = preload("res://levels/level_skin.gd")
const PerfMonitorScript = preload("res://core/debug/perf_monitor.gd")
const SettingsScript = preload("res://core/settings.gd")
const FX_STYLES: Array[String] = ["Sprites (como está)", "Partículas", "Shaders"]
const CityDecorScript = preload("res://levels/city_decor.gd")
const SceneDoorScene: PackedScene = preload("res://entities/interactables/scene_door.tscn")
const RibbonScript = preload("res://ui/debug/ribbon.gd")
const StressRoomUi = preload("res://scenes/hub/stress_room_ui.gd")

const RUNNER_SCENE: PackedScene = preload("res://entities/enemies/basic_runner.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://entities/enemies/zombie.tscn")
const GHOST_SCENE: PackedScene = preload("res://entities/enemies/ghost.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemies/armored_brute.tscn")
const SENTINEL_SCENE: PackedScene = preload("res://entities/enemies/shielded_sentinel.tscn")
const ACID_GRENADE_SCENE: PackedScene = preload("res://combat/throwables/acid_grenade.tscn")
const FRAG_GRENADE_SCENE: PackedScene = preload("res://combat/throwables/frag_grenade.tscn")
const ICE_GRENADE_SCENE: PackedScene = preload("res://combat/throwables/ice_grenade.tscn")
const GAS_BOMB_SCENE: PackedScene = preload("res://combat/throwables/gas_bomb.tscn")
const ROOT_NET_SCENE: PackedScene = preload("res://combat/throwables/root_net_grenade.tscn")
const FUEL_DROPLET_SCENE: PackedScene = preload("res://combat/fuel_droplet.tscn")
const FIRE_EXPLOSION_SCENE: PackedScene = preload("res://combat/throwables/fire_explosion.tscn")

const CAMP_SCENE: String = "res://scenes/hub/base_camp.tscn"

const TYPE_NAMES: Array[String] = ["Corredor", "Zombi", "Fantasma", "Bruto", "Centinela", "Mezcla"]
const TYPE_MIX: int = 5
## Peso de cada tipo en la mezcla (los pesados aparecen menos, como en la campaña).
const MIX_WEIGHTS: Array[float] = [4.0, 3.0, 2.0, 1.0, 1.0]
const GHOST_TYPE: int = 2

const BATCH_SIZES: Array[int] = [1, 5, 10, 25, 50, 100, 200]
const RATES: Array[float] = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0]
const CAPS: Array[int] = [10, 25, 50, 100, 200, 300, 500, 1000]
## 0 = todos en el mismo cuadro (peor caso).
const PER_FRAME: Array[int] = [1, 5, 10, 25, 0]
const AUTO_FIRE_RATES: Array[float] = [0.0, 5.0, 15.0, 30.0, 60.0]
## Lluvia del cielo: qué cae, cuántos por segundo, y desde dónde.
const SKY_KINDS: Array[String] = [
	"Ácido", "Fragmentación", "Hielo", "Gas", "Red", "Granadas variadas",
	"Fuego: gotas de combustible", "Fuego: llamaradas", "Balas", "Todo junto",
	"Solo experiencia",
]
const SKY_ACID: int = 0
const SKY_MIX_GRENADES: int = 5
const SKY_FUEL: int = 6
const SKY_FLARE: int = 7
const SKY_BULLETS: int = 8
const SKY_ALL: int = 9
## Lluvia de orbes de experiencia (no entra en "Todo junto"): prueba el halo, la atracción y la fusión de orbes.
const SKY_EXP: int = 10
const EXP_RAIN_AMOUNT: float = 5.0
const EXP_ORB_SCENE: PackedScene = preload("res://entities/items/exp_orb.tscn")
const DeathFxQueueScript = preload("res://combat/death_fx_queue.gd")
const SKY_RAIN_RATES: Array[float] = [2.0, 5.0, 10.0, 20.0, 40.0, 80.0, 160.0]
## La lluvia cae a esta distancia (px) a cada lado del jugador, dentro de la arena, y desde esta altura.
const SKY_RAIN_HALF_WIDTH: float = 720.0
const SKY_RAIN_HEIGHT: float = -140.0

# Arena (el doble de larga que antes: seis zonas de unos mil píxeles)
const ARENA_LEFT: float = 0.0
const ARENA_RIGHT: float = 6400.0
const FLOOR_TOP: float = 536.0
const SPAWN_MARGIN: float = 90.0
## No aparecen enemigos más cerca del jugador que esto.
const SPAWN_MIN_DISTANCE: float = 220.0
const PLAYER_START: Vector2 = Vector2(900.0, 520.0)
const DOOR_X: float = 140.0
## Zonas con nombre: la pestaña Arena arma un botón de teletransporte por cada una y la regla las rotula.
const ZONES: Array[Dictionary] = [
	{"name": "Puerta", "x": 300.0},
	{"name": "Plaza", "x": 1400.0},
	{"name": "Avenida", "x": 2700.0},
	{"name": "Cruce", "x": 3900.0},
	{"name": "Mercado", "x": 5100.0},
	{"name": "Extremo", "x": 6150.0},
]
## Plataformas bajas y altas (centros en x), cajas del piso y marcas de la regla.
const LOW_PLATFORMS: Array[float] = [700.0, 1500.0, 2300.0, 3100.0, 3900.0, 4700.0, 5500.0]
const HIGH_PLATFORMS: Array[float] = [1100.0, 1900.0, 2700.0, 3500.0, 4300.0, 5100.0, 5900.0]
const CRATES: Array[float] = [2000.0, 3600.0, 5000.0]
const RULER_STEP: float = 400.0

## Dónde nacen los enemigos.
const SPAWN_ZONES: Array[String] = [
	"Toda la arena", "Alrededor del jugador", "Lejos del jugador (fuera de pantalla)", "Extremo izquierdo", "Extremo derecho",
]
const ZONE_NEAR: int = 1
const ZONE_FAR: int = 2
const ZONE_LEFT: int = 3
const ZONE_RIGHT: int = 4
const NEAR_RADIUS: float = 900.0
## Más que medio ancho de pantalla: nacen fuera de la vista.
const FAR_MIN_DISTANCE: float = 760.0
const EDGE_WIDTH: float = 1000.0

const AUTO_FIRE_DAMAGE: float = 14.0
const AUTO_FIRE_SPEED: float = 760.0
const HURT_ALL_DAMAGE: float = 20.0
## Tandas que tarden más que esto en instanciarse se anotan en el registro.
const SLOW_SPAWN_LOG_MS: float = 8.0

@onready var player: Player = get_node_or_null("Player") as Player
@onready var enemies_root: Node2D = get_node_or_null("Enemies") as Node2D

## La lee GameManager para reaparecer al jugador (la sala cuenta como sandbox).
var initial_spawn_position: Vector2 = PLAYER_START

var monitor: Node = null

var enemy_type: int = TYPE_MIX
var batch_size: int = 10
var spawner_on: bool = false
var spawn_rate: float = 5.0
var alive_cap: int = 100
var per_frame: int = 10
var auto_fire_rate: float = 0.0
var frozen: bool = false
var loot_enabled: bool = true
var aggro_on_spawn: bool = true
var god_mode: bool = true
var infinite_ammo: bool = true
var sky_rain_on: bool = false
var sky_rain_rate: float = 10.0
var sky_kind: int = SKY_ACID
var spawn_zone: int = 0
var ruler_on: bool = true
var _sky_accum: float = 0.0
var sky_thrown: int = 0
## Valores originales de las opciones que se tocan en la sala (se restauran al salir)
var _saved_settings: Dictionary = {}
## Lluvia de la ciudad (Mundo 1): gotas que chocan con los sólidos, salpicaduras y relámpagos.
var city_rain_on: bool = false

var _queue: Array[int] = []
var _spawn_accum: float = 0.0
var _fire_accum: float = 0.0
var spawned_total: int = 0
var last_spawn_ms: float = 0.0
var last_spawn_count: int = 0

var ribbon: RibbonScript = null
var _ui_layer: CanvasLayer = null
var _ruler: Node2D = null
## Alto de la cinta que ya se descontó del HUD y la cámara.
var _ribbon_reserved: float = 0.0


func _ready() -> void:
	# Antes que nada: lo que pase acá no se guarda (ni al cerrar la ventana ni al volver por el menú de pausa)
	SaveManager.saving_suspended = true
	_build_arena()
	var camera: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.limit_left = int(ARENA_LEFT - 80.0)
		camera.limit_right = int(ARENA_RIGHT + 80.0)
	LevelSkinScript.apply(self, 0)
	GameFeel.music_start_level(self)
	get_tree().paused = false
	if GameManager != null:
		GameManager.current_state = GameManager.GameState.PLAYING

	if player != null:
		player.global_position = PLAYER_START
		var sm: SaveManager = SaveManager.get_instance()
		if sm != null and bool(sm.get_slot_preview(sm.current_slot).get("exists", false)):
			sm.load_from_disk(sm.current_slot)
		var hud: HUD = get_node_or_null("HUD") as HUD
		if hud != null:
			hud.setup_with_player(player)
		if player.weapon_manager != null:
			player.weapon_manager.set_infinite_ammo(infinite_ammo)
			_grant_test_weapons()
		player.knockback_immune = god_mode
	SaveManager.set_respawn_point(PLAYER_START)

	var door: Node2D = SceneDoorScene.instantiate() as Node2D
	door.set("target_scene", CAMP_SCENE)
	door.set("prompt_text", "[E] Volver al campamento")
	door.set("sign_text", "CAMPAMENTO")
	door.set("accent", Color(0.4, 0.85, 1.0, 1.0))
	door.position = Vector2(DOOR_X, FLOOR_TOP)
	add_child(door)

	monitor = PerfMonitorScript.new()
	monitor.set("tag", "sala")
	monitor.set("persistent", true)
	monitor.set("context_provider", _context_text)
	add_child(monitor)
	_log("Entrada a la Sala de Estrés. Opciones: %s" % _context_text())

	_build_ribbon()
	print("[StressRoom] Sala de Estrés lista. F4 muestra u oculta la cinta. El progreso no se guarda acá adentro.")


## Armas de prueba que la sala entrega si el jugador no las tiene (no se guardan: la sala no persiste).
func _grant_test_weapons() -> void:
	var wm: WeaponManager = player.weapon_manager
	for path: String in ["res://data/weapons/mjolnir.tres"]:
		var owned: bool = false
		for w: WeaponData in wm.weapons:
			if w != null and w.source_resource_path == path:
				owned = true
		if not owned and ResourceLoader.exists(path):
			wm.add_weapon(load(path) as WeaponData, false)


func _exit_tree() -> void:
	SaveManager.saving_suspended = false
	# Los estilos probados acá no se guardan: vuelven a lo que tenía el jugador
	for key: String in _saved_settings.keys():
		SettingsScript.values[key] = _saved_settings[key]
	if _ui_layer != null and is_instance_valid(_ui_layer):
		_ui_layer.queue_free()


func _physics_process(delta: float) -> void:
	if god_mode and player != null and player.stats_manager != null:
		var max_hp: float = player.stats_manager.get_max_health()
		if player.stats_manager.current_health < max_hp:
			player.stats_manager.heal(max_hp)
	if player != null and player.global_position.y > 900.0:
		player.respawn(PLAYER_START)

	if spawner_on:
		_spawn_accum += spawn_rate * delta
		var alive: int = get_tree().get_node_count_in_group(&"enemies") + _queue.size()
		while _spawn_accum >= 1.0:
			_spawn_accum -= 1.0
			if alive >= alive_cap:
				_spawn_accum = 0.0
				break
			_queue.append(_pick_type(enemy_type))
			alive += 1

	_process_queue()

	if sky_rain_on:
		_sky_accum += sky_rain_rate * delta
		while _sky_accum >= 1.0:
			_sky_accum -= 1.0
			_sky_drop()

	if auto_fire_rate > 0.0:
		_fire_accum += auto_fire_rate * delta
		while _fire_accum >= 1.0:
			_fire_accum -= 1.0
			_auto_fire_shot()


## Teclas fijas del Input Map. Las demás (F4-F11, Supr) las despacha la cinta (ver `Ribbon.bind_key`).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn_runner"):
		queue_batch(0)
	elif event.is_action_pressed("debug_spawn_zombie"):
		queue_batch(1)
	elif event.is_action_pressed("debug_spawn_ghost"):
		queue_batch(2)
	elif event.is_action_pressed("debug_spawn_brute"):
		queue_batch(3)
	elif event.is_action_pressed("debug_spawn_sentinel"):
		queue_batch(4)
	elif event.is_action_pressed("debug_kill_all"):
		kill_all()
	elif event.is_action_pressed("debug_heal"):
		heal_player()


# ==============================================================================
# Arena
# ==============================================================================

func _build_arena() -> void:
	var environment: Node2D = Node2D.new()
	environment.name = "Environment"
	add_child(environment)
	move_child(environment, 0)
	var width: float = ARENA_RIGHT - ARENA_LEFT
	_add_block(environment, "MainFloor", Rect2(ARENA_LEFT - 40.0, FLOOR_TOP, width + 80.0, 48.0))
	_add_block(environment, "LeftWall", Rect2(ARENA_LEFT - 80.0, -500.0, 80.0, 1084.0))
	_add_block(environment, "RightWall", Rect2(ARENA_RIGHT, -500.0, 80.0, 1084.0))
	# Plataformas y cajas para ver cómo se reparten, saltan y se trancan cuando hay muchos
	for x: float in LOW_PLATFORMS:
		_add_block(environment, "Platform", Rect2(x - 130.0, 410.0, 260.0, 16.0))
	for x: float in HIGH_PLATFORMS:
		_add_block(environment, "HighPlatform", Rect2(x - 100.0, 290.0, 200.0, 16.0))
	for x: float in CRATES:
		_add_block(environment, "Crate", Rect2(x - 45.0, FLOOR_TOP - 70.0, 90.0, 70.0))

	_build_ruler(environment)

	var tip: Label = Label.new()
	tip.text = "SALA DE ESTRÉS  ·  F4 cinta de opciones  ·  N Z V B M lote  ·  K matar todos  ·  L curar"
	tip.position = Vector2(PLAYER_START.x - 420.0, 170.0)
	tip.size = Vector2(840.0, 20.0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45, 1.0))
	tip.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	tip.add_theme_constant_override("outline_size", 4)
	environment.add_child(tip)


## Regla de distancia: una marca cada `RULER_STEP` px con su coordenada, y el nombre de cada zona arriba.
func _build_ruler(environment: Node2D) -> void:
	_ruler = Node2D.new()
	_ruler.name = "Ruler"
	_ruler.visible = ruler_on
	environment.add_child(_ruler)
	var x: float = 0.0
	while x <= ARENA_RIGHT:
		var tick: ColorRect = ColorRect.new()
		tick.color = Color(1.0, 0.75, 0.45, 0.35)
		tick.position = Vector2(x - 1.0, FLOOR_TOP - 18.0)
		tick.size = Vector2(2.0, 18.0)
		_ruler.add_child(tick)
		_ruler.add_child(_ruler_label(str(int(x)), Vector2(x - 40.0, FLOOR_TOP + 12.0), Vector2(80.0, 16.0), 11, 0.6))
		x += RULER_STEP
	for zone: Dictionary in ZONES:
		_ruler.add_child(_ruler_label("ZONA  ·  %s" % str(zone["name"]).to_upper(),
				Vector2(float(zone["x"]) - 200.0, 215.0), Vector2(400.0, 28.0), 20, 0.5))


func _ruler_label(text: String, position_in: Vector2, size_in: Vector2, font_size: int, alpha: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = position_in
	label.size = size_in
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45, alpha))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, alpha))
	label.add_theme_constant_override("outline_size", 3)
	return label


## Bloque sólido al estilo de los niveles (StaticBody2D + ColorRect + TopBorder) para que LevelSkin lo revista.
func _add_block(parent: Node2D, block_name: String, rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = block_name
	body.add_to_group(&"world")
	body.collision_mask = 0
	body.position = rect.get_center()
	parent.add_child(body)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	var color_rect: ColorRect = ColorRect.new()
	color_rect.name = "ColorRect"
	color_rect.color = Color(0.14, 0.12, 0.13, 1.0)
	color_rect.position = -rect.size * 0.5
	color_rect.size = rect.size
	body.add_child(color_rect)
	var border: ColorRect = ColorRect.new()
	border.name = "TopBorder"
	border.color = Color(0.85, 0.45, 0.2, 1.0)
	border.position = -rect.size * 0.5
	border.size = Vector2(rect.size.x, 3.0)
	body.add_child(border)


# ==============================================================================
# Generación de enemigos
# ==============================================================================

func queue_batch(type_idx: int) -> void:
	for i: int in range(batch_size):
		_queue.append(_pick_type(type_idx))
	_log("Pedido: %d x %s" % [batch_size, TYPE_NAMES[type_idx]])


func _pick_type(type_idx: int) -> int:
	if type_idx != TYPE_MIX:
		return type_idx
	var total: float = 0.0
	for w: float in MIX_WEIGHTS:
		total += w
	var roll: float = randf() * total
	for i: int in range(MIX_WEIGHTS.size()):
		roll -= MIX_WEIGHTS[i]
		if roll <= 0.0:
			return i
	return 0


func _scene_for(type_idx: int) -> PackedScene:
	match type_idx:
		1:
			return ZOMBIE_SCENE
		2:
			return GHOST_SCENE
		3:
			return BRUTE_SCENE
		4:
			return SENTINEL_SCENE
	return RUNNER_SCENE


func _process_queue() -> void:
	if _queue.is_empty():
		return
	var count: int = _queue.size() if per_frame <= 0 else mini(per_frame, _queue.size())
	var started: int = Time.get_ticks_usec()
	for i: int in range(count):
		_spawn_one(_queue[i])
	_queue = _queue.slice(count)
	last_spawn_ms = float(Time.get_ticks_usec() - started) / 1000.0
	last_spawn_count = count
	if last_spawn_ms >= SLOW_SPAWN_LOG_MS:
		_log("Instanciar %d enemigos en un cuadro tardó %.1f ms (%.2f ms c/u)" % [count, last_spawn_ms, last_spawn_ms / float(count)])


func _spawn_one(type_idx: int) -> void:
	var enemy: Node2D = _scene_for(type_idx).instantiate() as Node2D
	if enemy == null:
		return
	if not loot_enabled:
		if "loot_table" in enemy:
			enemy.set("loot_table", null)
		if "exp_orb_scene" in enemy:
			enemy.set("exp_orb_scene", null)
		if "drop_rune_on_death" in enemy:
			enemy.set("drop_rune_on_death", null)
	enemy.position = _spawn_position(type_idx == GHOST_TYPE)
	var parent: Node = enemies_root if enemies_root != null else self
	parent.add_child(enemy)
	if aggro_on_spawn and "is_aggroed" in enemy:
		enemy.set("is_aggroed", true)
	if frozen:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	spawned_total += 1


func _spawn_position(flying: bool) -> Vector2:
	var y: float = randf_range(220.0, 470.0) if flying else FLOOR_TOP - randf_range(24.0, 60.0)
	return Vector2(_spawn_x(), y)


## Coordenada x de un enemigo nuevo según la zona elegida, siempre lejos de la cara del jugador.
func _spawn_x() -> float:
	var player_x: float = player.global_position.x if player != null else PLAYER_START.x
	var low: float = ARENA_LEFT + SPAWN_MARGIN
	var high: float = ARENA_RIGHT - SPAWN_MARGIN
	match spawn_zone:
		ZONE_NEAR:
			low = maxf(low, player_x - NEAR_RADIUS)
			high = minf(high, player_x + NEAR_RADIUS)
		ZONE_LEFT:
			low = DOOR_X + 160.0
			high = low + EDGE_WIDTH
		ZONE_RIGHT:
			low = high - EDGE_WIDTH
	var min_distance: float = FAR_MIN_DISTANCE if spawn_zone == ZONE_FAR else SPAWN_MIN_DISTANCE
	var x: float = player_x
	for attempt: int in range(8):
		x = randf_range(low, high)
		if absf(x - player_x) >= min_distance:
			break
	return x


# ==============================================================================
# Acciones
# ==============================================================================

func heal_player() -> void:
	if player != null and player.stats_manager != null:
		player.stats_manager.heal(player.stats_manager.get_max_health())


func queue_size() -> int:
	return _queue.size()


func leave_room() -> void:
	GameManager.change_scene(CAMP_SCENE)


## Lleva al jugador a una x de la arena (la cámara salta con él, sin recorrer el camino suavizada).
func teleport_to(x: float) -> void:
	if player == null:
		return
	player.global_position = Vector2(clampf(x, ARENA_LEFT + 60.0, ARENA_RIGHT - 60.0), FLOOR_TOP - 40.0)
	if "velocity" in player:
		player.set("velocity", Vector2.ZERO)
	var camera: Camera2D = get_tree().get_first_node_in_group(&"game_camera") as Camera2D
	if camera != null:
		camera.global_position = player.global_position
		camera.reset_smoothing()
	_log("Teletransporte a x %d" % int(player.global_position.x))


## Mata a todos con daño real (muerte, sangre, gibs, botín y orbes): el peor caso de un cuadro.
func kill_all() -> void:
	var killed: int = 0
	var started: int = Time.get_ticks_usec()
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var hc: HealthComponent = node.get_node_or_null("HealthComponent") as HealthComponent
		if hc != null and not hc.is_dead:
			hc.apply_damage(hc.current_health + hc.max_shield + 1.0)
			killed += 1
	_log("Matar todos: %d enemigos (%.1f ms en el cuadro del golpe; las muertes siguen en los cuadros de después)" % [
		killed, float(Time.get_ticks_usec() - started) / 1000.0])


## Golpea a todos con un impacto normal (sangre, heridas, números de daño) sin matarlos de una.
func hurt_all() -> void:
	var hit: int = 0
	var started: int = Time.get_ticks_usec()
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if not node.has_method("take_hit") or not (node is Node2D):
			continue
		var dir: Vector2 = Vector2.RIGHT
		if player != null:
			dir = ((node as Node2D).global_position - player.global_position).normalized()
		node.call("take_hit", HitPayload.new(HURT_ALL_DAMAGE, 60.0, dir, player))
		hit += 1
	_log("Herir a todos: %d enemigos x %d de daño (%.1f ms)" % [hit, int(HURT_ALL_DAMAGE), float(Time.get_ticks_usec() - started) / 1000.0])


## Borra los enemigos sin efectos de muerte (para volver a cero sin el pico de gore).
func remove_all_silently() -> void:
	var removed: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.queue_free()
		removed += 1
	_queue.clear()
	_log("Borrar sin efectos: %d enemigos" % removed)


## Quita gibs, manchas, botín, orbes y números de daño que quedaron en el piso.
func clear_debris() -> void:
	var removed: int = 0
	for group: StringName in [&"gibs", &"blood_stains"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.queue_free()
			removed += 1
	for child: Node in get_children():
		var key: String = PerfMonitorScript._node_key(child)
		if key == "LootDrop" or key == "ExpOrb" or key == "DamageNumber":
			child.queue_free()
			removed += 1
	_log("Limpiar escombros: %d nodos" % removed)


func _auto_fire_shot() -> void:
	if player == null:
		return
	var pool: ProjectilePool = get_tree().get_first_node_in_group(&"projectile_pool") as ProjectilePool
	var targets: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	if pool == null or targets.is_empty():
		return
	var target: Node2D = targets[randi() % targets.size()] as Node2D
	if target == null:
		return
	var origin: Vector2 = player.global_position + Vector2(0.0, -28.0)
	var dir: Vector2 = (target.global_position + Vector2(0.0, -16.0) - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	pool.get_projectile(origin, dir, HitPayload.new(AUTO_FIRE_DAMAGE, 90.0, dir, player), AUTO_FIRE_SPEED)


func set_spawner(on: bool) -> void:
	spawner_on = on
	_spawn_accum = 0.0
	_sync("spawner", on)
	_log("Generador continuo %s (%.0f/s, tope %d, %s)" % ["ENCENDIDO" if on else "apagado", spawn_rate, alive_cap, TYPE_NAMES[enemy_type]])


func set_enemy_type(index: int) -> void:
	enemy_type = clampi(index, 0, TYPE_NAMES.size() - 1)
	_sync("type", enemy_type)
	_log("Tipo: %s" % TYPE_NAMES[enemy_type])


func set_batch_size(count: int) -> void:
	batch_size = maxi(count, 1)
	_sync("batch", BATCH_SIZES.find(batch_size))


func set_spawn_rate(rate: float) -> void:
	spawn_rate = rate
	_sync("rate", RATES.find(rate))
	_log("Ritmo del generador: %.0f/s" % spawn_rate)


func set_alive_cap(cap: int) -> void:
	alive_cap = cap
	_sync("cap", CAPS.find(cap))
	_log("Tope de vivos: %d" % alive_cap)


func set_per_frame(count: int) -> void:
	per_frame = count
	_sync("per_frame", PER_FRAME.find(count))
	_log("Instanciar: %s" % ("todos de golpe" if count <= 0 else "%d por cuadro" % count))


func set_spawn_zone(index: int) -> void:
	spawn_zone = clampi(index, 0, SPAWN_ZONES.size() - 1)
	_sync("zone", spawn_zone)
	_log("Zona de aparición: %s" % SPAWN_ZONES[spawn_zone])


func set_aggro(on: bool) -> void:
	aggro_on_spawn = on
	_sync("aggro", on)


func set_loot(on: bool) -> void:
	loot_enabled = on
	_sync("loot", on)
	_log("Botín %s (para los que aparezcan desde ahora)" % ("activado" if on else "desactivado"))


func set_god_mode(on: bool) -> void:
	god_mode = on
	if player != null:
		player.knockback_immune = on
	_sync("god", on)


func set_infinite_ammo(on: bool) -> void:
	infinite_ammo = on
	if player != null and player.weapon_manager != null:
		player.weapon_manager.set_infinite_ammo(on)
	_sync("ammo", on)


func set_auto_fire_rate(rate: float) -> void:
	auto_fire_rate = rate
	_fire_accum = 0.0
	_sync("fire", AUTO_FIRE_RATES.find(rate))
	_log("Fuego automático: %s" % ("apagado" if rate <= 0.0 else "%.0f tiros / s" % rate))


func set_sky_rain_rate(rate: float) -> void:
	sky_rain_rate = rate
	_sync("sky_rate", SKY_RAIN_RATES.find(rate))
	_log("Lluvia del cielo: %.0f/s" % sky_rain_rate)


func set_ruler(on: bool) -> void:
	ruler_on = on
	if _ruler != null:
		_ruler.visible = on
	_sync("ruler", on)


func set_sky_rain(on: bool) -> void:
	sky_rain_on = on
	_sky_accum = 0.0
	_sync("sky_rain", on)
	_log("Lluvia del cielo %s (%s, %.0f/s)" % ["ENCENDIDA" if on else "apagada", SKY_KINDS[sky_kind], sky_rain_rate])


## Estilo de fuego y ácido: 0 sprites, 1 partículas, 2 shaders (vale para lo que aparezca desde ahora).
func set_fx_style(index: int) -> void:
	_remember_setting("fire_style")
	SettingsScript.values["fire_style"] = clampi(index, 0, FX_STYLES.size() - 1)
	_sync("fx_style", int(SettingsScript.values["fire_style"]))
	_log("Estilo de fuego y ácido: %s" % FX_STYLES[int(SettingsScript.values["fire_style"])])


## Enemigos lejanos como un solo sprite (opción "enemy_lod").
func set_enemy_lod(on: bool) -> void:
	_remember_setting("enemy_lod")
	SettingsScript.values["enemy_lod"] = on
	_sync("lod", on)
	_log("Enemigos lejanos como sprite: %s" % ("sí" if on else "no"))


func fx_style_index() -> int:
	return SettingsScript.get_int("fire_style")


func enemy_lod_on() -> bool:
	return SettingsScript.get_bool("enemy_lod")


func _remember_setting(key: String) -> void:
	if not _saved_settings.has(key):
		_saved_settings[key] = SettingsScript.values.get(key)


func set_sky_kind(index: int) -> void:
	sky_kind = clampi(index, 0, SKY_KINDS.size() - 1)
	_sync("sky_kind", sky_kind)
	_log("Lluvia del cielo: %s" % SKY_KINDS[sky_kind])


func next_sky_kind() -> void:
	set_sky_kind((sky_kind + 1) % SKY_KINDS.size())


## Enciende o apaga la lluvia de la ciudad con los sólidos de la arena (misma rutina que usan los sectores 4-x).
func set_city_rain(on: bool) -> void:
	for node_name: String in ["RainDrops", "RainSplashes", "Rain"]:
		var old: Node = get_node_or_null(node_name)
		if old != null:
			old.free()
	city_rain_on = on
	if on:
		var solids: Array[Rect2] = []
		var environment: Node = get_node_or_null("Environment")
		if environment != null:
			for body: Node in environment.get_children():
				if not body is StaticBody2D:
					continue
				for child: Node in body.get_children():
					var shape_node: CollisionShape2D = child as CollisionShape2D
					if shape_node != null and shape_node.shape is RectangleShape2D:
						var size: Vector2 = (shape_node.shape as RectangleShape2D).size
						solids.append(Rect2((body as StaticBody2D).position - size * 0.5, size))
		CityDecorScript.add_rain(self, solids)
	_sync("city_rain", on)
	_log("Lluvia de la ciudad %s" % ("ENCENDIDA" if on else "apagada"))


## Suelta algo del cielo según `sky_kind`; todo pasa por el circuito real (fusible, efecto, sonido, gotas).
func _sky_drop() -> void:
	var kind: int = sky_kind
	if kind == SKY_ALL:
		kind = randi() % SKY_ALL
	var x: float = _sky_x()
	var thrown_player: Node2D = player
	match kind:
		SKY_FUEL:
			var droplet: Node2D = FUEL_DROPLET_SCENE.instantiate() as Node2D
			add_child(droplet)
			droplet.global_position = Vector2(x, SKY_RAIN_HEIGHT)
			droplet.rotation = PI * 0.5 + randf_range(-0.25, 0.25)
			var effects: Array[String] = ["FIRE"]
			var payload: HitPayload = HitPayload.new(4.0, 0.0, Vector2.DOWN, thrown_player, effects)
			droplet.call("setup", randf_range(260.0, 420.0), payload)
		SKY_FLARE:
			var flare: AreaBurst = FIRE_EXPLOSION_SCENE.instantiate() as AreaBurst
			flare.radius = 70.0
			flare.source_node = thrown_player
			flare.position = Vector2(x, FLOOR_TOP - randf_range(10.0, 80.0))
			add_child(flare)
		SKY_EXP:
			DeathFxQueueScript.exp_orb(self, EXP_ORB_SCENE, EXP_RAIN_AMOUNT, Vector2(x, SKY_RAIN_HEIGHT))
		SKY_BULLETS:
			var pool: ProjectilePool = get_tree().get_first_node_in_group(&"projectile_pool") as ProjectilePool
			if pool != null:
				var down: Vector2 = Vector2.DOWN.rotated(randf_range(-0.2, 0.2))
				pool.get_projectile(Vector2(x, SKY_RAIN_HEIGHT), down,
						HitPayload.new(AUTO_FIRE_DAMAGE, 90.0, down, thrown_player), AUTO_FIRE_SPEED)
		_:
			var scenes: Array[PackedScene] = [ACID_GRENADE_SCENE, FRAG_GRENADE_SCENE, ICE_GRENADE_SCENE, GAS_BOMB_SCENE, ROOT_NET_SCENE]
			var scene: PackedScene = scenes[kind] if kind < scenes.size() else scenes[randi() % scenes.size()]
			var grenade: Node = scene.instantiate()
			add_child(grenade)
			grenade.call("launch", Vector2(x, SKY_RAIN_HEIGHT),
					Vector2(randf_range(-70.0, 70.0), randf_range(0.0, 140.0)), thrown_player)
	sky_thrown += 1


func _sky_x() -> float:
	var center_x: float = player.global_position.x if player != null else (ARENA_LEFT + ARENA_RIGHT) * 0.5
	var min_x: float = maxf(ARENA_LEFT + 60.0, center_x - SKY_RAIN_HALF_WIDTH)
	var max_x: float = minf(ARENA_RIGHT - 60.0, center_x + SKY_RAIN_HALF_WIDTH)
	return randf_range(min_x, max_x)


func set_frozen(on: bool) -> void:
	frozen = on
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	_sync("freeze", on)
	_log("Enemigos %s" % ("CONGELADOS (sin IA ni física: solo costo de dibujo)" if on else "descongelados"))


## Refleja en la cinta un estado que cambió (sin disparar la señal del control).
func _sync(id: String, value: Variant) -> void:
	if ribbon != null:
		ribbon.set_value(id, value)


func _log(text: String) -> void:
	if monitor != null:
		monitor.call("log_event", text)


func _context_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("generador %s %.0f/s tope %d" % ["ON" if spawner_on else "off", spawn_rate, alive_cap])
	parts.append("tipo %s" % TYPE_NAMES[enemy_type])
	parts.append("zona %s" % SPAWN_ZONES[spawn_zone])
	parts.append("cola %d" % _queue.size())
	parts.append("x cuadro %s" % ("todos" if per_frame <= 0 else str(per_frame)))
	parts.append("último lote %d en %.1f ms" % [last_spawn_count, last_spawn_ms])
	parts.append("fuego auto %.0f/s" % auto_fire_rate)
	var death_queue: Node = get_node_or_null("DeathFxQueue")
	if death_queue != null:
		parts.append("cola muertes %d (gore descartado %d)" % [int(death_queue.call("pending")), int(death_queue.get("dropped_gore"))])
	if frozen:
		parts.append("CONGELADOS")
	if not loot_enabled:
		parts.append("sin botín")
	return " | ".join(parts)


# ==============================================================================
# Cinta de opciones
# ==============================================================================

func _build_ribbon() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 110
	add_child(_ui_layer)
	# El contador de FPS del juego ocupa la esquina de arriba a la izquierda: el título arranca después
	ribbon = RibbonScript.new("Sala de Estrés", 84.0)
	_ui_layer.add_child(ribbon)
	StressRoomUi.build(self, ribbon)
	ribbon.layout_changed.connect(_on_ribbon_layout)


## La cinta se come el borde de arriba: baja el HUD y el panel de rendimiento, y corre la cámara para que el jugador
## siga centrado en lo que queda visible.
func _on_ribbon_layout() -> void:
	var height: float = ribbon.effective_height()
	var delta: float = height - _ribbon_reserved
	if is_zero_approx(delta):
		return
	_ribbon_reserved = height
	var hud: Node = get_node_or_null("HUD")
	if hud != null:
		for child: Node in hud.get_children():
			var box: MarginContainer = child as MarginContainer
			if box != null and box.anchor_top == 0.0 and box.anchor_bottom == 0.0:
				box.offset_top += delta
				box.offset_bottom += delta
	var overlay: CanvasLayer = monitor.get("_layer") as CanvasLayer if monitor != null else null
	if overlay != null:
		overlay.offset = Vector2(0.0, height)
	var camera: CameraFollow = get_tree().get_first_node_in_group(&"game_camera") as CameraFollow
	if camera != null:
		camera.target_offset.y -= delta * 0.5 / maxf(camera.zoom.y, 0.1)
