extends RefCounted
## Salto automático de los enemigos terrestres sobre los obstáculos del escenario (cajas, contenedores,
## paredones). Solo sortea cuerpos del grupo `hop_obstacle` (los de `world_prop.gd` y la decoración sólida).
## Sin class_name: se carga por `preload` desde cada enemigo.

## Velocidad de salto: con gravedad 980 el pico queda ~150 px sobre los pies (los obstáculos llegan a ~125).
const HOP_SPEED: float = 540.0
const GROUP: StringName = &"hop_obstacle"


## Llamar justo antes de `move_and_slide()`. `dir` es el sentido en que el enemigo quiere avanzar (-1, 0, 1).
static func try_hop(body: CharacterBody2D, dir: float) -> void:
	if dir == 0.0 or not body.is_on_floor() or not body.is_on_wall():
		return
	for i: int in body.get_slide_collision_count():
		var hit: KinematicCollision2D = body.get_slide_collision(i)
		var other: Object = hit.get_collider()
		if other is Node and (other as Node).is_in_group(GROUP) and hit.get_normal().x * dir < -0.5:
			body.velocity.y = -HOP_SPEED
			return
