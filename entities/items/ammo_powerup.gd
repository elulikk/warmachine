extends Area2D
## Powerup de munición: al tocarlo rellena el cargador y la reserva de TODAS las armas del jugador
## (la equipada y las que cambie después, aunque sea a otra). Se dibuja por código (arte pendiente).
## Sin class_name a propósito: lo instancia levels/level_base.gd por preload.

const PickupAuraScript = preload("res://entities/items/pickup_aura.gd")

var _time: float = 0.0
var _collected: bool = false
var _visuals: Node2D = null


func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	add_child(shape)
	_visuals = Node2D.new()
	add_child(_visuals)
	var aura: Node2D = PickupAuraScript.new()
	aura.color = Color(1.0, 0.8, 0.2, 1.0)
	_visuals.add_child(aura)
	# Tres balas doradas
	for i in range(3):
		var bullet: ColorRect = ColorRect.new()
		bullet.color = Color(1.0, 0.82, 0.25, 1.0)
		bullet.size = Vector2(7.0, 20.0)
		bullet.position = Vector2(-13.0 + float(i) * 10.0, -10.0)
		_visuals.add_child(bullet)
	var label: Label = Label.new()
	label.text = "MUNICIÓN"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-30.0, -36.0)
	_visuals.add_child(label)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta * 3.5
	_visuals.position.y = sin(_time) * 4.0


func _on_body_entered(body: Node2D) -> void:
	if _collected or not (body is Player):
		return
	var player: Player = body as Player
	if player.weapon_manager == null:
		return
	_collected = true
	player.weapon_manager.refill_all_ammo()
	GameFeel.sfx(self, &"exp", Vector2.INF, -4.0, 1.4)
	queue_free()
