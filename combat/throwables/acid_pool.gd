class_name AcidPool
extends Area2D
## Charco de ácido persistente. Aplica ticks continuos a los blancos hostiles que lo pisan
## con `armor_penetration = 1.0`, anulando su armadura mientras dura el efecto.
## Cada charco es CHICO e independiente (área, daño, duración y mancha propios). La granada cae como un solo
## charco "raíz" que al nacer reparte `cluster_count - 1` charcos hermanos pegados a su alrededor.
##
## Rendimiento: los charcos se reciclan (al vencer vuelven a una reserva y los hermanos salen de ahí en vez de
## instanciarse), hay un tope de charcos activos (el más viejo cede su lugar) y nada de lo que está fuera de la
## cámara se anima ni se dibuja. Los ticks de daño de cada charco arrancan desfasados para no juntarse en un cuadro.

@export var lifetime: float = 5.0
@export var tick_interval: float = 0.5
@export var tick_damage: float = 8.0
@export var armor_penetration: float = 1.0
## Ancho del área de daño de ESTE charco (px). Las manchas dibujadas son más anchas y se solapan entre vecinos.
@export var pool_width: float = 36.0
@export var pool_height: float = 36.0
@export var pool_color: Color = Color(0.45, 0.95, 0.15, 1.0)
## Charcos en total que deja una granada (incluido este). Los hermanos nacen con 1.
@export var cluster_count: int = 6

var source_node: Node2D = null
## Retardo de aparición (s) y espejado/desfase de animación propios; los fija el que reparte el grupo.
var splash_delay: float = 0.0
var _is_sibling: bool = false
## Identifica a los charcos de una misma granada (el id del raíz); entre ellos no se tapan.
var _cluster_id: int = 0

var _age: float = 0.0
var _tick_timer: float = 0.0
var _frames: Array[Texture2D] = []

## Un PNG por cuadro (acid_pool_0.png ... acid_pool_3.png), todos del mismo tamaño y alineados arriba.
const FRAME_PATH: String = "res://assets/sprites/efectos/acid_pool_%d.png"
## Cuadros de la hoja (fila horizontal) y velocidad de la animación en el piso.
const FRAME_COUNT: int = 4
const FRAME_FPS: float = 7.0
## Los goteos del sprite se comprimen en vertical para que no cuelguen demasiado bajo el piso.
const SPRITE_VSQUASH: float = 0.5
## Duración de la aparición (la mancha se estira desde el impacto y rebota un poco).
const SPLAT_TIME: float = 0.3
## Ancho de la mancha dibujada de cada charco (px); es mayor que el área de daño para que los vecinos se unan.
const BLOB_WIDTH: float = 58.0
## Separación entre centros de charcos vecinos del grupo y desvío al azar de cada uno.
const CLUSTER_STEP: float = 24.0
const CLUSTER_JITTER: float = 3.0
## Variación de duración entre charcos de un mismo grupo (multiplicador al azar).
const CLUSTER_LIFETIME_MIN: float = 0.85
const CLUSTER_LIFETIME_MAX: float = 1.1
## Con tantos charcos activos a la vez las granadas nuevas reparten solo CLUSTER_MIN_COUNT (protege la lluvia masiva).
const CLUSTER_BUDGET_POOLS: int = 60
const CLUSTER_MIN_COUNT: int = 3
## Dónde se busca piso para cada charco hermano (relativo al raíz): desde arriba hasta abajo.
const CLUSTER_RAY_UP: float = 12.0
const CLUSTER_RAY_DOWN: float = 18.0
const ViewCullScript = preload("res://core/view_cull.gd")
const SettingsScript = preload("res://core/settings.gd")
const FxShadersScript = preload("res://combat/fx_shaders.gd")
## Estilos (opción gráfica "fire_style"): 0 sprites, 1 partículas, 2 shaders
const STYLE_PARTICLES: int = 1
const STYLE_SHADERS: int = 2
## Mancha del estilo shader: ancho y alto del cuadro (px)
const SHADER_BLOB_W: float = 70.0
const SHADER_BLOB_H: float = 26.0
const POOL_SCENE_PATH: String = "res://combat/throwables/acid_pool.tscn"
## Tope de charcos activos a la vez: al pasarse, el más viejo desaparece para dejar lugar al nuevo.
const MAX_ACTIVE: int = 100
## Charcos vencidos que se guardan para reutilizar (los que sobran se liberan).
const RESERVE_SIZE: int = 60
## Los charcos más lejos que esto de la cámara (px) no animan gotas ni se redibujan.
const VIEW_MARGIN: float = 120.0
## Altura máxima (px) a la que una mancha asoma por encima del borde del piso.
const BLOB_RAISE_MAX: float = 4.0
## Retardo extra de aparición por cada px de distancia al centro (el charco se abre desde el impacto).
const BLOB_DELAY_PER_PX: float = 0.0008
## Gotas de ácido que saltan al romperse el frasco y caen al piso.
const DROP_COUNT: int = 16
## Ancho de referencia del charco para escalar la cantidad de gotas.
const DROP_REF_WIDTH: float = 150.0
## Con muchos charcos a la vez las gotas se reducen: pasado este número de charcos activos, cada charco
## nuevo suelta proporcionalmente menos (mínimo DROP_MIN_COUNT). Protege la lluvia masiva.
const DROP_BUDGET_POOLS: int = 48
const DROP_MIN_COUNT: int = 3
const DROP_GRAVITY: float = 1150.0
## Lo que tarda una gota posada en fundirse con el charco, y el desvanecido final del charco.
const DROP_SPLAT_TIME: float = 0.3
const FADE_OUT_TIME: float = 0.8

## Un charco nuevo que cae encima de otro (su mancha tapa al menos esta fracción de la del viejo) hace desaparecer
## el dibujo del viejo. El área y el daño del viejo siguen; solo se ahorra dibujar manchas superpuestas.
## Vale charco por charco, salvo entre los de una misma granada, que se tocan a propósito.
const COVER_OVERLAP: float = 0.5
## Diferencia máxima de altura (px) para considerar que dos charcos están en el mismo piso.
const COVER_MAX_DY: float = 24.0
const COVER_FADE_TIME: float = 0.25

var _covered_by: AcidPool = null
## Generación del que tapa: si ese charco se reutilizó desde entonces, ya no tapa a nadie.
var _covered_gen: int = 0
## Cuántas veces se activó este nodo (para invalidar referencias a un charco reciclado) y si está en uso.
var _gen: int = 0
var _in_use: bool = false
var _shape_node: CollisionShape2D = null
var _style: int = 0
var _particles: CPUParticles2D = null

## Activos (del más viejo al más nuevo) y vencidos listos para reutilizar. Sin tipo: pueden quedar liberados
## al cambiar de escena, y `_exit_tree` los saca.
static var _active: Array = []
static var _reserve: Array = []
static var _frame_cache: Array[Texture2D] = []
static var _drop_tex_cache: Texture2D = null
## Cuadro de animación dibujado por última vez; el charco solo se redibuja cuando cambia (o mientras
## hay algo en movimiento), en vez de pedir un redibujo por cada paso de física.
var _last_frame_idx: int = -1
## Fin de la aparición de la última mancha (retardo máximo + SPLAT_TIME).
var _splat_end: float = 0.0
## 1 = dibujo completo, 0 = oculto por otro charco encima.
var _vis: float = 1.0

## Cada mancha: x (px desde el centro), ancho (px), alzada (px sobre el piso), retardo (s).
var _blobs: Array[Vector4] = []
var _flip: float = 1.0
var _frame_offset: int = 0

## Gotas en arreglos paralelos (mucho más baratos que un Dictionary por gota):
## posición, velocidad, tamaño en px y tiempo posado (< 0 = todavía en vuelo).
var _drop_pos: PackedVector2Array = PackedVector2Array()
var _drop_vel: PackedVector2Array = PackedVector2Array()
var _drop_size: PackedFloat32Array = PackedFloat32Array()
var _drop_landed_t: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false

	# El rectángulo se apoya sobre el punto de impacto para cubrir a quienes están parados encima.
	_shape_node = CollisionShape2D.new()
	_shape_node.shape = RectangleShape2D.new()
	add_child(_shape_node)

	if _frame_cache.is_empty():
		for i: int in FRAME_COUNT:
			var path: String = FRAME_PATH % i
			if not ResourceLoader.exists(path):
				_frame_cache.clear()
				break
			_frame_cache.append(load(path) as Texture2D)
	_frames = _frame_cache
	_activate()
	if _is_sibling:
		return
	GameFeel.sfx(self, &"glass_break", global_position, -1.0, randf_range(0.94, 1.06))
	_spawn_siblings()


func _exit_tree() -> void:
	_active.erase(self)
	_reserve.erase(self)


## Deja el charco listo para un uso nuevo (primer nacimiento o reutilización desde la reserva).
func _activate() -> void:
	_gen += 1
	_in_use = true
	_set_style(SettingsScript.get_int("fire_style"))
	_age = 0.0
	# Desfasado al azar: los ticks de muchos charcos no caen en el mismo cuadro.
	_tick_timer = randf_range(0.05, maxf(0.06, tick_interval))
	_covered_by = null
	_vis = 1.0
	_last_frame_idx = -1
	_clear_drops()
	(_shape_node.shape as RectangleShape2D).size = Vector2(pool_width, pool_height)
	_shape_node.position = Vector2(0.0, -pool_height * 0.5)
	if _cluster_id == 0:
		_cluster_id = get_instance_id()
	visible = true
	set_physics_process(true)
	# Diferido, igual que al liberar: si se libera y reutiliza en el mismo cuadro, gana el último pedido.
	set_deferred("monitoring", true)
	add_to_group(&"acid_pools")
	_build_blobs()
	_cover_older_pools()
	_spawn_drops()
	_active.append(self)
	# Tope: el más viejo cede el lugar (a veces ya fue liberado al cambiar de escena).
	while _active.size() > MAX_ACTIVE:
		var oldest: Variant = _active.pop_front()
		if is_instance_valid(oldest) and oldest != self:
			(oldest as AcidPool)._release()


## Vuelve a la reserva (oculto y sin física) o se libera si la reserva está llena.
func _release() -> void:
	if not _in_use:
		return
	_in_use = false
	_active.erase(self)
	remove_from_group(&"acid_pools")
	_clear_drops()
	if _reserve.size() >= RESERVE_SIZE:
		queue_free()
		return
	visible = false
	set_physics_process(false)
	set_deferred("monitoring", false)
	if _particles != null:
		_particles.emitting = false
	_reserve.append(self)


## Cambia el modo de dibujo del cuerpo del charco: sprites (manchas animadas), partículas o shader.
func _set_style(style: int) -> void:
	_style = style
	material = FxShadersScript.acid_material() if style == STYLE_SHADERS else null
	if style == STYLE_PARTICLES:
		if _particles == null:
			_particles = _make_particles()
			add_child(_particles)
		_particles.emitting = true
	elif _particles != null:
		_particles.emitting = false


## Burbujas verdes que suben del charco (estilo partículas).
func _make_particles() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = _get_drop_texture()
	p.amount = maxi(3, roundi(8.0 * SettingsScript.particle_scale()))
	p.lifetime = 0.9
	p.local_coords = true
	p.position = Vector2(0.0, -3.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(BLOB_WIDTH * 0.42, 1.5)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.85, 1.0, 0.55, 0.95))
	ramp.set_color(1, Color(0.2, 0.55, 0.08, 0.0))
	p.color_ramp = ramp
	return p


func _clear_drops() -> void:
	if _drop_pos.is_empty():
		return
	_drop_pos.clear()
	_drop_vel.clear()
	_drop_size.clear()
	_drop_landed_t.clear()


## Un charco de la reserva que siga en el mismo padre, o null.
static func _take_reserved(host: Node) -> AcidPool:
	while not _reserve.is_empty():
		var candidate: Variant = _reserve.pop_back()
		if not is_instance_valid(candidate):
			continue
		var node: Node = candidate as Node
		if node.is_inside_tree() and node.get_parent() == host:
			return candidate as AcidPool
		node.queue_free()
	return null


## Reparte los charcos hermanos a los costados del raíz, cada uno apoyado en el piso que encuentre.
func _spawn_siblings() -> void:
	var count: int = cluster_count
	if _active.size() >= CLUSTER_BUDGET_POOLS:
		count = mini(count, CLUSTER_MIN_COUNT)
	var host: Node = get_parent()
	if count <= 1 or host == null:
		return
	var scene: PackedScene = null
	# Posiciones sucesivas a derecha e izquierda alternadas: el raíz queda en el medio.
	var offsets: Array[float] = []
	for k: int in range(1, count):
		var side: float = 1.0 if k % 2 == 1 else -1.0
		offsets.append(side * ceilf(float(k) * 0.5) * CLUSTER_STEP + randf_range(-CLUSTER_JITTER, CLUSTER_JITTER))
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for x_off: float in offsets:
		var from: Vector2 = global_position + Vector2(x_off, -CLUSTER_RAY_UP)
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				from, from + Vector2(0.0, CLUSTER_RAY_UP + CLUSTER_RAY_DOWN), 1)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var sibling: AcidPool = _take_reserved(host)
		var reused: bool = sibling != null
		if not reused:
			if scene == null:
				scene = load(POOL_SCENE_PATH) as PackedScene
				if scene == null:
					return
			sibling = scene.instantiate() as AcidPool
			if sibling == null:
				continue
		sibling.cluster_count = 1
		sibling._is_sibling = true
		sibling._cluster_id = _cluster_id
		sibling.source_node = source_node
		sibling.pool_width = pool_width
		sibling.pool_height = pool_height
		sibling.tick_damage = tick_damage
		sibling.tick_interval = tick_interval
		sibling.armor_penetration = armor_penetration
		sibling.pool_color = pool_color
		sibling.lifetime = lifetime * randf_range(CLUSTER_LIFETIME_MIN, CLUSTER_LIFETIME_MAX)
		sibling.splash_delay = absf(x_off) * BLOB_DELAY_PER_PX + randf_range(0.0, 0.03)
		sibling.global_position = hit["position"] as Vector2
		if reused:
			sibling._activate()
		else:
			host.add_child.call_deferred(sibling)


## Oculta el dibujo de los charcos viejos que este tapa casi por completo.
func _cover_older_pools() -> void:
	var half: float = BLOB_WIDTH * 0.5
	for entry: Variant in _active:
		if not is_instance_valid(entry):
			continue
		var other: AcidPool = entry as AcidPool
		if other == null or other == self or other._cluster_id == _cluster_id:
			continue
		if absf(other.global_position.y - global_position.y) > COVER_MAX_DY:
			continue
		# Se compara el ancho de la mancha dibujada, que es lo que se superpone a la vista.
		var left: float = maxf(global_position.x - half, other.global_position.x - half)
		var right: float = minf(global_position.x + half, other.global_position.x + half)
		if right - left >= BLOB_WIDTH * COVER_OVERLAP:
			other._covered_by = self
			other._covered_gen = _gen


## Una sola mancha centrada, con tamaño, alzada, espejado y animación propios (cada charco se ve distinto).
func _build_blobs() -> void:
	_blobs.clear()
	var width: float = BLOB_WIDTH * randf_range(0.88, 1.12)
	var raise: float = randf_range(1.0, BLOB_RAISE_MAX)
	_blobs.append(Vector4(0.0, width, raise, splash_delay))
	_splat_end = splash_delay + SPLAT_TIME
	_flip = -1.0 if randf() < 0.5 else 1.0
	_frame_offset = randi() % FRAME_COUNT


## Salpicadura inicial: gotas que salen disparadas hacia arriba y a los costados.
func _spawn_drops() -> void:
	var count: int = clampi(roundi(DROP_COUNT * pool_width / DROP_REF_WIDTH), 3, 60)
	var active_pools: int = _active.size()
	if active_pools > DROP_BUDGET_POOLS:
		count = maxi(DROP_MIN_COUNT, roundi(float(count) * float(DROP_BUDGET_POOLS) / float(active_pools)))
	if _covered_by != null or not ViewCullScript.near(self, VIEW_MARGIN):
		return
	for i: int in count:
		var spread: float = randf_range(-1.0, 1.0)
		_drop_pos.append(Vector2(spread * pool_width * 0.4, -2.0))
		_drop_vel.append(Vector2(spread * randf_range(40.0, 190.0) + randf_range(-30.0, 30.0), -randf_range(240.0, 520.0)))
		_drop_size.append(float(randi_range(3, 7)))
		_drop_landed_t.append(-1.0)


## Avanza las gotas; devuelve true mientras quede alguna en vuelo o desvaneciéndose.
func _update_drops(delta: float) -> bool:
	var n: int = _drop_pos.size()
	if n == 0:
		return false
	var active: bool = false
	for i: int in n:
		var t: float = _drop_landed_t[i]
		if t >= 0.0:
			_drop_landed_t[i] = t + delta
			if t + delta < DROP_SPLAT_TIME:
				active = true
			continue
		active = true
		var vel: Vector2 = _drop_vel[i]
		vel.y += DROP_GRAVITY * delta
		_drop_vel[i] = vel
		var pos: Vector2 = _drop_pos[i] + vel * delta
		if pos.y >= 0.0 and vel.y > 0.0:
			pos.y = 0.0
			_drop_landed_t[i] = 0.0
		_drop_pos[i] = pos
	if not active:
		_drop_pos.clear()
		_drop_vel.clear()
		_drop_size.clear()
		_drop_landed_t.clear()
	return active


## Gota de ácido horneada una sola vez: contorno oscuro, relleno verde y un brillo arriba a la izquierda.
static func _get_drop_texture() -> Texture2D:
	if _drop_tex_cache == null:
		var size: int = 24
		var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c: float = float(size) * 0.5
		var dark: Color = Color(0.1, 0.38, 0.05)
		var mid: Color = Color(0.38, 0.86, 0.12)
		var light: Color = Color(0.85, 1.0, 0.55)
		for y: int in size:
			for x: int in size:
				var px: float = float(x) + 0.5 - c
				var py: float = float(y) + 0.5 - c
				var d: float = sqrt(px * px + py * py)
				var col: Color = Color(0, 0, 0, 0)
				if d <= c:
					col = dark
					col.a = clampf(c - d + 0.5, 0.0, 1.0)
					if d <= c * 0.78:
						col = mid
						var hx: float = px + c * 0.23
						var hy: float = py + c * 0.23
						if sqrt(hx * hx + hy * hy) <= c * 0.27:
							col = light
				img.set_pixel(x, y, col)
		_drop_tex_cache = ImageTexture.create_from_image(img)
	return _drop_tex_cache


## 0 -> 1 con sobreimpulso: la mancha pasa de tamaño y se asienta.
func _splat_curve(t: float) -> float:
	return 1.0 - pow(1.0 - t, 2.0) * cos(t * PI * 1.5)


func _draw_drops(remaining: float) -> void:
	var mid: Color = Color(0.38, 0.86, 0.12, remaining)
	var drop_tex: Texture2D = _get_drop_texture()
	for i: int in _drop_pos.size():
		var pos: Vector2 = _drop_pos[i]
		var r: float = _drop_size[i] * 0.5 + 1.0
		var landed_t: float = _drop_landed_t[i]
		if landed_t >= 0.0:
			# Al tocar el piso la gota se aplasta en una mancha baja que se funde con el charco.
			var fade: float = 1.0 - landed_t / DROP_SPLAT_TIME
			if fade <= 0.0:
				continue
			draw_rect(Rect2(pos.x - r * 1.8, -1.6, r * 3.6, 1.8), Color(mid.r, mid.g, mid.b, remaining * fade))
			continue
		# Gota en vuelo: un solo cuadrito con la textura de la gota (contorno oscuro, relleno y brillo ya
		# horneados). Tres `draw_circle` por gota teselaban polígonos y eran lo más caro del charco.
		var outer: float = r + 1.2
		draw_texture_rect(drop_tex, Rect2(pos.x - outer, pos.y - outer, outer * 2.0, outer * 2.0), false,
				Color(1.0, 1.0, 1.0, remaining))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		_release()
		return
	
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_tick()
	
	# Fuera de la cámara no se animan gotas ni se redibuja (el daño sigue igual).
	var on_screen: bool = ViewCullScript.near(self, VIEW_MARGIN)
	var drops_active: bool = false
	if not on_screen:
		_clear_drops()
	elif _vis > 0.0 or _covered_by == null:
		drops_active = _update_drops(delta)
	else:
		_clear_drops()
	# Si el charco que lo tapaba ya no existe (o se reutilizó en otro lado), el dibujo vuelve.
	if _covered_by != null and (not is_instance_valid(_covered_by) or not _covered_by._in_use
			or _covered_by._gen != _covered_gen):
		_covered_by = null
	var prev_vis: float = _vis
	_vis = move_toward(_vis, 0.0 if _covered_by != null else 1.0, delta / COVER_FADE_TIME)
	if _particles != null and _style == STYLE_PARTICLES:
		_particles.emitting = on_screen
		_particles.modulate.a = clampf((lifetime - _age) / FADE_OUT_TIME, 0.0, 1.0) * _vis
	if (_vis <= 0.0 and prev_vis <= 0.0) or not on_screen:
		return
	var frame_idx: int = int(_age * FRAME_FPS)
	var moving: bool = drops_active or _age < _splat_end or _vis != prev_vis or lifetime - _age < FADE_OUT_TIME
	if moving or frame_idx != _last_frame_idx:
		_last_frame_idx = frame_idx
		queue_redraw()


func _apply_tick() -> void:
	if not monitoring:
		return
	var targets: Array[Node2D] = ThrowableUtil.collect_hostile_targets(self)
	for target in targets:
		if not is_instance_valid(target):
			continue
		var effects: Array[String] = ["ACID"]
		var payload: HitPayload = HitPayload.new(
			tick_damage,
			0.0,
			Vector2.ZERO,
			source_node,
			effects,
			1,
			0.0,
			armor_penetration
		)
		ThrowableUtil.deliver_hit(target, payload)


func _draw() -> void:
	if _vis <= 0.0:
		return
	var remaining: float = clampf((lifetime - _age) / FADE_OUT_TIME, 0.0, 1.0) * _vis
	var bubble_phase: float = _age * 4.0

	if _style == STYLE_SHADERS or _style == STYLE_PARTICLES:
		var delay: float = _blobs[0].w if not _blobs.is_empty() else 0.0
		if _age < delay:
			return
		var grow: float = 1.0
		if _age < delay + SPLAT_TIME:
			grow = _splat_curve(clampf((_age - delay) / SPLAT_TIME, 0.0, 1.0))
		if _style == STYLE_SHADERS:
			# Un solo cuadro con el shader del charco (la onda y las burbujas se animan en la GPU)
			var sw: float = SHADER_BLOB_W * lerpf(0.3, 1.0, grow)
			var sh: float = SHADER_BLOB_H * lerpf(0.35, 1.0, grow)
			draw_texture_rect(FxShadersScript.white_texture(), Rect2(-sw * 0.5, 2.0 - sh, sw, sh), false,
					Color(1, 1, 1, 0.95 * remaining))
		else:
			# Estilo partículas: base plana verde y las burbujas son el emisor hijo
			var bw: float = BLOB_WIDTH * 0.9 * lerpf(0.3, 1.0, grow)
			draw_rect(Rect2(-bw * 0.5, -3.0, bw, 5.0), Color(0.16, 0.5, 0.07, 0.9 * remaining))
			draw_rect(Rect2(-bw * 0.5, -4.0, bw, 1.5), Color(0.5, 0.92, 0.2, 0.9 * remaining))
		_draw_drops(remaining)
		return

	if _frames.size() == FRAME_COUNT:
		# Mancha vista de costado: el borde superior queda a ras del piso (el origen del charco es el
		# punto de apoyo) y los goteos cuelgan hacia abajo. Al aparecer se aplasta y rebota (splat).
		# Varias manchas chicas, semi superpuestas y apenas por encima del borde del piso, cada una
		# con su propio desfase de animación, retardo de aparición y espejado.
		for i: int in _blobs.size():
			var blob: Vector4 = _blobs[i]
			if _age < blob.w:
				continue
			var tex: Texture2D = _frames[(int(_age * FRAME_FPS) + _frame_offset + i) % FRAME_COUNT]
			var squash: float = 1.0
			if _age < blob.w + SPLAT_TIME:
				squash = _splat_curve(clampf((_age - blob.w) / SPLAT_TIME, 0.0, 1.0))
			var w: float = blob.y * lerpf(0.3, 1.0, squash)
			var h: float = w * float(tex.get_height()) / float(tex.get_width()) * SPRITE_VSQUASH * lerpf(0.35, 1.0, squash)
			var flip: float = _flip
			# Con ancho negativo Godot espeja la textura pero `position` sigue siendo el borde izquierdo.
			var rect: Rect2 = Rect2(Vector2(blob.x - w * 0.5, -1.0 - blob.z), Vector2(w * flip, h))
			draw_texture_rect(tex, rect, false, Color(1, 1, 1, 0.95 * remaining))
		_draw_drops(remaining)
		return
	
	var base: Color = pool_color
	base.a = 0.55 * remaining
	var half_w: float = pool_width * 0.5
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 24
	for i in range(steps):
		var ang: float = TAU * float(i) / float(steps)
		var wobble: float = 1.0 + 0.06 * sin(bubble_phase + ang * 3.0)
		points.append(Vector2(cos(ang) * half_w * wobble, sin(ang) * 9.0 * wobble - 4.0))
	draw_colored_polygon(points, base)
	
	var rim: Color = pool_color.lightened(0.35)
	rim.a = 0.85 * remaining
	draw_polyline(points + PackedVector2Array([points[0]]), rim, 1.5)
	
	# Burbujas animadas
	var bubble: Color = Color(0.85, 1.0, 0.5, 0.8 * remaining)
	for i in range(4):
		var bx: float = sin(bubble_phase * 0.7 + float(i) * 1.9) * half_w * 0.6
		var by: float = -4.0 - absf(sin(bubble_phase + float(i) * 1.3)) * 7.0
		draw_circle(Vector2(bx, by), 2.0, bubble)
