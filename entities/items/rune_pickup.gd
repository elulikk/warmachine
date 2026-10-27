class_name RunePickup
extends Area2D
## Objeto recolectable de runa en el escenario.
## Al entrar en contacto con el Jugador, intenta engarzarse en el primer socket disponible
## del arma actualmente equipada en WeaponManager.

const ItemIconsScript = preload("res://ui/components/item_icons.gd")
const PickupAuraScript = preload("res://entities/items/pickup_aura.gd")

## Lado mayor del sprite de la runa en el suelo (px)
const ICON_SIZE: float = 24.0

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
	# Aura que pulsa detrás de la runa, del color de su rareza
	if visuals != null:
		var aura: Node2D = PickupAuraScript.new()
		aura.color = ItemTooltip.RARITY_COLORS.get(int(rune_data.rarity), Color.WHITE) as Color
		visuals.add_child(aura)
		visuals.move_child(aura, 0)
	if name_label != null:
		name_label.text = rune_data.rune_name

	# Sprite de arte de la runa (brillante); si no existe, quedan los cuadrados de respaldo
	var icon: Texture2D = ItemIconsScript.get_art_icon(rune_data) as Texture2D
	if icon != null and visuals != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "IconSprite"
		sprite.texture = icon
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var longest: float = maxf(float(icon.get_width()), float(icon.get_height()))
		var fit: float = ICON_SIZE / maxf(longest, 1.0)
		sprite.scale = Vector2(fit, fit)
		visuals.add_child(sprite)
		if color_rect != null:
			color_rect.visible = false
		if inner_rect != null:
			inner_rect.visible = false
	elif color_rect != null:
		color_rect.color = rune_data.rune_color


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
