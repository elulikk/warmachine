extends RefCounted
## Sintetizador y reproductor de efectos de sonido de estilo "shooter clásico" (tipo Doom).
## No usa assets: cada sonido se genera por código, se cachea y suena por un pool de voces.
## Sin class_name a propósito: se carga por preload desde GameFeel, que es el punto de entrada
## (`GameFeel.sfx(self, &"coin")`, `GameFeel.sfx_weapon_fire(self, weapon)`).
##
## Cómo se logra el carácter "sampleado de los 90":
## - Capas de ruido blanco filtrado (pasa-bajos con barrido) para el cuerpo y la cola de cada golpe.
## - Un "thump" senoidal grave con caída de tono para el peso.
## - Eco corto de sala y saturación suave (la degradación 8-bit de antes quedó apagada: ver `LOFI`).
##
## Disparos, impactos y explosiones de alta calidad: `assets/audio/sfx/<nombre>_<n>.wav` (los genera
## `art_source/audio/synth_guns.py`). Si existe `<nombre>_1.wav`, se usa en vez de la receta, con las variantes
## al azar sin repetir. Pisar esos archivos con audio real también funciona.
##
## Cómo reemplazar un sonido por audio real, sin tocar la lógica:
## - Por arma: asignar `fire_stream` / `hit_stream` en su WeaponData (.tres).
## - Por nombre: `Sfx.register_override(&"coin", preload("res://audio/coin.ogg"))`.
## Recetas: ver `_build()`. Para sumar un sonido nuevo, agregar un caso ahí y llamarlo por nombre.

const MIX_RATE: int = 22050
## true = degradación de los 90 (7 bits, ~11 kHz) en los sonidos sintetizados. Apagada: sonaba a 8-bit.
const LOFI: bool = false
## Carpeta de sonidos en archivo (`<nombre>_1.wav`, `<nombre>_2.wav`...), con prioridad sobre las recetas.
const SAMPLE_DIR: String = "res://assets/audio/sfx/"
const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"
const VOICE_COUNT: int = 20

## Atenuación por distancia al jugador (px): pleno hasta HEAR_FULL, silencio desde HEAR_MAX.
const HEAR_FULL_DISTANCE: float = 420.0
const HEAR_MAX_DISTANCE: float = 1400.0

## Separación mínima entre dos reproducciones del mismo sonido (evita saturar con ráfagas).
const DEFAULT_MIN_INTERVAL_MSEC: int = 35
const MIN_INTERVAL_MSEC: Dictionary = {
	&"shot_flame": 120,
	&"shot_extinguisher": 110,
	&"fire_ignite": 260,
	&"laser_beam": 80,
	&"chain_lightning": 45,
	&"shot_auto": 40,
	&"exp": 45,
	&"coin": 22,
	&"hit_world": 70,
	&"levelup": 400,
	&"jump": 120,
	&"land": 120,
	&"hurt": 150,
	&"hurt_thud": 150,
	&"heartbeat": 200,
	&"enemy_death": 60,
	&"enemy_death_flesh": 60,
	&"reload_out": 100,
	&"reload_done": 100,
	&"reload_shell": 60,
	&"reload_rack": 120,
}

## Sonidos que se generan de a uno por cuadro al cargar un nivel, para evitar tirones en el primer disparo.
const PREWARM_SOUNDS: Array[StringName] = [
	&"shot_pistol", &"shot_auto", &"shot_rifle", &"shot_shotgun", &"shot_flame", &"shot_ice",
	&"shot_revolver", &"shot_smg", &"shot_sniper", &"shot_sawed", &"shot_enemy_gun",
	&"swing", &"swing_light", &"swing_heavy",
	&"hit_flesh", &"hit_blade", &"hit_armor", &"hit_crit", &"hit_shield", &"hit_world",
	&"enemy_death", &"reload_out", &"reload_in", &"reload_done", &"reload_shell", &"reload_rack", &"weapon_swap",
	&"hurt", &"hurt_thud", &"heartbeat", &"jump", &"land", &"coin", &"exp", &"pickup_gear", &"levelup",
]

const WAVE_SQUARE: int = 0
const WAVE_TRIANGLE: int = 1
const WAVE_SAW: int = 2
const WAVE_NOISE: int = 3
const WAVE_SINE: int = 4

static var _cache: Dictionary = {}
static var _overrides: Dictionary = {}
static var _last_play_msec: Dictionary = {}
static var _host: Node = null
static var _voices: Array[AudioStreamPlayer] = []
static var _next_voice: int = 0
static var _listener: Node2D = null
static var _prewarmed: bool = false


# ==============================================================================
# API pública
# ==============================================================================

## Reproduce un sonido por nombre. `world_pos` (si se indica) atenúa según la distancia al jugador.
static func play(
	ctx: Node,
	sound: StringName,
	world_pos: Vector2 = Vector2.INF,
	volume_db: float = 0.0,
	pitch: float = 1.0
) -> void:
	var stream: AudioStream = _get_stream(sound)
	if stream == null:
		return
	play_stream(ctx, stream, sound, world_pos, volume_db, pitch)


## Reproduce un AudioStream ya resuelto (audio real asignado en un recurso). `key` agrupa el límite de frecuencia.
static func play_stream(
	ctx: Node,
	stream: AudioStream,
	key: StringName,
	world_pos: Vector2 = Vector2.INF,
	volume_db: float = 0.0,
	pitch: float = 1.0
) -> void:
	if stream == null or ctx == null or not ctx.is_inside_tree():
		return
	var tree: SceneTree = ctx.get_tree()
	if tree == null:
		return

	var now_msec: int = Time.get_ticks_msec()
	var min_gap: int = int(MIN_INTERVAL_MSEC.get(key, DEFAULT_MIN_INTERVAL_MSEC))
	var last_msec: int = int(_last_play_msec.get(key, -100000))
	if now_msec - last_msec < min_gap:
		return

	var gain_db: float = volume_db
	if world_pos != Vector2.INF:
		var attenuation: float = _distance_attenuation(tree, world_pos)
		if attenuation <= 0.01:
			return
		gain_db += linear_to_db(attenuation)

	var voice: AudioStreamPlayer = _acquire_voice(tree)
	if voice == null:
		return
	_last_play_msec[key] = now_msec
	voice.stream = stream
	voice.volume_db = gain_db
	voice.pitch_scale = clampf(pitch, 0.25, 4.0)
	voice.play()


## Disparo del arma activa. Usa `fire_stream` si el arma lo define; si no, sintetiza según sus stats.
static func play_weapon_fire(ctx: Node, weapon: WeaponData) -> void:
	if weapon == null:
		return
	if weapon.fire_stream != null:
		play_stream(ctx, weapon.fire_stream, &"weapon_stream", Vector2.INF, -2.0, randf_range(0.97, 1.03))
		return
	# Los sonidos en archivo ya traen el peso de cada arma: el tono varía poco para no deformarlos.
	var pitch: float = lerpf(1.06, 0.94, clampf(weapon.damage / 120.0, 0.0, 1.0)) * randf_range(0.97, 1.03)
	play(ctx, weapon_fire_profile(weapon), Vector2.INF, -3.0, pitch)


## Tajo del arma melee activa.
static func play_weapon_swing(ctx: Node, weapon: WeaponData) -> void:
	if weapon == null:
		return
	if weapon.fire_stream != null:
		play_stream(ctx, weapon.fire_stream, &"weapon_stream", Vector2.INF, -2.0, randf_range(0.97, 1.03))
		return
	var profile: StringName = &"swing"
	if weapon.damage >= 80.0 or weapon.fire_rate <= 1.3:
		profile = &"swing_heavy"
	elif weapon.fire_rate >= 3.0 or weapon.swing_duration <= 0.12:
		profile = &"swing_light"
	play(ctx, profile, Vector2.INF, -4.0, randf_range(0.94, 1.06))


## Elige la receta de disparo a partir de la familia y datos del arma (no depende del nombre).
static func weapon_fire_profile(weapon: WeaponData) -> StringName:
	if weapon.fire_sound != &"":
		return weapon.fire_sound
	# Armas que escupen combustible encendido (no lanzallamas): chasquido mágico suave en vez de bala.
	if weapon.projectile_scene != null and weapon.projectile_scene.resource_path.ends_with("fuel_droplet.tscn") and weapon.family != WeaponData.WeaponFamily.FLAMETHROWER:
		return &"shot_magic"
	match weapon.family:
		WeaponData.WeaponFamily.SHOTGUN:
			# Recortada o de dos caños (sin bomba) contra la de corredera
			return &"shot_sawed" if weapon.magazine_size <= 2 else &"shot_shotgun"
		WeaponData.WeaponFamily.FLAMETHROWER:
			return &"shot_flame"
		WeaponData.WeaponFamily.SNIPER:
			return &"shot_sniper"
		WeaponData.WeaponFamily.RIFLE:
			return &"shot_auto" if weapon.is_automatic else &"shot_rifle"
		WeaponData.WeaponFamily.CARBINE:
			return &"shot_rifle" if weapon.damage >= 24.0 else &"shot_auto"
		WeaponData.WeaponFamily.SMG:
			return &"shot_smg"
		WeaponData.WeaponFamily.ENERGY:
			if weapon.innate_status_effects.has("ICE"):
				return &"shot_ice"
			return &"shot_magic"
		WeaponData.WeaponFamily.REVOLVER:
			return &"shot_revolver"
		WeaponData.WeaponFamily.PISTOL:
			return &"shot_revolver" if weapon.damage >= 60.0 else &"shot_pistol"
	if weapon.pellets_per_shot >= 3:
		return &"shot_shotgun"
	if weapon.is_automatic and weapon.fire_rate >= 14.0:
		return &"shot_flame"
	if weapon.innate_status_effects.has("ICE"):
		return &"shot_ice"
	if weapon.innate_status_effects.has("FIRE"):
		return &"shot_magic"
	if weapon.damage >= 90.0 or weapon.projectile_speed >= 900.0:
		return &"shot_rifle"
	if weapon.is_automatic:
		return &"shot_auto"
	return &"shot_pistol"


## Sustituye un sonido por nombre con audio real (por ejemplo, un .ogg importado).
static func register_override(sound: StringName, stream: AudioStream) -> void:
	if stream == null:
		_overrides.erase(sound)
	else:
		_overrides[sound] = stream


## Volumen del bus SFX en escala lineal (0.0 a 1.0), para un futuro menú de opciones.
static func set_sfx_volume(linear: float) -> void:
	ensure_buses()
	var idx: int = AudioServer.get_bus_index(SFX_BUS)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


## Crea los buses `SFX` y `Music` (hijos de `Master`) si no existen todavía.
static func ensure_buses() -> void:
	for bus_name: StringName in [SFX_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


## Crea el reproductor y los buses y va generando los sonidos comunes de a uno por cuadro.
static func prewarm(ctx: Node) -> void:
	if ctx == null or not ctx.is_inside_tree():
		return
	var tree: SceneTree = ctx.get_tree()
	_ensure_host(tree)
	if _prewarmed:
		return
	_prewarmed = true
	for sound_name: StringName in PREWARM_SOUNDS:
		_get_stream(sound_name)
		await tree.process_frame


# ==============================================================================
# Reproductor
# ==============================================================================

## Crea el nodo anfitrión (colgado de la raíz, sobrevive a los cambios de escena). Devuelve true si ya está en el árbol.
static func _ensure_host(tree: SceneTree) -> bool:
	if _host != null and is_instance_valid(_host):
		return _host.is_inside_tree()
	if tree == null or tree.root == null:
		return false
	ensure_buses()
	_host = Node.new()
	_host.name = "SfxHost"
	_host.process_mode = Node.PROCESS_MODE_ALWAYS
	_voices.clear()
	_next_voice = 0
	for i in range(VOICE_COUNT):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		_host.add_child(voice)
		_voices.append(voice)
	tree.root.add_child.call_deferred(_host)
	return false


static func _acquire_voice(tree: SceneTree) -> AudioStreamPlayer:
	if not _ensure_host(tree):
		return null
	# Prefiere una voz libre; si todas suenan, roba la siguiente (round-robin)
	for offset in range(VOICE_COUNT):
		var idx: int = (_next_voice + offset) % VOICE_COUNT
		var candidate: AudioStreamPlayer = _voices[idx]
		if not candidate.playing:
			_next_voice = (idx + 1) % VOICE_COUNT
			return candidate
	var stolen: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	return stolen


static func _distance_attenuation(tree: SceneTree, world_pos: Vector2) -> float:
	if _listener == null or not is_instance_valid(_listener):
		_listener = tree.get_first_node_in_group(&"player") as Node2D
	if _listener == null:
		return 1.0
	var distance: float = _listener.global_position.distance_to(world_pos)
	var t: float = clampf((distance - HEAR_FULL_DISTANCE) / (HEAR_MAX_DISTANCE - HEAR_FULL_DISTANCE), 0.0, 1.0)
	return (1.0 - t) * (1.0 - t)


static func _get_stream(sound: StringName) -> AudioStream:
	if _overrides.has(sound):
		return _overrides[sound] as AudioStream
	if _cache.has(sound):
		return _cache[sound] as AudioStream
	var stream: AudioStream = _load_samples(sound)
	if stream == null:
		stream = _build(sound)
	_cache[sound] = stream
	return stream


## Variantes en archivo de un sonido (`<nombre>_1.wav`, `_2`...) como un AudioStreamRandomizer; null si no hay.
static func _load_samples(sound: StringName) -> AudioStream:
	var first: String = "%s%s_1.wav" % [SAMPLE_DIR, sound]
	if not ResourceLoader.exists(first):
		return null
	var randomizer: AudioStreamRandomizer = AudioStreamRandomizer.new()
	randomizer.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	randomizer.random_pitch = 1.0
	randomizer.random_volume_offset_db = 1.0
	var index: int = 1
	while index <= 8:
		var path: String = "%s%s_%d.wav" % [SAMPLE_DIR, sound, index]
		if not ResourceLoader.exists(path):
			break
		var variant: AudioStream = load(path) as AudioStream
		if variant != null:
			randomizer.add_stream(-1, variant)
		index += 1
	return randomizer if randomizer.streams_count > 0 else null


# ==============================================================================
# Síntesis
# ==============================================================================

## Define una capa de sonido.
## t: inicio (s) · d: duración (s) · f0/f1: frecuencia inicial/final (Hz) · w: onda · v: volumen
## e: exponente de caída · duty: ancho de pulso · vib: vibrato (fracción) · a: ataque (fracción de la capa)
## lp/lp1: frecuencia de corte del pasa-bajos al inicio/final (0 = sin filtro)
static func _l(
	t: float, d: float, f0: float, f1: float, w: int, v: float,
	e: float = 2.0, duty: float = 0.5, vib: float = 0.0, a: float = 0.0,
	lp: float = 0.0, lp1: float = -1.0
) -> Dictionary:
	return {
		"t": t, "d": d, "f0": f0, "f1": f1, "w": w, "v": v, "e": e, "duty": duty,
		"vib": vib, "a": a, "lp": lp, "lp1": lp1, "notes": PackedFloat32Array()
	}


## Ruido blanco filtrado: el cuerpo de casi todo golpe, disparo o explosión.
## lp0 -> lp1 es el barrido del filtro (brillante al inicio, apagado al final).
static func _n(t: float, d: float, v: float, e: float, lp0: float, lp1: float, a: float = 0.0) -> Dictionary:
	return _l(t, d, float(MIX_RATE), float(MIX_RATE), WAVE_NOISE, v, e, 0.5, 0.0, a, lp0, lp1)


## Thump senoidal con caída de tono: el peso del impacto.
static func _s(t: float, d: float, f0: float, f1: float, v: float, e: float = 2.0, vib: float = 0.0) -> Dictionary:
	return _l(t, d, f0, f1, WAVE_SINE, v, e, 0.5, vib)


## Capa de arpegio: recorre las notas indicadas en partes iguales de su duración.
static func _arp(t: float, d: float, notes: PackedFloat32Array, w: int, v: float, e: float = 1.2, duty: float = 0.5) -> Dictionary:
	var layer: Dictionary = _l(t, d, 0.0, 0.0, w, v, e, duty)
	layer["notes"] = notes
	return layer


## Mezcla las capas y aplica eco de sala, saturación y degradación 8-bit.
## crush_bits: profundidad de bits · hold: retención de muestras (2 = ~11 kHz) · drive: saturación
## echo_ms / echo_gain: eco corto de sala (0 = sin eco)
static func _render(
	total_seconds: float, layers: Array, crush_bits: int = 7, hold: int = 2,
	drive: float = 1.0, echo_ms: float = 0.0, echo_gain: float = 0.0
) -> AudioStreamWAV:
	var count: int = maxi(1, int(total_seconds * float(MIX_RATE)))
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(count)
	for layer: Dictionary in layers:
		buf = _mix_layer(buf, layer)

	# Eco de sala: dos rebotes decrecientes
	if echo_ms > 0.0 and echo_gain > 0.0:
		var delay: int = maxi(1, int(echo_ms * 0.001 * float(MIX_RATE)))
		for i in range(count - 1, delay - 1, -1):
			buf[i] += buf[i - delay] * echo_gain
		for i in range(count - 1, delay * 2 - 1, -1):
			buf[i] += buf[i - delay * 2] * echo_gain * 0.5

	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	var levels: float = float(1 << crush_bits) * 0.5
	var drive_norm: float = tanh(drive) if drive > 1.0 else 1.0
	var held: float = 0.0
	var step: int = maxi(1, hold)
	for i in range(count):
		if not LOFI or i % step == 0:
			var sample: float = buf[i] * 0.85
			if drive > 1.0:
				sample = tanh(sample * drive) / drive_norm
			sample = clampf(sample, -1.0, 1.0)
			# Reducción de profundidad de bits: el "grano" de los samples viejos (solo con LOFI)
			held = roundf(sample * levels) / levels if LOFI else sample
		# Fundido de las últimas muestras para no dejar un clic al final
		var tail: float = clampf(float(count - i) / 64.0, 0.0, 1.0)
		data.encode_s16(i * 2, int(held * tail * 32767.0))

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


static func _mix_layer(buf: PackedFloat32Array, layer: Dictionary) -> PackedFloat32Array:
	var start: int = int(float(layer["t"]) * float(MIX_RATE))
	var length: int = int(float(layer["d"]) * float(MIX_RATE))
	var f0: float = float(layer["f0"])
	var f1: float = float(layer["f1"])
	var wave: int = int(layer["w"])
	var volume: float = float(layer["v"])
	var decay: float = float(layer["e"])
	var duty: float = float(layer["duty"])
	var vibrato: float = float(layer["vib"])
	var attack_frac: float = float(layer["a"])
	var lp0: float = float(layer["lp"])
	var lp1: float = float(layer["lp1"])
	if lp1 < 0.0:
		lp1 = lp0
	var notes: PackedFloat32Array = layer["notes"] as PackedFloat32Array
	var ramp: int = maxi(1, int(0.002 * float(MIX_RATE)))

	var phase: float = 0.0
	var noise_value: float = 0.0
	var filter_state: float = 0.0
	for i in range(length):
		var idx: int = start + i
		if idx >= buf.size():
			break
		var t: float = float(i) / float(length)

		var freq: float = lerpf(f0, f1, t)
		if notes.size() > 0:
			freq = notes[mini(int(t * float(notes.size())), notes.size() - 1)]
		if vibrato > 0.0:
			freq *= 1.0 + vibrato * sin(TAU * 28.0 * float(i) / float(MIX_RATE))

		var previous_phase: float = phase
		phase += freq / float(MIX_RATE)
		var sample: float = 0.0
		match wave:
			WAVE_SQUARE:
				sample = 1.0 if fposmod(phase, 1.0) < duty else -1.0
			WAVE_TRIANGLE:
				sample = 1.0 - 4.0 * absf(fposmod(phase, 1.0) - 0.5)
			WAVE_SAW:
				sample = 2.0 * fposmod(phase, 1.0) - 1.0
			WAVE_SINE:
				sample = sin(TAU * phase)
			_:
				# Ruido: valor aleatorio retenido; con frecuencia >= MIX_RATE es ruido blanco
				if floorf(phase) != floorf(previous_phase):
					noise_value = randf_range(-1.0, 1.0)
				sample = noise_value

		# Pasa-bajos de un polo con corte variable (el ruido se recompensa para no quedar mudo)
		if lp0 > 0.0:
			var cutoff: float = lerpf(lp0, lp1, t)
			var alpha: float = 1.0 - exp(-TAU * cutoff / float(MIX_RATE))
			filter_state += alpha * (sample - filter_state)
			sample = filter_state
			if wave == WAVE_NOISE:
				sample *= minf(3.0, sqrt((2.0 - alpha) / maxf(alpha, 0.0001)))

		var envelope: float = 0.0
		if attack_frac > 0.0 and t < attack_frac:
			envelope = t / attack_frac
		else:
			var tail_t: float = (t - attack_frac) / maxf(0.0001, 1.0 - attack_frac)
			envelope = pow(maxf(0.0, 1.0 - tail_t), decay)
		if i < ramp:
			envelope *= float(i) / float(ramp)

		buf[idx] += sample * volume * envelope
	return buf


## Recetas de cada sonido. Todas sintetizadas.
static func _build(sound: StringName) -> AudioStreamWAV:
	var sq: int = WAVE_SQUARE
	var tri: int = WAVE_TRIANGLE
	var saw: int = WAVE_SAW
	var sine: int = WAVE_SINE
	match sound:
		# --- Disparos: chasquido brillante + cuerpo de ruido + thump grave + eco de sala ----
		&"shot_pistol":
			return _render(0.24, [
				_n(0.0, 0.035, 0.9, 3.0, 9000.0, 3000.0),
				_n(0.0, 0.15, 0.6, 2.4, 2800.0, 500.0),
				_s(0.0, 0.12, 230.0, 65.0, 0.8, 2.0),
			], 7, 2, 1.7, 42.0, 0.25)
		&"shot_auto":
			return _render(0.14, [
				_n(0.0, 0.025, 0.9, 3.0, 8500.0, 2500.0),
				_n(0.0, 0.09, 0.5, 2.4, 2200.0, 600.0),
				_s(0.0, 0.07, 190.0, 80.0, 0.8, 2.0),
			], 7, 2, 1.7, 30.0, 0.18)
		&"shot_rifle":
			return _render(0.7, [
				_n(0.0, 0.05, 1.0, 3.0, 10000.0, 2500.0),
				_s(0.0, 0.28, 150.0, 40.0, 1.0, 1.8),
				_n(0.0, 0.32, 0.8, 1.7, 3200.0, 300.0),
				_n(0.04, 0.5, 0.35, 1.3, 700.0, 180.0),
			], 7, 2, 1.8, 85.0, 0.32)
		&"shot_shotgun":
			return _render(0.8, [
				_n(0.0, 0.06, 1.0, 3.0, 11000.0, 2000.0),
				_s(0.0, 0.38, 120.0, 28.0, 1.0, 1.5),
				_n(0.0, 0.45, 0.9, 1.4, 2800.0, 200.0),
				# Bombeo de la corredera: dos clacs mecánicos
				_n(0.30, 0.02, 0.6, 3.0, 6000.0, 3000.0),
				_s(0.30, 0.04, 220.0, 120.0, 0.5, 2.5),
				_n(0.42, 0.02, 0.6, 3.0, 6000.0, 3000.0),
				_s(0.42, 0.05, 180.0, 90.0, 0.5, 2.5),
			], 7, 2, 1.9, 95.0, 0.35)
		&"shot_flame":
			# Soplido de gas encendido: ruido suave que sube y baja, rugido grave y chisporroteo.
			# Se dispara cada ~120 ms con 0.3 s de duración, así los disparos se funden en un rugido continuo.
			return _render(0.3, [
				_n(0.0, 0.3, 0.55, 1.2, 700.0, 2400.0, 0.35),
				_n(0.0, 0.3, 0.35, 1.0, 1800.0, 600.0, 0.5),
				_s(0.0, 0.3, 62.0, 48.0, 0.55, 1.0, 0.08),
				_n(0.05, 0.015, 0.35, 3.0, 5000.0, 2500.0),
				_n(0.14, 0.012, 0.3, 3.0, 4500.0, 2000.0),
				_n(0.22, 0.015, 0.3, 3.0, 5500.0, 2500.0),
			], 8, 1, 1.2, 38.0, 0.15)
		&"shot_ice":
			return _render(0.24, [
				_n(0.0, 0.10, 0.5, 2.5, 7000.0, 2000.0),
				_l(0.0, 0.16, 2200.0, 700.0, tri, 0.45, 1.8),
				_l(0.0, 0.12, 1000.0, 2600.0, sine, 0.25, 2.0),
			], 7, 1, 1.2, 50.0, 0.2)
		&"shot_magic":
			return _render(0.26, [
				_s(0.0, 0.24, 180.0, 520.0, 0.6, 1.3, 0.06),
				_n(0.0, 0.22, 0.35, 1.5, 1500.0, 4000.0, 0.4),
				_l(0.0, 0.2, 1200.0, 300.0, tri, 0.25, 2.0),
			], 7, 1, 1.3, 60.0, 0.22)
		&"shot_bow":
			return _render(0.18, [
				_l(0.0, 0.14, 750.0, 160.0, tri, 0.6, 3.0),
				_n(0.0, 0.05, 0.35, 3.0, 6000.0, 2000.0),
				_n(0.0, 0.12, 0.2, 2.0, 1500.0, 500.0),
			], 7, 2, 1.2)
		&"shot_enemy":
			return _render(0.14, [
				_l(0.0, 0.10, 700.0, 180.0, sq, 0.35, 2.0, 0.25, 0.0, 0.0, 3500.0),
				_n(0.0, 0.05, 0.45, 3.0, 6000.0, 1500.0),
				_s(0.0, 0.08, 160.0, 60.0, 0.5, 2.0),
			], 7, 2, 1.5, 35.0, 0.2)
		&"shot_drone":
			return _render(0.1, [
				_l(0.0, 0.08, 1900.0, 700.0, sine, 0.4, 2.0),
				_n(0.0, 0.02, 0.4, 3.0, 6000.0, 3000.0),
			], 7, 1, 1.1)

		# --- Melee: silbido de aire con filtro que sube + golpe grave ------------------------
		&"swing_light":
			return _render(0.13, [
				_n(0.0, 0.11, 0.6, 1.5, 900.0, 4500.0, 0.3),
			], 7, 2, 1.0)
		&"swing":
			return _render(0.18, [
				_n(0.0, 0.16, 0.7, 1.7, 600.0, 3500.0, 0.35),
				_s(0.0, 0.14, 140.0, 90.0, 0.25, 2.0),
			], 7, 2, 1.1)
		&"swing_heavy":
			return _render(0.3, [
				_n(0.0, 0.28, 0.85, 1.5, 400.0, 2600.0, 0.4),
				_s(0.05, 0.22, 80.0, 40.0, 0.6, 2.0),
			], 7, 2, 1.3, 40.0, 0.15)

		# --- Impactos -------------------------------------------------------------------------
		&"hit_flesh":
			return _render(0.13, [
				_s(0.0, 0.10, 160.0, 45.0, 0.9, 2.2),
				_n(0.0, 0.10, 0.8, 2.5, 3000.0, 400.0),
				_n(0.0, 0.03, 0.5, 3.0, 8000.0, 3000.0),
			], 7, 2, 1.5)
		&"hit_blade":
			return _render(0.15, [
				_n(0.0, 0.12, 0.8, 2.5, 9000.0, 1500.0),
				_l(0.0, 0.12, 1200.0, 900.0, tri, 0.3, 2.5),
				_s(0.0, 0.08, 200.0, 80.0, 0.5, 2.5),
			], 7, 2, 1.4)
		&"hit_armor":
			return _render(0.2, [
				_n(0.0, 0.04, 0.9, 4.0, 10000.0, 5000.0),
				_l(0.0, 0.18, 1850.0, 1700.0, sq, 0.3, 3.0, 0.125),
				_l(0.0, 0.18, 2750.0, 2650.0, tri, 0.25, 3.0),
				_s(0.0, 0.06, 300.0, 150.0, 0.5, 3.0),
			], 7, 1, 1.4, 25.0, 0.2)
		&"hit_crit":
			return _render(0.22, [
				_n(0.0, 0.05, 1.0, 3.0, 10000.0, 3000.0),
				_s(0.0, 0.14, 200.0, 45.0, 1.0, 2.0),
				_l(0.0, 0.16, 900.0, 1800.0, sq, 0.3, 2.0, 0.25, 0.0, 0.0, 5000.0),
				_n(0.0, 0.12, 0.6, 2.5, 4000.0, 800.0),
			], 7, 2, 1.7, 30.0, 0.2)
		&"hit_shield":
			return _render(0.18, [
				_l(0.0, 0.15, 1400.0, 350.0, saw, 0.4, 2.0, 0.5, 0.1, 0.0, 4000.0),
				_l(0.0, 0.10, 2600.0, 700.0, tri, 0.25, 2.5),
				_n(0.0, 0.03, 0.4, 3.0, 9000.0, 4000.0),
			], 7, 1, 1.3)
		&"hit_world":
			return _render(0.08, [
				_n(0.0, 0.06, 0.5, 3.5, 5000.0, 1200.0),
				_s(0.0, 0.04, 180.0, 90.0, 0.3, 3.0),
			], 7, 2, 1.0)
		&"parry":
			return _render(0.32, [
				_l(0.0, 0.3, 1800.0, 1800.0, sine, 0.35, 2.0),
				_l(0.0, 0.3, 2700.0, 2700.0, sine, 0.2, 2.5),
				_l(0.0, 0.25, 3600.0, 3600.0, tri, 0.12, 3.0),
				_n(0.0, 0.06, 0.7, 4.0, 9000.0, 3000.0),
			], 7, 1, 1.3, 35.0, 0.2)
		&"drip":  # gota de alcantarilla: "plip" agudo que cae de tono y rebota en la bóveda (eco largo)
			return _render(0.5, [
				_l(0.0, 0.09, 1900.0, 700.0, sine, 0.45, 3.0),
				_l(0.0, 0.05, 3800.0, 1400.0, sine, 0.15, 3.5),
				_n(0.0, 0.015, 0.2, 4.0, 6000.0, 2500.0),
			], 9, 1, 1.0, 110.0, 0.5)
		&"flute_call":  # Flauta de Hamelin: tres notas suaves que suben
			return _render(0.5, [
				_arp(0.0, 0.42, PackedFloat32Array([784.0, 988.0, 1319.0]), tri, 0.3, 0.9),
				_arp(0.0, 0.42, PackedFloat32Array([1568.0, 1976.0, 2637.0]), sine, 0.08, 1.2),
			], 9, 1, 1.0, 70.0, 0.3)
		&"rat_screech":  # chillido de la Rata Gigante
			return _render(0.55, [
				_l(0.0, 0.5, 2100.0, 650.0, saw, 0.45, 1.4, 0.5, 0.18, 0.0, 3800.0, 900.0),
				_n(0.0, 0.2, 0.25, 2.0, 5000.0, 1500.0),
			], 8, 2, 1.3, 60.0, 0.25)
		&"enemy_death_flesh":  # cuerpo que cae: golpe sordo y húmedo, sin estallido
			return _render(0.28, [
				_s(0.0, 0.2, 130.0, 40.0, 0.9, 2.2),
				_n(0.0, 0.16, 0.5, 2.5, 1800.0, 250.0),
				_n(0.03, 0.1, 0.3, 3.0, 900.0, 200.0),
			], 7, 2, 1.5)
		&"enemy_death":
			return _render(0.6, [
				_l(0.0, 0.5, 260.0, 35.0, saw, 0.6, 1.3, 0.5, 0.14, 0.0, 1300.0, 200.0),
				_n(0.0, 0.45, 0.6, 1.4, 3000.0, 150.0),
				_s(0.0, 0.3, 100.0, 30.0, 0.8, 1.8),
				_n(0.0, 0.04, 0.7, 3.0, 8000.0, 3000.0),
			], 7, 2, 1.6, 60.0, 0.22)

		# --- Armas: mecanismos (clics secos con golpe grave) -----------------------------------
		&"reload_out":
			return _render(0.1, [
				_n(0.0, 0.012, 0.9, 2.5, 7000.0, 4000.0),
				_s(0.0, 0.05, 260.0, 110.0, 0.6, 3.0),
				_n(0.045, 0.03, 0.4, 3.0, 3000.0, 1500.0),
			], 7, 1, 1.2)
		&"reload_in":
			return _render(0.12, [
				_n(0.0, 0.04, 0.45, 2.0, 3000.0, 1500.0, 0.3),
				_n(0.05, 0.012, 0.9, 2.5, 7000.0, 4000.0),
				_s(0.05, 0.05, 180.0, 90.0, 0.6, 3.0),
			], 7, 1, 1.2)
		&"reload_done":
			return _render(0.18, [
				_n(0.0, 0.015, 0.9, 2.5, 7000.0, 4000.0),
				_s(0.0, 0.06, 200.0, 80.0, 0.7, 3.0),
				_n(0.08, 0.012, 0.8, 2.5, 8000.0, 4000.0),
				_s(0.08, 0.05, 260.0, 120.0, 0.5, 3.0),
			], 7, 1, 1.3)
		&"reload_shell":  # bala o cartucho que entra: clic metálico corto y agudo
			return _render(0.08, [
				_n(0.0, 0.01, 0.8, 2.5, 9000.0, 5000.0),
				_s(0.0, 0.035, 520.0, 300.0, 0.4, 3.0),
				_n(0.02, 0.02, 0.3, 3.0, 4000.0, 2000.0),
			], 7, 1, 1.2)
		&"reload_rack":  # bombeo de escopeta o cerrojo: corredera atrás (raspado) y adelante (golpe)
			return _render(0.24, [
				_n(0.0, 0.06, 0.5, 1.8, 3500.0, 1800.0, 0.2),
				_n(0.06, 0.014, 0.9, 2.5, 7500.0, 4000.0),
				_s(0.06, 0.06, 210.0, 90.0, 0.7, 3.0),
				_n(0.13, 0.05, 0.45, 1.8, 3200.0, 1600.0, 0.2),
				_n(0.18, 0.014, 1.0, 2.5, 8000.0, 4000.0),
				_s(0.18, 0.05, 260.0, 110.0, 0.6, 3.0),
			], 7, 1, 1.3)
		&"reload_vent":  # depósito de energía que se acopla: siseo filtrado descendente
			return _render(0.36, [
				_n(0.0, 0.32, 0.55, 1.2, 9000.0, 1200.0, 0.05),
				_l(0.0, 0.3, 900.0, 300.0, tri, 0.18, 1.6),
			], 7, 2, 1.1)
		&"weapon_swap":
			return _render(0.1, [
				_n(0.0, 0.04, 0.4, 2.5, 2500.0, 1500.0, 0.3),
				_n(0.04, 0.012, 0.7, 3.0, 6000.0, 3000.0),
				_s(0.04, 0.04, 200.0, 100.0, 0.4, 3.0),
			], 7, 1, 1.1)

		# --- Jugador ----------------------------------------------------------------------------
		&"hurt":
			return _render(0.26, [
				_l(0.0, 0.20, 230.0, 110.0, saw, 0.7, 1.4, 0.5, 0.06, 0.0, 1500.0, 700.0),
				_n(0.0, 0.12, 0.4, 2.5, 1800.0, 500.0),
				_s(0.0, 0.10, 120.0, 60.0, 0.5, 2.0),
			], 7, 2, 1.4)
		&"hurt_thud":  # cuerpo enemigo que empuja al jugador: golpe sordo que se suma al grito de "hurt"
			return _render(0.16, [
				_s(0.0, 0.14, 150.0, 45.0, 1.0, 2.2),
				_n(0.0, 0.05, 0.5, 3.0, 2500.0, 600.0),
			], 7, 2, 1.3)
		&"heartbeat":
			# Dos golpes sordos seguidos (lub-dub), graves y sin brillo
			return _render(0.42, [
				_s(0.0, 0.14, 70.0, 38.0, 1.0, 1.6),
				_n(0.0, 0.06, 0.25, 2.5, 500.0, 150.0),
				_s(0.17, 0.16, 58.0, 32.0, 0.8, 1.6),
				_n(0.17, 0.06, 0.2, 2.5, 450.0, 130.0),
			], 8, 1, 1.2)
		&"player_death":
			return _render(0.9, [
				_l(0.0, 0.7, 200.0, 40.0, saw, 0.7, 1.2, 0.5, 0.1, 0.0, 1100.0, 250.0),
				_n(0.0, 0.5, 0.45, 1.5, 2500.0, 150.0),
				_s(0.1, 0.5, 90.0, 30.0, 0.6, 1.5),
			], 6, 2, 1.5, 80.0, 0.3)
		&"jump":
			return _render(0.13, [
				_n(0.0, 0.10, 0.25, 2.0, 500.0, 1800.0, 0.2),
				_s(0.0, 0.09, 130.0, 220.0, 0.3, 2.0),
			], 7, 2, 1.0)
		&"land":
			return _render(0.1, [
				_s(0.0, 0.09, 110.0, 45.0, 0.8, 2.0),
				_n(0.0, 0.07, 0.45, 2.5, 900.0, 200.0),
			], 7, 2, 1.2)

		# --- Recolección y progreso (limpios: senoidales con arpegios cortos) -------------------
		&"coin":
			# "Ding" clásico: si bemol - mi agudo en onda cuadrada, con un destello una octava arriba
			return _render(0.26, [
				_arp(0.0, 0.07, PackedFloat32Array([988.0]), sq, 0.2, 1.0),
				_arp(0.065, 0.19, PackedFloat32Array([1319.0]), sq, 0.2, 1.0),
				_arp(0.065, 0.19, PackedFloat32Array([2637.0]), sine, 0.12, 1.0),
			], 7, 1, 1.0)
		&"exp":
			return _render(0.1, [
				_l(0.0, 0.09, 800.0, 1500.0, sine, 0.35, 1.4),
			], 7, 1, 1.0)
		&"heal":
			return _render(0.32, [
				_arp(0.0, 0.3, PackedFloat32Array([523.0, 659.0, 784.0]), sine, 0.45, 1.0),
			], 7, 1, 1.0)
		&"pickup_gear":
			return _render(0.26, [
				_arp(0.0, 0.24, PackedFloat32Array([440.0, 554.0, 659.0, 880.0]), tri, 0.4, 1.0),
				_n(0.0, 0.02, 0.5, 3.0, 7000.0, 3000.0),
			], 7, 1, 1.1)
		&"pickup_ammo":
			return _render(0.1, [
				_n(0.0, 0.015, 0.8, 3.0, 7000.0, 3000.0),
				_s(0.0, 0.05, 220.0, 110.0, 0.6, 2.5),
				_n(0.06, 0.015, 0.7, 3.0, 7000.0, 3000.0),
			], 7, 1, 1.1)
		&"levelup":
			return _render(0.7, [
				_arp(0.0, 0.62, PackedFloat32Array([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0]), sq, 0.26, 0.8, 0.25),
				_arp(0.0, 0.62, PackedFloat32Array([262.0, 330.0, 392.0, 523.0, 392.0, 523.0]), tri, 0.3, 0.8),
				_arp(0.0, 0.62, PackedFloat32Array([1047.0, 1319.0, 1568.0, 2093.0, 1568.0, 2093.0]), sine, 0.15, 0.8),
			], 7, 1, 1.2, 70.0, 0.2)
		&"potion":
			return _render(0.3, [
				_l(0.0, 0.28, 220.0, 520.0, sine, 0.5, 1.2, 0.5, 0.2),
				_n(0.0, 0.2, 0.15, 1.5, 1200.0, 600.0),
			], 7, 1, 1.0)
		&"buy":
			return _render(0.24, [
				_arp(0.0, 0.22, PackedFloat32Array([784.0, 1175.0, 1568.0]), sine, 0.4, 1.0),
			], 7, 1, 1.0)
		&"deny":
			return _render(0.18, [
				_l(0.0, 0.15, 150.0, 105.0, saw, 0.5, 1.5, 0.5, 0.0, 0.0, 900.0),
			], 7, 2, 1.1)

		# --- Granadas y mundo ------------------------------------------------------------------
		&"throw":
			return _render(0.15, [
				_n(0.0, 0.13, 0.5, 1.6, 700.0, 3500.0, 0.3),
				_s(0.0, 0.1, 140.0, 200.0, 0.2, 2.0),
			], 7, 2, 1.0)
		&"glass_break":
			# Frasco de ácido que estalla: crujido brillante, una lluvia de tintineos de vidrio
			# a destiempo y un chapoteo húmedo y corto al final.
			return _render(0.6, [
				_n(0.0, 0.05, 0.9, 3.0, 12000.0, 5000.0),
				_l(0.0, 0.12, 3400.0, 2600.0, tri, 0.3, 3.0, 0.5, 0.0, 0.0, 9000.0),
				_l(0.03, 0.14, 5200.0, 4300.0, sine, 0.25, 3.5),
				_l(0.07, 0.12, 4100.0, 3300.0, tri, 0.22, 3.5),
				_l(0.12, 0.16, 6100.0, 5000.0, sine, 0.18, 3.0),
				_l(0.18, 0.12, 3000.0, 2400.0, tri, 0.16, 3.5),
				_l(0.25, 0.1, 5600.0, 4700.0, sine, 0.12, 3.0),
				_n(0.04, 0.3, 0.45, 1.8, 3200.0, 500.0, 0.1),
				_s(0.0, 0.12, 180.0, 70.0, 0.4, 2.0),
			], 8, 1, 1.4, 55.0, 0.2)
		&"boom_frag":
			return _render(0.75, [
				_n(0.0, 0.04, 1.0, 3.0, 11000.0, 2500.0),
				_s(0.0, 0.5, 100.0, 24.0, 1.0, 1.6),
				_n(0.0, 0.55, 0.9, 1.4, 3000.0, 150.0),
				_n(0.08, 0.4, 0.4, 1.5, 1200.0, 200.0),
			], 7, 2, 1.9, 110.0, 0.35)
		&"boom_ice":
			return _render(0.55, [
				_n(0.0, 0.45, 0.5, 1.8, 6000.0, 900.0),
				_l(0.0, 0.4, 1700.0, 350.0, tri, 0.35, 1.5),
				_l(0.0, 0.25, 2500.0, 500.0, sq, 0.2, 2.5, 0.125, 0.0, 0.0, 4000.0),
				_s(0.0, 0.25, 120.0, 40.0, 0.7, 2.0),
			], 7, 1, 1.5, 70.0, 0.25)
		&"fire_ignite":
			# Charco de combustible que se prende: soplido corto y grave, sin golpe (suena muchas veces seguidas).
			return _render(0.25, [
				_n(0.0, 0.25, 0.4, 1.4, 500.0, 1600.0, 0.4),
				_s(0.0, 0.2, 70.0, 50.0, 0.3, 1.5),
			], 8, 1, 1.2, 38.0, 0.15)
		&"laser_beam":
			# Tick del haz: zumbido eléctrico corto y agudo (suena cada 0.1 s con el rayo sostenido)
			return _render(0.12, [
				_l(0.0, 0.1, 1500.0, 900.0, saw, 0.3, 1.2, 0.5, 0.0, 0.0, 3500.0),
				_n(0.0, 0.08, 0.25, 1.4, 6000.0, 2500.0),
			], 8, 1, 1.0)
		&"chain_lightning":
			# Chasquido eléctrico: crujido agudo con un golpe seco
			return _render(0.22, [
				_l(0.0, 0.18, 2400.0, 500.0, saw, 0.35, 1.3, 0.5, 0.0, 0.0, 4500.0),
				_n(0.0, 0.16, 0.5, 1.6, 8000.0, 1500.0),
				_s(0.0, 0.08, 140.0, 60.0, 0.5, 1.8),
			], 7, 1, 1.2)
		&"cloak_on":
			# Tela que se abre / roce: soplido filtrado ascendente
			return _render(0.35, [
				_n(0.0, 0.3, 0.4, 1.6, 600.0, 2800.0, 0.3),
				_l(0.0, 0.25, 220.0, 520.0, sine, 0.2, 1.4),
			], 7, 1, 1.1, 40.0, 0.2)
		&"cloak_off":
			return _render(0.3, [
				_n(0.0, 0.25, 0.4, 1.5, 2800.0, 500.0, 0.3),
				_l(0.0, 0.2, 520.0, 200.0, sine, 0.2, 1.4),
			], 7, 1, 1.1, 40.0, 0.2)
		&"net_deploy":
			# Red que se abre: soplido de tela con un chasquido corto y grave al caer.
			return _render(0.45, [
				_n(0.0, 0.3, 0.45, 1.5, 3500.0, 700.0, 0.3),
				_l(0.0, 0.2, 520.0, 220.0, tri, 0.25, 1.5),
				_s(0.0, 0.12, 110.0, 60.0, 0.5, 1.8),
			], 7, 1, 1.2, 45.0, 0.2)
		&"boom_fire":
			return _render(0.7, [
				_s(0.0, 0.55, 85.0, 22.0, 1.0, 1.4),
				_n(0.0, 0.5, 0.9, 1.2, 2600.0, 120.0, 0.05),
				_l(0.0, 0.45, 280.0, 55.0, saw, 0.35, 1.5, 0.5, 0.0, 0.0, 1200.0),
			], 7, 2, 1.8, 100.0, 0.3)
		&"checkpoint":
			return _render(0.4, [
				_arp(0.0, 0.38, PackedFloat32Array([523.0, 784.0, 1047.0]), tri, 0.4, 1.0),
				_arp(0.0, 0.38, PackedFloat32Array([262.0, 392.0, 523.0]), sine, 0.3, 1.0),
			], 7, 1, 1.0, 60.0, 0.2)
		&"gate_open":
			return _render(0.8, [
				_l(0.0, 0.55, 60.0, 120.0, saw, 0.5, 1.0, 0.5, 0.04, 0.0, 600.0, 900.0),
				_n(0.0, 0.5, 0.4, 1.0, 500.0, 1200.0, 0.2),
				_arp(0.2, 0.3, PackedFloat32Array([392.0, 523.0, 659.0]), sine, 0.25, 1.0),
			], 7, 2, 1.3, 90.0, 0.25)
		&"barrier_close":
			return _render(0.4, [
				_s(0.0, 0.3, 75.0, 35.0, 0.9, 1.6),
				_n(0.0, 0.25, 0.5, 2.0, 900.0, 200.0),
				_n(0.0, 0.03, 0.9, 3.0, 9000.0, 3000.0),
				_l(0.02, 0.1, 420.0, 380.0, tri, 0.2, 3.0),
			], 7, 2, 1.5, 60.0, 0.25)
		&"barrier_open":
			return _render(0.32, [
				_l(0.0, 0.28, 70.0, 160.0, saw, 0.4, 1.6, 0.5, 0.0, 0.0, 700.0),
				_n(0.0, 0.2, 0.35, 2.0, 1500.0, 600.0),
				_n(0.0, 0.03, 0.7, 3.0, 8000.0, 3000.0),
			], 7, 2, 1.3, 50.0, 0.2)
	return null
