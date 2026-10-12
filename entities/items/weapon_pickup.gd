class_name WeaponPickup
extends Area2D
## Objeto recolectable de arma en el escenario.
## Al entrar en contacto con el Jugador, agrega el arma a su WeaponManager y la equipa.

const ItemIconsScript = preload("res://ui/components/item_icons.gd")
const PickupAuraScript = preload("res://entities/items/pickup_aura.gd")

## Armas que entran al arsenal (las que llenan la barra rápida); el resto va a la mochila.
const ARSENAL_LIMIT: int = 9

@export var weapon_data: WeaponData

## Si es false, el pickup desaparece al cargar el nivel cuando el jugador ya posee esa arma
## (armas fijas de campaña/tutorial). Dejar en true solo para botín repetible y vendible.
@export var allow_duplicates: bool = false

@onready var visuals: Node2D = $Visuals
@onready var icon_label: Label = $Visuals/IconLabel
@onready var name_label: Label = $Visuals/NameLabel
@onready var background_rect: ColorRect = $Visuals/BackgroundRect

var _time_accumulator: float = 0.0
var _collected: bool = false
var pickup_cooldown: float = 0.2


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visuals()


func _apply_visuals() -> void:
	if weapon_data == null:
		return
	
	var rarity_color: Color = ItemTooltip.RARITY_COLORS.get(int(weapon_data.rarity), Color.WHITE) as Color
	# Aura que pulsa detrás del arma, del color de su rareza
	if visuals != null:
		var aura: Node2D = PickupAuraScript.new()
		aura.color = rarity_color
		visuals.add_child(aura)
		visuals.move_child(aura, 0)
	if name_label != null:
		name_label.text = weapon_data.weapon_name
		name_label.add_theme_color_override("font_color", rarity_color)

	# Forma del arma: el mismo ícono pixel art del inventario (si no existe, queda el emoji)
	var icon: Texture2D = ItemIconsScript.get_icon_for(weapon_data) as Texture2D
	if icon != null and visuals != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "IconSprite"
		sprite.texture = icon
		# Arte HD: se reduce a ~30 px de lado mayor; los íconos 16x16 de respaldo conservan su ampliación pixelada
		if ItemIconsScript.get_art_icon(weapon_data) != null:
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var longest: float = maxf(float(icon.get_width()), float(icon.get_height()))
			var fit: float = 30.0 / maxf(longest, 1.0)
			sprite.scale = Vector2(fit, fit)
		else:
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(1.5, 1.5)
		visuals.add_child(sprite)
		if icon_label != null:
			icon_label.visible = false
	elif icon_label != null:
		if weapon_data.weapon_type == WeaponData.WeaponType.MELEE:
			icon_label.text = "⚔️"
		else:
			icon_label.text = "🔫"


func _process(delta: float) -> void:
	if pickup_cooldown > 0.0:
		pickup_cooldown = maxf(0.0, pickup_cooldown - delta)
		if pickup_cooldown <= 0.0:
			if _player_already_owns_weapon():
				_collected = true
				print("[WeaponPickup] %s ya está en posesión del jugador; el pedestal queda vacío." % weapon_data.weapon_name)
				queue_free()
				return
			for body in get_overlapping_bodies():
				if body is Player:
					_on_body_entered(body)
					break

	# Flotación suave oscilatoria (bobbing)
	_time_accumulator += delta * 3.5
	if visuals != null:
		visuals.position.y = sin(_time_accumulator) * 4.0


## Indica si el jugador ya tiene esta arma en el arsenal o la mochila (comparando la ruta del .tres).
func _player_already_owns_weapon() -> bool:
	if allow_duplicates or weapon_data == null or weapon_data.resource_path.is_empty():
		return false

	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return false

	var path: String = weapon_data.resource_path
	if player.weapon_manager != null:
		for owned: WeaponData in player.weapon_manager.weapons:
			if owned != null and owned.source_resource_path == path:
				return true

	if player.inventory_manager != null:
		for item: Resource in player.inventory_manager.backpack:
			var stored: WeaponData = item as WeaponData
			if stored == null:
				continue
			var stored_path: String = stored.resource_path if not stored.resource_path.is_empty() else stored.source_resource_path
			if stored_path == path:
				return true

	return false


func _on_body_entered(body: Node2D) -> void:
	if _collected or pickup_cooldown > 0.0 or weapon_data == null:
		return
	
	if body is Player:
		var player: Player = body as Player
		var added_success: bool = false
		if player.weapon_manager != null:
			if player.weapon_manager.weapons.size() < ARSENAL_LIMIT:
				_collected = true
				added_success = true
				player.weapon_manager.add_weapon(weapon_data, true)
				print("[WeaponPickup] Jugador recogió el arma: %s" % weapon_data.weapon_name)
		
		if not added_success and player.inventory_manager != null:
			if player.inventory_manager.add_item(weapon_data):
				_collected = true
				print("[WeaponPickup] Arsenal lleno. Arma %s guardada en la mochila." % weapon_data.weapon_name)
		
		if _collected:
			GameFeel.sfx(self, &"pickup_gear", Vector2.INF, -3.0)
			var tw: Tween = create_tween()
			tw.set_parallel(true)
			tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "modulate:a", 0.0, 0.15)
			tw.chain().tween_callback(queue_free)
