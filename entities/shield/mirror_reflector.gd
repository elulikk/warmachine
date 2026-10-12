extends Area2D
## Reflector del escudo espejo (Fase Z). Lo agrega Player en `_ready`.
## Con un escudo `reflects_projectiles` en la mano secundaria y levantado (clic derecho mantenido),
## los proyectiles ajenos que entran en esta zona rebotan hacia donde apunta el jugador con la mitad
## del daño (`Projectile.reflect`) y pasan a ser del jugador, así que no lo lastiman y sí dañan enemigos.
## Sin class_name a propósito: se carga por preload (ver class-name-cache-gotcha).

## Centro de la zona respecto del jugador (a la altura del pecho) y cuánto se adelanta hacia donde apunta.
const CENTER: Vector2 = Vector2(0.0, -32.0)
const REACH: float = 26.0
const RADIUS: float = 30.0
## Capa de los proyectiles (ver Projectile.reset_state).
const PROJECTILE_LAYER_MASK: int = 4

var _player: Player = null
var _shape: CollisionShape2D = null


func _ready() -> void:
	_player = get_parent() as Player
	collision_layer = 0
	collision_mask = PROJECTILE_LAYER_MASK
	monitorable = false
	_shape = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = RADIUS
	_shape.shape = circle
	add_child(_shape)
	_shape.disabled = true
	area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	var active: bool = _is_mirror_raised()
	_shape.disabled = not active
	if not active:
		return
	position = CENTER + _aim_direction() * REACH


## true si el jugador tiene el espejo en la mano secundaria y levantado.
func _is_mirror_raised() -> bool:
	if _player == null or _player.weapon_manager == null:
		return false
	var off: WeaponManager = _player.weapon_manager.offhand
	if off == null or off.current_weapon == null or not off.current_weapon.reflects_projectiles:
		return false
	return off.is_shield_raised()


func _aim_direction() -> Vector2:
	if _player.weapon_pivot != null:
		return _player.weapon_pivot.get_aim_direction()
	return Vector2(float(_player.facing_direction), 0.0)


func _on_area_entered(area: Area2D) -> void:
	var proj: Projectile = area as Projectile
	if proj == null or proj.payload == null or not _is_mirror_raised():
		return
	var src: Node = proj.payload.source_node
	# Solo lo ajeno: lo que disparó el jugador o sus aliados pasa de largo
	if src != null and (src == _player or src.is_in_group(&"player") or src.is_in_group(&"allies")):
		return
	var dir: Vector2 = _aim_direction()
	GameFeel.sfx(self, &"parry", global_position, -4.0, 1.25)
	proj.reflect(dir, _player)
