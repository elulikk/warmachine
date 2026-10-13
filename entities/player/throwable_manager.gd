class_name ThrowableManager
extends Node
## Gestor del arrojadizo táctico del Jugador. Mantiene el ítem de la ranura TACTICAL activo,
## administra el cooldown entre lanzamientos y calcula la parábola balística hacia el cursor
## (o hacia el stick derecho del gamepad). La acción `throw_tactical` ([G], clic central o L2)
## funciona como apuntado: al mantenerla se muestra la trayectoria y el alcance crece hasta
## `max_throw_range` según `full_charge_time`; al soltarla se lanza el proyectil.

signal throwable_thrown(item: ItemData)
signal cooldown_changed(remaining: float, total: float)
signal equipped_throwable_changed(item: ItemData)

## Ítem arrojadizo activo (se sincroniza automáticamente con la ranura TACTICAL del EquipmentManager).
@export var equipped_throwable: ItemData = null

## Tiempo de recarga entre lanzamientos en segundos.
@export var throw_cooldown: float = 4.0

@export_group("Balística")
@export var max_throw_range: float = 460.0
@export var min_throw_range: float = 90.0
@export var min_flight_time: float = 0.35
@export var max_flight_time: float = 0.9
@export var flight_reference_speed: float = 520.0
@export var stick_throw_distance: float = 320.0
@export var stick_deadzone: float = 0.25
## Segundos que hay que mantener la tecla para alcanzar el alcance máximo.
@export var full_charge_time: float = 0.9

## Paso de la simulación de la trayectoria mostrada y tiempo máximo buscando el suelo.
const PREVIEW_STEP: float = 0.03
const PREVIEW_MAX_TIME: float = 2.5
## Capa de física del terreno (la misma que usa ThrowableBase para ubicar el suelo).
const TERRAIN_MASK: int = 1

var player: Player = null
var equipment_manager: EquipmentManager = null
var cooldown_left: float = 0.0
## true mientras el jugador mantiene la acción de apuntar.
var is_aiming: bool = false
## Carga del apuntado: 0.0 = alcance mínimo, 1.0 = alcance máximo.
var aim_charge: float = 0.0

var _preview: TrajectoryPreview = null


## Dibujo de la trayectoria. Se ubica en coordenadas globales (top_level) para no depender del jugador.
class TrajectoryPreview extends Node2D:
	var points: PackedVector2Array = PackedVector2Array()
	var landing: Vector2 = Vector2.ZERO
	var color: Color = Color.WHITE

	func _draw() -> void:
		if points.size() < 2:
			return
		draw_polyline(points, color, 2.0, true)
		# Sin suelo a la vista (INF) no hay marca de caída
		if landing.is_finite():
			draw_circle(landing, 5.0, color)


func _ready() -> void:
	player = owner as Player
	if player == null and get_parent() is Player:
		player = get_parent() as Player

	equipment_manager = get_node_or_null("../EquipmentManager") as EquipmentManager
	if equipment_manager != null:
		if not equipment_manager.item_equipped.is_connected(_on_item_equipped):
			equipment_manager.item_equipped.connect(_on_item_equipped)
		if not equipment_manager.item_unequipped.is_connected(_on_item_unequipped):
			equipment_manager.item_unequipped.connect(_on_item_unequipped)
		var current: ItemData = equipment_manager.get_equipped_item(EquipmentManager.SLOT_TACTICAL)
		if current != null:
			equipped_throwable = current

	_preview = TrajectoryPreview.new()
	_preview.top_level = true
	_preview.z_index = 50
	_preview.visible = false
	add_child(_preview)


func _process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)
		cooldown_changed.emit(cooldown_left, throw_cooldown)
	if is_aiming:
		_update_aim(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("throw_tactical"):
		begin_aim()
	elif event.is_action_released("throw_tactical"):
		release_aim()
	elif event.is_action_pressed("use_tool"):
		# El clic derecho es de la mano secundaria mientras tenga un arma lista (la herramienta sigue en F y L1)
		if event.is_action("attack_secondary") and _offhand_ready():
			return
		try_throw()


## true si el jugador tiene un arma lista en la mano secundaria (no bloqueada por un arma a dos manos).
func _offhand_ready() -> bool:
	if player == null or player.weapon_manager == null:
		return false
	var off: WeaponManager = player.weapon_manager.offhand
	return off != null and off.current_weapon != null


func _on_item_equipped(slot: String, item: ItemData) -> void:
	if slot == EquipmentManager.SLOT_TACTICAL:
		equipped_throwable = item
		equipped_throwable_changed.emit(item)
	elif EquipmentManager.ACCESSORY_SLOTS.has(slot) and item != null and item.throwable_scene != null:
		if equipped_throwable == null or equipped_throwable.equip_slot != EquipmentManager.SLOT_TACTICAL:
			equipped_throwable = item
			equipped_throwable_changed.emit(item)


func _on_item_unequipped(slot: String, item: ItemData) -> void:
	if slot == EquipmentManager.SLOT_TACTICAL:
		equipped_throwable = null
		var acc: ItemData = _find_accessory_throwable()
		if acc != null:
			equipped_throwable = acc
		equipped_throwable_changed.emit(equipped_throwable)
	elif EquipmentManager.ACCESSORY_SLOTS.has(slot):
		if equipped_throwable == item:
			equipped_throwable = null
			if equipment_manager != null:
				var tac: ItemData = equipment_manager.get_equipped_item(EquipmentManager.SLOT_TACTICAL)
				if tac != null:
					equipped_throwable = tac
			equipped_throwable_changed.emit(equipped_throwable)


## Primer accesorio equipado (en cualquiera de las dos ranuras) que sea arrojadizo.
func _find_accessory_throwable() -> ItemData:
	if equipment_manager == null:
		return null
	for acc_slot in EquipmentManager.ACCESSORY_SLOTS:
		var acc: ItemData = equipment_manager.get_equipped_item(acc_slot)
		if acc != null and acc.throwable_scene != null:
			return acc
	return null


## Fracción de recarga restante (1.0 = recién lanzado, 0.0 = listo).
func get_cooldown_ratio() -> float:
	if throw_cooldown <= 0.0:
		return 0.0
	return clampf(cooldown_left / throw_cooldown, 0.0, 1.0)


## Intenta lanzar el arrojadizo equipado hacia el objetivo actual (cursor o stick). Devuelve true si se lanzó.
func try_throw() -> bool:
	if not _can_throw():
		return false
	var origin: Vector2 = _get_throw_origin()
	return _spawn(origin, _get_target_position(origin))


## Empieza el apuntado (al mantener [G] / clic central / L2). El gancho y el boomerang se lanzan al instante, sin apuntado.
func begin_aim() -> void:
	if not _can_throw():
		return
	if equipped_throwable.item_id == "grappling_hook" or _is_straight_throw():
		try_throw()
		return
	is_aiming = true
	aim_charge = 0.0


## Suelta el apuntado y lanza con el alcance cargado hasta el momento.
func release_aim() -> void:
	if not is_aiming:
		return
	# Se lee la carga antes de cancelar el apuntado, que la reinicia
	var charge: float = aim_charge
	cancel_aim()
	if not _can_throw():
		return
	var origin: Vector2 = _get_throw_origin()
	var direction: Vector2 = (_get_target_position(origin) - origin).normalized()
	var reach: float = lerpf(min_throw_range, max_throw_range, charge)
	_spawn(origin, origin + direction * reach)


## Cancela el apuntado sin lanzar y oculta la trayectoria.
func cancel_aim() -> void:
	is_aiming = false
	aim_charge = 0.0
	if _preview != null:
		_preview.visible = false


func _can_throw() -> bool:
	if player == null or not player.is_inside_tree():
		return false
	if equipped_throwable == null or equipped_throwable.throwable_scene == null:
		return false
	return cooldown_left <= 0.0


## Avanza la carga y redibuja la trayectoria hacia la dirección actual.
func _update_aim(delta: float) -> void:
	if not _can_throw():
		cancel_aim()
		return
	aim_charge = minf(1.0, aim_charge + delta / maxf(full_charge_time, 0.01))

	var origin: Vector2 = _get_throw_origin()
	var direction: Vector2 = (_get_target_position(origin) - origin).normalized()
	var reach: float = lerpf(min_throw_range, max_throw_range, aim_charge)
	var aim_point: Vector2 = origin + direction * reach
	var velocity: Vector2 = _compute_ballistic_velocity(origin, aim_point)
	_show_trajectory(origin, velocity)


## Dibuja la parábola real del proyectil hasta el primer impacto contra el terreno.
func _show_trajectory(origin: Vector2, velocity: Vector2) -> void:
	var gravity_vec: Vector2 = _gravity_vec()
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var points: PackedVector2Array = PackedVector2Array([origin])
	var landing: Vector2 = Vector2.INF
	var previous: Vector2 = origin
	var t: float = 0.0
	while t < PREVIEW_MAX_TIME:
		t += PREVIEW_STEP
		var current: Vector2 = origin + velocity * t + 0.5 * gravity_vec * t * t
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(previous, current, TERRAIN_MASK)
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty():
			landing = hit["position"] as Vector2
			points.append(landing)
			break
		points.append(current)
		previous = current

	_preview.points = points
	_preview.landing = landing
	_preview.color = Color(1.0, 1.0, 1.0, 0.85).lerp(Color(1.0, 0.45, 0.2, 0.95), aim_charge)
	_preview.visible = true
	_preview.queue_redraw()


## Instancia el proyectil, lo lanza desde `origin` hacia `target` y arranca la recarga.
func _spawn(origin: Vector2, target: Vector2) -> bool:
	var host: Node = get_tree().current_scene
	if host == null:
		host = player.get_parent()
	if host == null:
		return false

	var instance: Node = equipped_throwable.throwable_scene.instantiate()
	if instance == null:
		push_warning("[ThrowableManager] No se pudo instanciar la escena de '%s'." % equipped_throwable.item_name)
		return false

	var velocity: Vector2 = _launch_velocity(origin, target)

	host.add_child(instance)
	if instance.has_method("launch"):
		if instance is GrapplingHook:
			var aim_dir: Vector2 = (target - origin).normalized()
			instance.call("launch", origin, aim_dir, player)
		else:
			instance.call("launch", origin, velocity, player)

	var current_cooldown: float = throw_cooldown
	if equipped_throwable.item_id == "teleport_beacon":
		current_cooldown = 1.5
	elif equipped_throwable.item_id == "grappling_hook":
		current_cooldown = 1.2
	elif equipped_throwable.item_id == "acid_grenade":
		# Sin recarga: se puede tirar una tras otra.
		current_cooldown = 0.0

	cooldown_left = current_cooldown
	cooldown_changed.emit(cooldown_left, current_cooldown)
	throwable_thrown.emit(equipped_throwable)
	GameFeel.sfx(self, &"throw", Vector2.INF, -4.0)
	print("[ThrowableManager] Usado/Lanzado: %s (recarga %.1fs)" % [equipped_throwable.item_name, current_cooldown])
	return true


func _get_throw_origin() -> Vector2:
	if player.weapon_pivot != null:
		return player.weapon_pivot.global_position + player.weapon_pivot.get_aim_direction() * 14.0
	return player.global_position + Vector2(0.0, -32.0)


## Posición objetivo: stick derecho si está deflectado, de lo contrario el cursor del ratón.
func _get_target_position(origin: Vector2) -> Vector2:
	var stick: Vector2 = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() > stick_deadzone:
		return origin + stick.normalized() * stick_throw_distance

	var mouse_target: Vector2 = player.get_global_mouse_position()
	if mouse_target.distance_squared_to(origin) < 16.0:
		var fallback_dir: Vector2 = Vector2(float(player.facing_direction), 0.0)
		if player.weapon_pivot != null:
			fallback_dir = player.weapon_pivot.get_aim_direction()
		return origin + fallback_dir * min_throw_range
	return mouse_target


## true si el arrojadizo equipado sale en línea recta hacia el cursor, como un disparo (boomerang).
func _is_straight_throw() -> bool:
	return equipped_throwable != null and equipped_throwable.item_id == "boomerang"


## Velocidad con la que se lanza el proyectil. Los de línea recta solo usan la dirección hacia `target`;
## el resto sigue la parábola balística.
func _launch_velocity(origin: Vector2, target: Vector2) -> Vector2:
	if _is_straight_throw():
		return (target - origin).normalized()
	return _compute_ballistic_velocity(origin, target)


## Calcula la velocidad inicial que describe una parábola desde `origin` hasta `target`.
## Resuelve v = (d - 0.5 * g * t^2) / t con un tiempo de vuelo proporcional a la distancia.
func _compute_ballistic_velocity(origin: Vector2, target: Vector2) -> Vector2:
	var offset: Vector2 = target - origin
	var distance: float = offset.length()
	if distance > max_throw_range:
		offset = offset.normalized() * max_throw_range
		distance = max_throw_range
	elif distance < min_throw_range and distance > 0.001:
		offset = offset.normalized() * min_throw_range
		distance = min_throw_range

	var flight_time: float = _flight_time_for(distance)
	var gravity_vec: Vector2 = _gravity_vec()
	return (offset - 0.5 * gravity_vec * flight_time * flight_time) / flight_time


func _flight_time_for(distance: float) -> float:
	return clampf(distance / flight_reference_speed, min_flight_time, max_flight_time)


func _gravity_vec() -> Vector2:
	return Vector2(0.0, float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)))
