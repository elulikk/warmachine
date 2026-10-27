extends Projectile
## Bocanada de CO2 del Matafuegos: se frena, crece y se desvanece en su corta vida. Congela (ICE del arma)
## y empuja; no hace ruido al chocar con paredes (el chorro ya suena).

const DRAG: float = 2.4
const START_SCALE: float = 0.8
const END_SCALE: float = 2.8


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var t: float = clampf(current_lifetime / maxf(0.01, max_lifetime), 0.0, 1.0)
	speed = maxf(70.0, speed * (1.0 - DRAG * delta))
	# Se escala el dibujo y la forma, no el nodo: el avance usa transform.x y crecería la velocidad
	var grow: Vector2 = Vector2.ONE * lerpf(START_SCALE, END_SCALE, t)
	var sprite: Node2D = get_node_or_null("Sprite2D") as Node2D
	if sprite != null:
		sprite.scale = grow
		sprite.modulate.a = 1.0 - t * t
	var shape: Node2D = get_node_or_null("CollisionShape2D") as Node2D
	if shape != null:
		shape.scale = grow
