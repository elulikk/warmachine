extends Node2D
## Casquillos, vainas, cartuchos, cargadores y bidones que caen al recargar (solo efecto visual, sin recogida).
## Física mínima a mano: gravedad, rebote contra el piso (raycast a la capa 1) y desvanecido. Se dibuja por código.
## Sin class_name a propósito: se carga por `preload` desde `WeaponManager` (ver class-name-cache-gotcha).
##
## Qué cae lo decide la familia del arma (`WeaponData.get_reload_drop()`), no el nombre del arma:
##   CYLINDER  vainas gastadas del tambor (revólver)
##   MAGAZINE  cargador viejo y casquillos (pistolas, subfusiles, carabinas, fusiles)
##   SHELLS    cartuchos gastados (escopeta)
##   CANISTER  bidón o celda de energía (armas de energía y lanzallamas)

const SettingsScript = preload("res://core/settings.gd")

const GROUP: StringName = &"reload_debris"
## Tope de piezas vivas a la vez: al pasarse se liberan las más viejas.
const LIMIT: int = 36
## Con la densidad de partículas por debajo de esto (calidad baja) no se dibuja nada.
const MIN_DENSITY: float = 0.3
const FX_Z_INDEX: int = 12
const GRAVITY: float = 980.0
const MAX_BOUNCES: int = 2
const BOUNCE_DAMPING: float = 0.32
const FRICTION: float = 0.5
const REST_SECONDS: float = 1.6
const FADE_SECONDS: float = 0.7
const AIR_TIMEOUT: float = 1.6
## Piezas por tipo de caída (el resto se descarta; es solo visual).
const MAX_CASINGS: int = 6

const BRASS: Color = Color(0.86, 0.66, 0.26, 1.0)
const BRASS_DARK: Color = Color(0.55, 0.38, 0.12, 1.0)
const STEEL: Color = Color(0.27, 0.29, 0.33, 1.0)
const STEEL_LIGHT: Color = Color(0.62, 0.64, 0.68, 1.0)

var kind: String = "casing"
var tint: Color = Color(0.45, 0.95, 0.85, 1.0)
var velocity: Vector2 = Vector2.ZERO
var spin: float = 0.0

var _bounces: int = 0
var _resting: bool = false
var _air_time: float = 0.0


## Hace caer lo que corresponde a `drop` (un `WeaponData.ReloadDrop`) desde `pos`.
## `aim` es la dirección de apuntado (los casquillos salen hacia el costado contrario al de la boca);
## `count` son los disparos gastados del cargador. `energy_tint` tiñe el bidón.
static func spawn(host: Node, drop: int, pos: Vector2, aim: Vector2, count: int, energy_tint: Color = Color(0.45, 0.95, 0.85, 1.0)) -> void:
	if host == null or not host.is_inside_tree() or drop == WeaponData.ReloadDrop.NONE:
		return
	var density: float = SettingsScript.particle_scale()
	if density < MIN_DENSITY:
		return
	var tree: SceneTree = host.get_tree()
	var container: Node = tree.current_scene if tree.current_scene != null else tree.root
	if container == null:
		return
	var side: float = -signf(aim.x) if absf(aim.x) > 0.05 else -1.0
	var pieces: Array[Dictionary] = []
	var shots: int = clampi(count, 1, MAX_CASINGS)
	shots = maxi(1, roundi(float(shots) * density))
	match drop:
		WeaponData.ReloadDrop.CYLINDER: # las vainas caen casi derechas del tambor
			for i in range(shots):
				pieces.append({"kind": "casing", "v": Vector2(randf_range(-30.0, 30.0) + side * 12.0, randf_range(-40.0, 10.0))})
		WeaponData.ReloadDrop.MAGAZINE: # el cargador cae y los casquillos saltan para el costado
			pieces.append({"kind": "magazine", "v": Vector2(side * randf_range(8.0, 30.0), randf_range(20.0, 70.0))})
			for i in range(shots):
				pieces.append({"kind": "casing", "v": Vector2(side * randf_range(30.0, 90.0), randf_range(-150.0, -60.0))})
		WeaponData.ReloadDrop.SHELLS: # cartuchos gastados
			for i in range(shots):
				pieces.append({"kind": "shell", "v": Vector2(side * randf_range(20.0, 80.0) + randf_range(-15.0, 15.0), randf_range(-120.0, -30.0))})
		WeaponData.ReloadDrop.CANISTER: # el bidón viejo cae
			pieces.append({"kind": "canister", "v": Vector2(side * randf_range(8.0, 28.0), randf_range(10.0, 50.0))})
		_:
			return

	var existing: Array[Node] = tree.get_nodes_in_group(GROUP)
	for i in range(maxi(0, existing.size() + pieces.size() - LIMIT)):
		existing[i].queue_free()

	for piece: Dictionary in pieces:
		var debris: Node2D = (load("res://combat/reload_debris.gd") as GDScript).new() as Node2D
		debris.set("kind", piece["kind"])
		debris.set("tint", energy_tint)
		debris.set("velocity", piece["v"])
		debris.set("spin", randf_range(-16.0, 16.0))
		debris.z_index = FX_Z_INDEX
		debris.add_to_group(GROUP)
		container.add_child(debris)
		debris.global_position = pos + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 3.0))
		debris.rotation = randf() * TAU


func _draw() -> void:
	match kind:
		"casing":
			draw_rect(Rect2(-2.6, -1.3, 5.2, 2.6), BRASS)
			draw_rect(Rect2(1.4, -1.3, 1.2, 2.6), BRASS_DARK)
		"shell":
			draw_rect(Rect2(-4.6, -2.2, 9.2, 4.4), Color(0.78, 0.16, 0.12, 1.0))
			draw_rect(Rect2(1.8, -2.2, 2.8, 4.4), BRASS)
			draw_rect(Rect2(3.6, -2.2, 1.0, 4.4), BRASS_DARK)
		"magazine":
			draw_rect(Rect2(-3.2, -6.5, 6.4, 13.0), STEEL)
			draw_rect(Rect2(-3.2, -6.5, 6.4, 2.0), STEEL_LIGHT)
			draw_rect(Rect2(-1.6, -3.0, 3.2, 1.5), BRASS)
			draw_rect(Rect2(-1.6, 0.0, 3.2, 1.5), BRASS)
		"canister":
			draw_rect(Rect2(-4.0, -7.5, 8.0, 15.0), STEEL)
			draw_rect(Rect2(-4.0, -7.5, 8.0, 2.4), STEEL_LIGHT)
			draw_rect(Rect2(-4.0, 5.0, 8.0, 2.5), STEEL_LIGHT)
			draw_rect(Rect2(-2.6, -3.4, 5.2, 6.6), tint)


func _physics_process(delta: float) -> void:
	if _resting:
		return
	_air_time += delta
	if _air_time > AIR_TIMEOUT:
		_rest(false)
		return

	velocity.y += GRAVITY * delta
	var step: Vector2 = velocity * delta
	if velocity.y > 0.0:
		var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + step + Vector2(0.0, 3.0), 1)
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			global_position = (hit["position"] as Vector2) + Vector2(0.0, -1.5)
			_land()
			return
	global_position += step
	rotation += spin * delta


func _land() -> void:
	_bounces += 1
	if _bounces > MAX_BOUNCES or absf(velocity.y) < 70.0:
		_rest(true)
		return
	velocity.y = -velocity.y * BOUNCE_DAMPING
	velocity.x *= FRICTION
	spin *= 0.5


## Se queda quieto en el piso (o donde esté) y se desvanece pasado un rato.
func _rest(on_floor: bool) -> void:
	_resting = true
	velocity = Vector2.ZERO
	if on_floor:
		rotation = roundf(rotation / PI) * PI
	var fade: Tween = create_tween()
	fade.tween_interval(REST_SECONDS if on_floor else 0.1)
	fade.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	fade.tween_callback(queue_free)
