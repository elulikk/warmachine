class_name PickupItem
extends Area2D
## Objeto recolectable en el escenario que aplica modificadores de estadísticas al Jugador al contacto.
## Posee movimiento oscilatorio vertical (bobbing) y muestra el ícono pixel art del ítem.

const ItemIconsScript = preload("res://ui/components/item_icons.gd")

@export var item_data: ItemData

## Si es false, el pickup desaparece al cargar el nivel cuando el jugador ya posee el ítem
## (recompensas fijas de campaña). Los drops de enemigos lo dejan en true.
@export var allow_duplicates: bool = true

@onready var visuals: Node2D = $Visuals
@onready var visual_rect: ColorRect = $Visuals/ColorRect
@onready var inner_rect: ColorRect = get_node_or_null("Visuals/InnerRect") as ColorRect
@onready var name_label: Label = get_node_or_null("Visuals/NameLabel") as Label

var _time_accumulator: float = 0.0
var _collected: bool = false
var pickup_cooldown: float = 0.4

## true mientras el jugador está encima pero no hay lugar para el ítem (mochila llena).
var _blocked_by_full_bag: bool = false
var _retry_timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visuals()


func _apply_visuals() -> void:
	if item_data == null:
		return

	if visual_rect != null:
		visual_rect.color = item_data.item_color

	if name_label != null:
		name_label.text = item_data.item_name
		var rarity_color: Color = ItemTooltip.RARITY_COLORS.get(int(item_data.rarity), Color.WHITE) as Color
		name_label.add_theme_color_override("font_color", rarity_color)

	# Forma del ítem: el mismo ícono del inventario reemplaza al cuadrado de color
	var icon: Texture2D = ItemIconsScript.get_icon_for(item_data) as Texture2D
	if icon != null and visuals != null:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "IconSprite"
		sprite.texture = icon
		# Arte HD: se reduce a ~30 px de lado mayor; los íconos 16x16 de respaldo conservan su ampliación pixelada
		if ItemIconsScript.get_art_icon(item_data) != null:
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var longest: float = maxf(float(icon.get_width()), float(icon.get_height()))
			var fit: float = 30.0 / maxf(longest, 1.0)
			sprite.scale = Vector2(fit, fit)
		else:
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.scale = Vector2(1.5, 1.5)
		visuals.add_child(sprite)
		if visual_rect != null:
			visual_rect.visible = false
		if inner_rect != null:
			inner_rect.visible = false


func _process(delta: float) -> void:
	if pickup_cooldown > 0.0:
		pickup_cooldown = maxf(0.0, pickup_cooldown - delta)
		if pickup_cooldown <= 0.0:
			if _player_already_owns_item():
				_collected = true
				print("[PickupItem] %s ya está en posesión del jugador; el pedestal queda vacío." % item_data.item_name)
				queue_free()
				return
			_try_collect_overlapping()
	elif _blocked_by_full_bag and not _collected:
		_retry_timer -= delta
		if _retry_timer <= 0.0:
			_retry_timer = 0.5
			_try_collect_overlapping()

	# Movimiento oscilatorio vertical suave tipo flotación (bobbing)
	_time_accumulator += delta * 3.5
	if visuals != null:
		visuals.position.y = sin(_time_accumulator) * 4.0


func _try_collect_overlapping() -> void:
	for body in get_overlapping_bodies():
		if body is Player:
			_on_body_entered(body)
			break


## Indica si el jugador ya tiene este ítem equipado, en la mochila o en el baúl (compara la ruta del .tres).
func _player_already_owns_item() -> bool:
	if allow_duplicates or item_data == null or item_data.resource_path.is_empty():
		return false

	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return false

	var path: String = item_data.resource_path
	if player.equipment_manager != null:
		for equipped: Variant in player.equipment_manager.equipped_items.values():
			var equipped_item: ItemData = equipped as ItemData
			if equipped_item != null and equipped_item.resource_path == path:
				return true

	if player.inventory_manager != null:
		for stored: Resource in player.inventory_manager.backpack:
			if stored != null and stored.resource_path == path:
				return true

	var sm: SaveManager = SaveManager.get_instance()
	return sm != null and sm.stash_has_path(path)


func _on_body_entered(body: Node2D) -> void:
	if _collected or pickup_cooldown > 0.0:
		return

	if body is Player:
		var player: Player = body as Player
		var handled: bool = true
		if item_data != null:
			handled = _deliver_to(player)

		if not handled:
			# Sin lugar: el ítem se queda en el suelo en vez de perderse
			if not _blocked_by_full_bag:
				print("[PickupItem] Mochila llena. Liberá un casillero para recoger %s." % item_data.item_name)
			_blocked_by_full_bag = true
			return

		_collected = true
		if item_data != null:
			print("[PickupItem] ¡%s recogido y procesado!" % item_data.item_name)

		GameFeel.sfx(self, &"pickup_gear", Vector2.INF, -3.0)
		# Animación breve de recolección
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 0.0, 0.15)
		tween.finished.connect(queue_free)


## Equipa el ítem si su ranura está libre; si no, lo guarda en la mochila. Devuelve false si no hay lugar.
func _deliver_to(player: Player) -> bool:
	var slot_key: String = item_data.equip_slot.to_upper()

	if not slot_key.is_empty() and slot_key != "NONE" and player.equipment_manager != null:
		# Si la ranura de equipamiento está libre, equiparlo de inmediato
		var target_slot: String = player.equipment_manager.get_target_slot_for_item(item_data)
		if player.equipment_manager.get_equipped_item(target_slot) == null:
			if player.equipment_manager.equip_item(target_slot, item_data):
				return true

	# Si la ranura está ocupada o es NONE, guardarlo en la mochila si existe
	if player.inventory_manager != null:
		if player.inventory_manager.add_item(item_data):
			return true
		if player.stats_manager != null and slot_key == "NONE":
			item_data.apply_to_stats(player.stats_manager)
			return true
		return false

	if player.stats_manager != null:
		item_data.apply_to_stats(player.stats_manager)
	return true
