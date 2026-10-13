extends Node
## Evento de los Agentes del Tiempo: un helicóptero negro cruza con el reflector, se detiene y bajan 2 o 3 Agentes
## (o, en interiores, aparecen con un destello). Lo crea LevelBase si el nivel tiene `agent_event_chance` > 0
## y `agent_events_enabled`. Sin class_name: se carga por `preload`.
##
## El evento guionado del P-5 no usa este nodo (es una cinemática, ver core/cinematics/cinematic_library.gd).

const CinemaScript = preload("res://core/cinematics/cinematic_player.gd")
const AGENT_SCENE: String = "res://entities/enemies/time_agent.tscn"
const HELI_TEXTURE: String = "res://assets/art/world4/helicopter.png"

var style: String = "helicopter"
var delay_min: float = 25.0
var delay_max: float = 70.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var timer: SceneTreeTimer = get_tree().create_timer(randf_range(delay_min, delay_max))
	timer.timeout.connect(_start)


func _start() -> void:
	if not is_inside_tree():
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	var level: Node = get_tree().current_scene
	if player == null or level == null or CinemaScript.active:
		return
	# Cae por delante del jugador (donde va), sin salirse del nivel
	var limit_right: float = 99999.0
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		limit_right = float(camera.limit_right)
	var x: float = clampf(player.global_position.x + 360.0, 200.0, limit_right - 300.0)
	var ground: float = player.global_position.y
	print("[AgentEvent] Los Agentes del Tiempo llegan (%s) a x=%d." % [style, int(x)])
	if style == "helicopter":
		_fly_in(level, Vector2(x, ground))
	else:
		_portal_in(level, Vector2(x, ground))


func _fly_in(level: Node, spot: Vector2) -> void:
	var tex: Texture2D = load(HELI_TEXTURE) as Texture2D
	if tex == null:
		_drop_agents(level, spot)
		return
	var heli: Sprite2D = Sprite2D.new()
	heli.texture = tex
	var s: float = 150.0 / float(tex.get_height())
	heli.scale = Vector2(-s, s)
	heli.z_index = 8
	heli.global_position = spot + Vector2(-900.0, -330.0)
	level.add_child(heli)
	var tw: Tween = heli.create_tween()
	tw.tween_property(heli, "global_position", spot + Vector2(0.0, -250.0), 2.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_drop_agents.bind(level, spot))
	tw.tween_interval(1.2)
	tw.tween_property(heli, "global_position", spot + Vector2(1500.0, -420.0), 2.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(heli.queue_free)


func _portal_in(level: Node, spot: Vector2) -> void:
	_drop_agents(level, spot)


func _drop_agents(level: Node, spot: Vector2) -> void:
	var scene: PackedScene = load(AGENT_SCENE) as PackedScene
	if scene == null or not is_instance_valid(level):
		return
	var count: int = randi_range(2, 3)
	for i in range(count):
		var agent: Node2D = scene.instantiate() as Node2D
		agent.global_position = spot + Vector2(float(i - 1) * 70.0, -6.0)
		level.add_child(agent)
