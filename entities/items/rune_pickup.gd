class_name RunePickup
extends Area2D
## Objeto recolectable de runa en el escenario.
## Al entrar en contacto con el Jugador, intenta engarzarse en el primer socket disponible
## del arma actualmente equipada en WeaponManager.

@export var rune_data: RuneData

@onready var visuals: Node2D = $Visuals
@onready var color_rect: ColorRect = $Visuals/ColorRect
@onready var inner_rect: ColorRect = $Visuals/InnerRect
@onready var name_label: Label = get_node_or_null("Visuals/NameLabel") as Label

var _time_accumulator: float = 0.0
var _collected: bool = false
var pickup_cooldown: float = 0.4


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visuals()


func _apply_visuals() -> void:
	if rune_data == null:
		return
	if color_rect != null:
		color_rect.color = rune_data.rune_color
	if name_label != null:
		name_label.text = rune_data.rune_name


func _process(delta: float) -> void:
	if pickup_cooldown > 0.0:
		pickup_cooldown = maxf(0.0, pickup_cooldown - delta)
		if pickup_cooldown <= 0.0:
			for body in get_overlapping_bodies():
				if body is Player:
					_on_body_entered(body)
					break

	# Flotación vertical oscilatoria (bobbing)
	_time_accumulator += delta * 4.0
	if visuals != null:
		visuals.position.y = sin(_time_accumulator) * 4.0


func _on_body_entered(body: Node2D) -> void:
	if _collected or pickup_cooldown > 0.0 or rune_data == null:
		return
	
	if body is Player:
		var player: Player = body as Player
		# Las runas recolectadas van exclusivamente a la mochila para ser engarzadas por el Herrero
		var inv_mgr: InventoryManager = player.get_node_or_null("InventoryManager") as InventoryManager
		if inv_mgr != null:
			if inv_mgr.add_item(rune_data):
				_collected = true
				print("[RunePickup] Runa '%s' almacenada en la mochila. Puedes engarzarla con el Herrero." % rune_data.rune_name)
			else:
				print("[RunePickup] Mochila llena. Libera espacio para recoger '%s'." % rune_data.rune_name)
		
		if _collected:
			GameFeel.sfx(self, &"pickup_gear", Vector2.INF, -3.0)
			# Animación breve de recolección
			var tw: Tween = create_tween()
			tw.set_parallel(true)
			tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "modulate:a", 0.0, 0.15)
			tw.finished.connect(queue_free)
