extends RefCounted
## Física de enemigos lejanos a baja frecuencia: fuera de la pantalla (más un colchón grande) el enemigo corre su
## `_physics_process` una de cada `EVERY` veces, con el tiempo acumulado. Nadie lo ve y el contacto con el jugador
## es imposible a esa distancia, así que solo se ahorra el `move_and_slide` y la IA de los cuadros intermedios.
## Sin class_name a propósito: se usa por `preload`.
##
## Uso al comienzo de `_physics_process(delta)`:
##     delta = FarStepScript.delta_for(self, delta)
##     if delta <= 0.0:
##         return

const ViewCullScript = preload("res://core/view_cull.gd")
## Colchón (px) alrededor de la cámara dentro del cual el enemigo corre a frecuencia completa.
const NEAR_MARGIN: float = 700.0
const EVERY: int = 4
const META_KEY: StringName = &"far_step_acc"


## Devuelve el delta a usar este cuadro: el mismo si está cerca, 0 si toca saltarse el cuadro, o lo acumulado.
static func delta_for(body: Node2D, delta: float) -> float:
	if ViewCullScript.near(body, NEAR_MARGIN):
		return delta
	var acc: float = float(body.get_meta(META_KEY, 0.0)) + delta
	if (Engine.get_physics_frames() + body.get_instance_id()) % EVERY != 0:
		body.set_meta(META_KEY, acc)
		return 0.0
	body.set_meta(META_KEY, 0.0)
	return acc
