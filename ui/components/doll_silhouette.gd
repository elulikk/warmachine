extends Control
## Muñeco de la hoja de equipamiento (paper doll): el mismo esqueleto del jugador, con su equipo puesto,
## que respira en reposo. Los casilleros se posicionan encima como hijos.
## Se llama "silhouette" por historia: antes dibujaba una silueta plana por código.

const RigScript = preload("res://entities/player/character_rig.gd")

## Cuántas veces se amplía el esqueleto (mide ~80 px en el juego).
const RIG_SCALE: float = 2.7

var _rig: Node2D = null
var _bound: bool = false


func _ready() -> void:
	clip_contents = false
	_rig = RigScript.new()
	_rig.name = "DollRig"
	_rig.set("preview_mode", true)
	_rig.scale = Vector2(RIG_SCALE, RIG_SCALE)
	add_child(_rig)
	move_child(_rig, 0)
	resized.connect(_place_rig)
	_place_rig()


func _place_rig() -> void:
	if _rig != null:
		_rig.position = Vector2(size.x * 0.5, size.y - 8.0)


func _process(_delta: float) -> void:
	if _bound or _rig == null:
		return
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		_rig.call("bind_player", player)
		_bound = true


func _draw() -> void:
	# Sombra de apoyo bajo los pies
	var center: Vector2 = Vector2(size.x * 0.5, size.y - 6.0)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 62.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(Vector2.ZERO, 46.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
