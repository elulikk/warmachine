extends ThrowableBase
## Bomba racimo: al cumplirse el fusible estalla chico y suelta `bomblet_count` bombitas que saltan en abanico
## y estallan solas un instante después (o al tocar a un enemigo).

@export var bomblet_scene: PackedScene
@export var bomblet_count: int = 6
@export var bomblet_speed_x: float = 260.0
@export var bomblet_speed_y: Vector2 = Vector2(260.0, 440.0)
@export var bomblet_fuse: Vector2 = Vector2(0.55, 1.05)


func _spawn_effect(spawn_pos: Vector2) -> void:
	super._spawn_effect(spawn_pos)
	if bomblet_scene == null:
		return
	var host: Node = get_tree().current_scene if get_tree() != null else null
	if host == null:
		host = get_parent()
	if host == null:
		return
	for i in range(bomblet_count):
		var bomblet: ThrowableBase = bomblet_scene.instantiate() as ThrowableBase
		if bomblet == null:
			continue
		# Repartidas a lo ancho, con un poco de azar para que no caigan en fila
		var spread: float = lerpf(-1.0, 1.0, float(i) / float(maxi(1, bomblet_count - 1)))
		var vel: Vector2 = Vector2(
			spread * bomblet_speed_x + randf_range(-40.0, 40.0),
			-randf_range(bomblet_speed_y.x, bomblet_speed_y.y)
		)
		bomblet.fuse_time = randf_range(bomblet_fuse.x, bomblet_fuse.y)
		bomblet.launch(spawn_pos + Vector2(0.0, -6.0), vel, thrower)
		host.add_child.call_deferred(bomblet)
