class_name GameFeel
extends RefCounted
## Utilidades estáticas de "game feel" (screen shake, hit stop y explosión de muerte).
## Todas reciben un nodo de contexto que esté dentro del árbol para acceder al SceneTree.

const CAMERA_GROUP: StringName = &"game_camera"

## Hit stop: el tiempo se ralentiza (no se congela) para no romper timers de física.
const HIT_STOP_DURATION: float = 0.03
const HIT_STOP_TIME_SCALE: float = 0.05
const HIT_STOP_COOLDOWN_MSEC: int = 90

## Umbrales de intensidad de impacto.
const STRONG_HIT_DAMAGE: float = 40.0
const HEAVY_RECOIL_THRESHOLD: float = 90.0

const SfxScript = preload("res://core/sfx.gd")
const MusicScript = preload("res://core/music.gd")
const MusicDirectorScript = preload("res://core/music_director.gd")
const SettingsScript = preload("res://core/settings.gd")
const BloodFxScript = preload("res://combat/blood_fx.gd")

static var _hit_stop_active: bool = false
static var _last_hit_stop_msec: int = 0


## Sacude la cámara activa. Si ya hay una sacudida más fuerte en curso, se conserva.
static func shake(ctx: Node, strength: float, duration: float = 0.18) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	var cam: CameraFollow = ctx.get_tree().get_first_node_in_group(CAMERA_GROUP) as CameraFollow
	if cam != null:
		cam.shake(strength, duration)


## Ralentiza el juego una fracción de segundo (tiempo real) para dar peso al impacto.
static func hit_stop(ctx: Node, duration: float = HIT_STOP_DURATION) -> void:
	if _hit_stop_active or ctx == null or not ctx.is_inside_tree():
		return
	if not bool(SettingsScript.get_bool("hit_stop")):
		return
	var tree: SceneTree = ctx.get_tree()
	if tree.paused:
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_hit_stop_msec < HIT_STOP_COOLDOWN_MSEC:
		return
	_last_hit_stop_msec = now_msec
	_hit_stop_active = true
	Engine.time_scale = HIT_STOP_TIME_SCALE
	# process_always = true, process_in_physics = false, ignore_time_scale = true
	tree.create_timer(duration, true, false, true).timeout.connect(_end_hit_stop)


static func _end_hit_stop() -> void:
	Engine.time_scale = 1.0
	_hit_stop_active = false


## Respuesta a un impacto del jugador sobre un blanco: crítico = hit stop, fuerte = shake.
static func on_player_hit(ctx: Node, is_critical: bool, damage: float) -> void:
	if is_critical:
		hit_stop(ctx)
		shake(ctx, 4.0, 0.15)
	elif damage >= STRONG_HIT_DAMAGE:
		shake(ctx, 3.0, 0.12)


## Shake para disparos pesados según el retroceso del arma (escopeta, sniper).
static func on_weapon_fired(ctx: Node, recoil_force: float) -> void:
	if recoil_force < HEAVY_RECOIL_THRESHOLD:
		return
	shake(ctx, clampf(recoil_force / 30.0, 2.0, 6.0), 0.14)


## Reproduce un efecto de sonido 8-bit por nombre (ver core/sfx.gd para el catálogo).
## `world_pos` (opcional) atenúa el sonido según la distancia al jugador; sin él suena a volumen pleno.
static func sfx(ctx: Node, sound: StringName, world_pos: Vector2 = Vector2.INF, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	SfxScript.play(ctx, sound, world_pos, volume_db, pitch)


## Reproduce un AudioStream real (por ejemplo, el `hit_stream` de un arma).
static func sfx_stream(ctx: Node, stream: AudioStream, world_pos: Vector2 = Vector2.INF) -> void:
	SfxScript.play_stream(ctx, stream, &"weapon_stream", world_pos, -2.0, randf_range(0.97, 1.03))


## Sonido de disparo del arma de fuego activa (sintetizado según sus stats o su `fire_stream`).
static func sfx_weapon_fire(ctx: Node, weapon: WeaponData) -> void:
	SfxScript.play_weapon_fire(ctx, weapon)


## Sonido de tajo del arma melee activa.
static func sfx_weapon_swing(ctx: Node, weapon: WeaponData) -> void:
	SfxScript.play_weapon_swing(ctx, weapon)


## Prepara el reproductor y genera los sonidos comunes (de a uno por cuadro).
static func sfx_prewarm(ctx: Node) -> void:
	SfxScript.prewarm(ctx)


## Fija la música base de la escena (menu, camp, explore...). Limpia anulaciones y situación previas.
static func music_set_base(ctx: Node, track: StringName) -> void:
	MusicScript.set_base(ctx, track)


## Fija la música de situación (combat, elite, boss) o vacío para volver a la base.
static func music_set_situation(ctx: Node, track: StringName) -> void:
	MusicScript.set_situation(ctx, track)


## Anula temporalmente la música (tienda, derrota, victoria). Se deshace con music_pop.
static func music_push(ctx: Node, track: StringName) -> void:
	MusicScript.push(ctx, track)


static func music_pop(ctx: Node, track: StringName) -> void:
	MusicScript.pop(ctx, track)


## Arranque de música de un nivel: exploración de base + director que sube combate / élite / jefe.
static func music_start_level(level: Node) -> void:
	MusicScript.set_base(level, &"explore")
	level.add_child.call_deferred(MusicDirectorScript.new())


## Explosión de partículas con sonido en la posición global indicada.
static func death_burst(ctx: Node, world_pos: Vector2) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	var tree: SceneTree = ctx.get_tree()
	var container: Node = tree.current_scene
	if container == null:
		container = tree.root

	# Chispas: ráfaga fogosa que cae por gravedad
	_spawn_emitter(container, world_pos, 18, 0.5, 100.0, 260.0, 3.0, 6.0, Vector2(0.0, 620.0), _make_fire_gradient())
	# Núcleo: destello blanco breve y más grande (se omite con "Reducir destellos")
	if not SettingsScript.reduce_flashes():
		_spawn_emitter(container, world_pos, 5, 0.14, 10.0, 60.0, 8.0, 12.0, Vector2.ZERO, _make_flash_gradient())

	_play_death_sound(container)


static func _spawn_emitter(
	container: Node,
	world_pos: Vector2,
	amount: int,
	lifetime: float,
	speed_min: float,
	speed_max: float,
	scale_min: float,
	scale_max: float,
	gravity: Vector2,
	ramp: Gradient
) -> void:
	var emitter: CPUParticles2D = CPUParticles2D.new()
	emitter.one_shot = true
	emitter.amount = maxi(1, int(roundf(float(amount) * SettingsScript.particle_scale())))
	emitter.lifetime = lifetime
	emitter.explosiveness = 1.0
	emitter.direction = Vector2.UP
	emitter.spread = 180.0
	emitter.initial_velocity_min = speed_min
	emitter.initial_velocity_max = speed_max
	# Partículas redondas (nunca cuadrados): la textura de gota de BloodFx, con la escala ajustada a su ancho
	var drop: Texture2D = BloodFxScript.disc_texture()
	emitter.texture = drop
	emitter.scale_amount_min = scale_min / float(drop.get_width())
	emitter.scale_amount_max = scale_max / float(drop.get_width())
	emitter.gravity = gravity
	emitter.color_ramp = ramp
	emitter.z_index = 20
	container.add_child(emitter)
	emitter.global_position = world_pos
	emitter.finished.connect(emitter.queue_free)
	emitter.emitting = true


static func _make_fire_gradient() -> Gradient:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 0.95, 0.6, 1.0),
		Color(1.0, 0.5, 0.15, 1.0),
		Color(0.6, 0.1, 0.05, 0.0),
	])
	return g


static func _make_flash_gradient() -> Gradient:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 0.9, 0.6, 0.0),
	])
	return g


static func _play_death_sound(container: Node) -> void:
	SfxScript.play(container, &"enemy_death", Vector2.INF, -4.0, randf_range(0.85, 1.15))
