extends Node2D
## Sala de Estrés: arena del campamento con un generador infinito de enemigos para medir el rendimiento.
## Sin class_name a propósito (ver class-name-cache-gotcha). Se entra por la puerta del Campamento Base.
##
## - Panel de control (F4): tipo de enemigo (o mezcla), lotes de 1 a 200, generador continuo con ritmo y tope
##   de vivos, cuántos se instancian por cuadro, fuego automático contra los enemigos (carga de proyectiles,
##   impactos, sangre y muertes sin tener que disparar), congelar enemigos (separa el costo de dibujo del de
##   IA y física), botín sí/no, inmortalidad (sin retroceso de armas ni empujones) y munición infinita, matar / herir / borrar, limpiar escombros.
## - `PerfMonitor` (core/debug/perf_monitor.gd) siempre activo: panel arriba a la derecha y registro en
##   `user://logs/rendimiento/sala_<fecha>.csv/.txt`. Acá se anotan los pedidos, los cambios de opciones y
##   cuánto tarda instanciar cada tanda; el monitor agrega picos, censo de nodos y resumen al salir.
## - Nada de lo que pasa adentro se guarda: `SaveManager.saving_suspended` mientras la sala existe; al volver,
##   el campamento recarga el slot del disco.
##
## Atajos: F4 panel · F5 generador continuo · F6 congelar · F7 limpiar escombros · F8 censo de nodos · F9 lluvia del cielo ·
## F11 cambia lo que cae (ácido, granadas, fuego, balas...) · F10 lluvia de la ciudad ·
## N/Z/V/B/M lote de corredor/zombi/fantasma/bruto/centinela · K matar todos · L curar · Supr borrar sin efectos.

const LevelSkinScript = preload("res://levels/level_skin.gd")
const PerfMonitorScript = preload("res://core/debug/perf_monitor.gd")
const SettingsScript = preload("res://core/settings.gd")
const FX_STYLES: Array[String] = ["Sprites (como está)", "Partículas", "Shaders"]
const CityDecorScript = preload("res://levels/city_decor.gd")
const SceneDoorScene: PackedScene = preload("res://entities/interactables/scene_door.tscn")

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
]
const SKY_ACID: int = 0
const SKY_MIX_GRENADES: int = 5
const SKY_FUEL: int = 6
const SKY_FLARE: int = 7
const SKY_BULLETS: int = 8
const SKY_ALL: int = 9
const SKY_RAIN_RATES: Array[float] = [2.0, 5.0, 10.0, 20.0, 40.0, 80.0, 160.0]
## La lluvia cae a esta distancia (px) a cada lado del jugador, dentro de la arena, y desde esta altura.
const SKY_RAIN_HALF_WIDTH: float = 720.0
const SKY_RAIN_HEIGHT: float = -140.0

# Arena
const ARENA_LEFT: float = 0.0
const ARENA_RIGHT: float = 3200.0
const FLOOR_TOP: float = 536.0
const SPAWN_MARGIN: float = 90.0
## No aparecen enemigos más cerca del jugador que esto.
const SPAWN_MIN_DISTANCE: float = 220.0
const PLAYER_START: Vector2 = Vector2(1600.0, 520.0)
const DOOR_X: float = 140.0

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
var _sky_accum: float = 0.0
var _sky_thrown: int = 0
var _sky_rain_button: CheckButton = null
var _sky_kind_option: OptionButton = null
var _fx_style_option: OptionButton = null
## Valores originales de las opciones que se tocan en la sala (se restauran al salir)
var _saved_settings: Dictionary = {}
## Lluvia de la ciudad (Mundo 4): gotas que chocan con los sólidos, salpicaduras y relámpagos.
var city_rain_on: bool = false
var _city_rain_button: CheckButton = null

var _queue: Array[int] = []
var _spawn_accum: float = 0.0
var _fire_accum: float = 0.0
var _spawned_total: int = 0
var _last_spawn_ms: float = 0.0
var _last_spawn_count: int = 0

var _ui_layer: CanvasLayer = null
var _panel: PanelContainer = null
var _status_label: Label = null
var _spawner_button: Button = null
var _freeze_button: Button = null
var _status_timer: float = 0.0


func _ready() -> void:
	# Antes que nada: lo que pase acá no se guarda (ni al cerrar la ventana ni al volver por el menú de pausa)
	SaveManager.saving_suspended = true
	_build_arena()
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

	_build_panel()
	print("[StressRoom] Sala de Estrés lista. F4 muestra el panel. El progreso no se guarda acá adentro.")


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


func _process(delta: float) -> void:
	_status_timer += delta
	if _status_timer >= 0.25:
		_status_timer = 0.0
		_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_spawn_runner"):
		_queue_batch(0)
	elif event.is_action_pressed("debug_spawn_zombie"):
		_queue_batch(1)
	elif event.is_action_pressed("debug_spawn_ghost"):
		_queue_batch(2)
	elif event.is_action_pressed("debug_spawn_brute"):
		_queue_batch(3)
	elif event.is_action_pressed("debug_spawn_sentinel"):
		_queue_batch(4)
	elif event.is_action_pressed("debug_kill_all"):
		kill_all()
	elif event.is_action_pressed("debug_heal"):
		if player != null and player.stats_manager != null:
			player.stats_manager.heal(player.stats_manager.get_max_health())
	elif event is InputEventKey and event.pressed and not event.is_echo():
		var key_event: InputEventKey = event as InputEventKey
		var key: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		match key:
			KEY_F4:
				_panel.visible = not _panel.visible
			KEY_F5:
				_set_spawner(not spawner_on)
			KEY_F6:
				_set_frozen(not frozen)
			KEY_F7:
				clear_debris()
			KEY_F8:
				monitor.call("log_census")
			KEY_F9:
				set_sky_rain(not sky_rain_on)
			KEY_F11:
				set_sky_kind((sky_kind + 1) % SKY_KINDS.size())
			KEY_F10:
				set_city_rain(not city_rain_on)
			KEY_DELETE:
				remove_all_silently()
			_:
				return
		get_viewport().set_input_as_handled()


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
	# Plataformas para ver cómo se reparten y saltan cuando hay muchos
	for x: float in [700.0, 1600.0, 2500.0]:
		_add_block(environment, "Platform", Rect2(x - 130.0, 410.0, 260.0, 16.0))
	for x: float in [1150.0, 2050.0]:
		_add_block(environment, "HighPlatform", Rect2(x - 100.0, 290.0, 200.0, 16.0))

	var tip: Label = Label.new()
	tip.text = "SALA DE ESTRÉS  ·  F4 panel  ·  F5 generador  ·  F6 congelar  ·  F7 limpiar  ·  F8 censo  ·  N Z V B M lote  ·  K matar todos"
	tip.position = Vector2(PLAYER_START.x - 420.0, 170.0)
	tip.size = Vector2(840.0, 20.0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45, 1.0))
	tip.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	tip.add_theme_constant_override("outline_size", 4)
	environment.add_child(tip)


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

func _queue_batch(type_idx: int) -> void:
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
	_last_spawn_ms = float(Time.get_ticks_usec() - started) / 1000.0
	_last_spawn_count = count
	if _last_spawn_ms >= SLOW_SPAWN_LOG_MS:
		_log("Instanciar %d enemigos en un cuadro tardó %.1f ms (%.2f ms c/u)" % [count, _last_spawn_ms, _last_spawn_ms / float(count)])


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
	_spawned_total += 1


func _spawn_position(flying: bool) -> Vector2:
	var player_x: float = player.global_position.x if player != null else PLAYER_START.x
	var x: float = player_x
	for attempt: int in range(8):
		x = randf_range(ARENA_LEFT + SPAWN_MARGIN, ARENA_RIGHT - SPAWN_MARGIN)
		if absf(x - player_x) >= SPAWN_MIN_DISTANCE:
			break
	var y: float = randf_range(220.0, 470.0) if flying else FLOOR_TOP - randf_range(24.0, 60.0)
	return Vector2(x, y)


# ==============================================================================
# Acciones
# ==============================================================================

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


func _set_spawner(on: bool) -> void:
	spawner_on = on
	_spawn_accum = 0.0
	if _spawner_button != null:
		_spawner_button.set_pressed_no_signal(on)
	_log("Generador continuo %s (%.0f/s, tope %d, %s)" % ["ENCENDIDO" if on else "apagado", spawn_rate, alive_cap, TYPE_NAMES[enemy_type]])


func set_sky_rain(on: bool) -> void:
	sky_rain_on = on
	_sky_accum = 0.0
	if _sky_rain_button != null:
		_sky_rain_button.set_pressed_no_signal(on)
	_log("Lluvia del cielo %s (%s, %.0f/s)" % ["ENCENDIDA" if on else "apagada", SKY_KINDS[sky_kind], sky_rain_rate])


## Estilo de fuego y ácido: 0 sprites, 1 partículas, 2 shaders (vale para lo que aparezca desde ahora).
func set_fx_style(index: int) -> void:
	_remember_setting("fire_style")
	SettingsScript.values["fire_style"] = clampi(index, 0, FX_STYLES.size() - 1)
	if _fx_style_option != null:
		_fx_style_option.select(int(SettingsScript.values["fire_style"]))
	_log("Estilo de fuego y ácido: %s" % FX_STYLES[int(SettingsScript.values["fire_style"])])


## Enemigos lejanos como un solo sprite (opción "enemy_lod").
func set_enemy_lod(on: bool) -> void:
	_remember_setting("enemy_lod")
	SettingsScript.values["enemy_lod"] = on
	_log("Enemigos lejanos como sprite: %s" % ("sí" if on else "no"))


func _remember_setting(key: String) -> void:
	if not _saved_settings.has(key):
		_saved_settings[key] = SettingsScript.values.get(key)


func set_sky_kind(index: int) -> void:
	sky_kind = clampi(index, 0, SKY_KINDS.size() - 1)
	if _sky_kind_option != null:
		_sky_kind_option.select(sky_kind)
	_log("Lluvia del cielo: %s" % SKY_KINDS[sky_kind])


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
	if _city_rain_button != null:
		_city_rain_button.set_pressed_no_signal(on)
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
	_sky_thrown += 1


func _sky_x() -> float:
	var center_x: float = player.global_position.x if player != null else (ARENA_LEFT + ARENA_RIGHT) * 0.5
	var min_x: float = maxf(ARENA_LEFT + 60.0, center_x - SKY_RAIN_HALF_WIDTH)
	var max_x: float = minf(ARENA_RIGHT - 60.0, center_x + SKY_RAIN_HALF_WIDTH)
	return randf_range(min_x, max_x)


func _set_frozen(on: bool) -> void:
	frozen = on
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if _freeze_button != null:
		_freeze_button.set_pressed_no_signal(on)
	_log("Enemigos %s" % ("CONGELADOS (sin IA ni física: solo costo de dibujo)" if on else "descongelados"))


func _log(text: String) -> void:
	if monitor != null:
		monitor.call("log_event", text)


func _context_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("generador %s %.0f/s tope %d" % ["ON" if spawner_on else "off", spawn_rate, alive_cap])
	parts.append("tipo %s" % TYPE_NAMES[enemy_type])
	parts.append("cola %d" % _queue.size())
	parts.append("x cuadro %s" % ("todos" if per_frame <= 0 else str(per_frame)))
	parts.append("último lote %d en %.1f ms" % [_last_spawn_count, _last_spawn_ms])
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
# Panel de control
# ==============================================================================

func _build_panel() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 110
	add_child(_ui_layer)

	_panel = PanelContainer.new()
	_panel.position = Vector2(16.0, 110.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.04, 0.88)
	style.border_color = Color(0.85, 0.5, 0.25, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8.0)
	_panel.add_theme_stylebox_override("panel", style)
	_ui_layer.add_child(_panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)

	var title: Label = _label("SALA DE ESTRÉS  ·  F4 oculta", 13, Color(1.0, 0.75, 0.4, 1.0))
	box.add_child(title)

	var type_labels: Array[String] = TYPE_NAMES.duplicate()
	box.add_child(_option_row("Tipo", type_labels, TYPE_MIX, func(i: int) -> void:
		enemy_type = i
		_log("Tipo: %s" % TYPE_NAMES[i])))

	var batch_labels: Array[String] = []
	for n: int in BATCH_SIZES:
		batch_labels.append(str(n))
	box.add_child(_option_row("Lote", batch_labels, BATCH_SIZES.find(batch_size), func(i: int) -> void:
		batch_size = BATCH_SIZES[i]))

	var spawn_row: HBoxContainer = HBoxContainer.new()
	spawn_row.add_child(_button("Generar lote", func() -> void: _queue_batch(enemy_type)))
	spawn_row.add_child(_button("Matar todos (K)", kill_all))
	box.add_child(spawn_row)

	box.add_child(_separator())
	_spawner_button = _toggle("Generador continuo (F5)", spawner_on, func(on: bool) -> void: _set_spawner(on))
	box.add_child(_spawner_button)

	var rate_labels: Array[String] = []
	for r: float in RATES:
		rate_labels.append("%.0f / s" % r)
	box.add_child(_option_row("Ritmo", rate_labels, RATES.find(spawn_rate), func(i: int) -> void:
		spawn_rate = RATES[i]
		_log("Ritmo del generador: %.0f/s" % spawn_rate)))

	var cap_labels: Array[String] = []
	for c: int in CAPS:
		cap_labels.append("%d vivos" % c)
	box.add_child(_option_row("Tope", cap_labels, CAPS.find(alive_cap), func(i: int) -> void:
		alive_cap = CAPS[i]
		_log("Tope de vivos: %d" % alive_cap)))

	var per_frame_labels: Array[String] = []
	for p: int in PER_FRAME:
		per_frame_labels.append("todos de golpe" if p <= 0 else "%d por cuadro" % p)
	box.add_child(_option_row("Instanciar", per_frame_labels, PER_FRAME.find(per_frame), func(i: int) -> void:
		per_frame = PER_FRAME[i]
		_log("Instanciar: %s" % per_frame_labels[i])))

	var fire_labels: Array[String] = []
	for f: float in AUTO_FIRE_RATES:
		fire_labels.append("apagado" if f <= 0.0 else "%.0f tiros / s" % f)
	box.add_child(_option_row("Fuego auto", fire_labels, 0, func(i: int) -> void:
		auto_fire_rate = AUTO_FIRE_RATES[i]
		_fire_accum = 0.0
		_log("Fuego automático: %s" % fire_labels[i])))

	box.add_child(_separator())
	_sky_rain_button = _toggle("Lluvia del cielo (F9)", sky_rain_on, func(on: bool) -> void: set_sky_rain(on))
	box.add_child(_sky_rain_button)
	var kind_row: HBoxContainer = _option_row("Cae", SKY_KINDS, sky_kind, func(i: int) -> void: set_sky_kind(i))
	_sky_kind_option = kind_row.get_child(1) as OptionButton
	box.add_child(kind_row)
	var rain_labels: Array[String] = []
	for r: float in SKY_RAIN_RATES:
		rain_labels.append("%.0f / s" % r)
	box.add_child(_option_row("Ritmo", rain_labels, SKY_RAIN_RATES.find(sky_rain_rate), func(i: int) -> void:
		sky_rain_rate = SKY_RAIN_RATES[i]
		_log("Lluvia del cielo: %.0f/s" % sky_rain_rate)))

	box.add_child(_separator())
	var style_row: HBoxContainer = _option_row("Estilo", FX_STYLES, SettingsScript.get_int("fire_style"),
			func(i: int) -> void: set_fx_style(i))
	_fx_style_option = style_row.get_child(1) as OptionButton
	box.add_child(style_row)
	box.add_child(_toggle("Enemigos lejanos como sprite", SettingsScript.get_bool("enemy_lod"),
			func(on: bool) -> void: set_enemy_lod(on)))
	_city_rain_button = _toggle("Lluvia de la ciudad (F10)", city_rain_on, func(on: bool) -> void: set_city_rain(on))
	box.add_child(_city_rain_button)
	_freeze_button = _toggle("Congelar enemigos (F6)", frozen, func(on: bool) -> void: _set_frozen(on))
	box.add_child(_freeze_button)
	box.add_child(_toggle("Aggro al aparecer", aggro_on_spawn, func(on: bool) -> void: aggro_on_spawn = on))
	box.add_child(_toggle("Botín y orbes", loot_enabled, func(on: bool) -> void:
		loot_enabled = on
		_log("Botín %s (para los que aparezcan desde ahora)" % ("activado" if on else "desactivado"))))
	box.add_child(_toggle("Inmortal (sin empujones)", god_mode, func(on: bool) -> void:
		god_mode = on
		if player != null:
			player.knockback_immune = on))
	box.add_child(_toggle("Munición infinita", infinite_ammo, func(on: bool) -> void:
		infinite_ammo = on
		if player != null and player.weapon_manager != null:
			player.weapon_manager.set_infinite_ammo(on)))

	box.add_child(_separator())
	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_child(_button("Herir a todos", hurt_all))
	action_row.add_child(_button("Borrar (Supr)", remove_all_silently))
	box.add_child(action_row)
	var clean_row: HBoxContainer = HBoxContainer.new()
	clean_row.add_child(_button("Limpiar escombros (F7)", clear_debris))
	clean_row.add_child(_button("Censo (F8)", func() -> void: monitor.call("log_census")))
	box.add_child(clean_row)
	var log_row: HBoxContainer = HBoxContainer.new()
	log_row.add_child(_button("Abrir carpeta de logs", func() -> void: monitor.call("open_log_folder")))
	log_row.add_child(_button("Volver", func() -> void: GameManager.change_scene(CAMP_SCENE)))
	box.add_child(log_row)

	_status_label = _label("", 11, Color(0.85, 0.85, 0.8, 1.0))
	box.add_child(_status_label)
	_update_status()


func _update_status() -> void:
	if _status_label == null or not _panel.visible:
		return
	_status_label.text = "Vivos %d  ·  en cola %d  ·  generados %d\nÚltimo lote: %d en %.1f ms
Lluvia del cielo: %d lanzados  ·  charcos de ácido %d" % [
		get_tree().get_node_count_in_group(&"enemies"), _queue.size(), _spawned_total, _last_spawn_count, _last_spawn_ms,
		_sky_thrown, get_tree().get_nodes_in_group(&"acid_pools").size()]


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _separator() -> HSeparator:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	return sep


## Sin foco de teclado: si no, Espacio (saltar) activaría el último botón tocado.
func _button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(on_pressed)
	return button


func _toggle(text: String, initial: bool, on_toggled: Callable) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.text = text
	check.button_pressed = initial
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_size_override("font_size", 11)
	check.toggled.connect(on_toggled)
	return check


func _option_row(caption: String, items: Array[String], selected: int, on_selected: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = _label(caption, 11, Color(0.9, 0.85, 0.75, 1.0))
	label.custom_minimum_size = Vector2(78.0, 0.0)
	row.add_child(label)
	var option: OptionButton = OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	option.add_theme_font_size_override("font_size", 11)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: String in items:
		option.add_item(item)
	option.select(maxi(selected, 0))
	option.item_selected.connect(on_selected)
	row.add_child(option)
	return row
