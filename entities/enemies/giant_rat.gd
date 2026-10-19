extends "res://entities/enemies/basic_runner.gd"
## Rata Gigante: jefe de las alcantarillas (1-03). Por ahora solo una rata enorme con mucha vida que persigue sin parar;
## al morir deja la Flauta de Hamelin (`dropped_item`, ver la escena). Las mecánicas propias se suman después.
## Va al grupo `boss` (música de jefe). Sin class_name a propósito: se carga por escena.

const BOSS_HEALTH: float = 1100.0
const BOSS_SPEED: float = 100.0
const BOSS_CONTACT_DAMAGE: float = 18.0
## Escala extra del arte sobre el 1.5x común de los mobs (la rata común mide ~45 px; esta ~135).
const ART_EXTRA_SCALE: float = 3.0
## Colisión del cuerpo y de la hurtbox (px, con los pies en el origen).
const BODY_SIZE: Vector2 = Vector2(120.0, 80.0)
const HURTBOX_SIZE: Vector2 = Vector2(150.0, 120.0)


func _ready() -> void:
	super._ready()
	entity_name = "Rata Gigante"
	move_speed = BOSS_SPEED
	contact_damage = BOSS_CONTACT_DAMAGE
	aggro_range = 4000.0
	add_to_group(&"boss")
	if health_component != null:
		health_component.max_health = BOSS_HEALTH
		health_component.current_health = BOSS_HEALTH
	var art: Node2D = get_node_or_null("Visuals/EnemyArt") as Node2D
	if art != null:
		art.scale *= ART_EXTRA_SCALE
	_resize("CollisionShape2D", BODY_SIZE)
	_resize("Hurtbox/CollisionShape2D", HURTBOX_SIZE)
	if overhead_bar != null:
		overhead_bar.set("vertical_offset_y", -150.0)
		if overhead_bar.has_method("setup") and health_component != null:
			overhead_bar.call("setup", health_component, EnemyLevelScript.display_name(self))
	var display: Node2D = get_node_or_null("StatusDisplayComponent") as Node2D
	if display != null:
		display.position.y = -130.0
	GameFeel.sfx(self, &"rat_screech", global_position, 0.0, 0.8)


## Pone el rectángulo de colisión en `size` apoyado en los pies (la forma ya es propia: la duplicó MobScale).
func _resize(path: String, size: Vector2) -> void:
	var node: CollisionShape2D = get_node_or_null(path) as CollisionShape2D
	if node == null:
		return
	var rect: RectangleShape2D = (node.shape.duplicate() as RectangleShape2D) if node.shape is RectangleShape2D else RectangleShape2D.new()
	rect.size = size
	node.shape = rect
	node.position = Vector2(0.0, -size.y * 0.5)
